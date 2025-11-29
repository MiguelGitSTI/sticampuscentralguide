import 'package:flutter/material.dart';
import 'package:sticampuscentralguide/Widgets/carousel_buttons.dart';

class CustomCarouselFB2 extends StatefulWidget {
  final VoidCallback? onNavigateToMap;
  final ValueChanged<String>? onLocate;
  const CustomCarouselFB2({super.key, this.onNavigateToMap, this.onLocate});

  @override
  State<CustomCarouselFB2> createState() => _CustomCarouselFB2State();
}

class _CustomCarouselFB2State extends State<CustomCarouselFB2> {

  // - - - - - - - - - - - - Instructions - - - - - - - - - - - - - -
  // 1.Replace cards list with whatever widgets you'd like. 
  // 2.Change the widgetMargin attribute, to ensure good spacing on all screensize.
  // 3.If you have a problem with this widget, please contact us at flutterbricks90@gmail.com
  // Learn to build this widget at https://www.youtube.com/watch?v=dSMw1Nb0QVg!
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
  
  late final List<_CarouselItem> items;
  int _currentPage = 0;

  // Tighter gaps between cards
  final double carouselItemMargin = 10;

  // Dynamic sizing to minimize inner whitespace while keeping portrait aspect
  late PageController _pageController;
  double _viewportFraction = 1;
  double _cardWidth = 230; // will be recalculated from screen width
  bool _imagesPrecached = false;

  @override
  void initState() {
    super.initState();
    // Temporary controller; real fraction is set in didChangeDependencies
    _pageController = PageController(initialPage: 0, viewportFraction: _viewportFraction);
    items = _kCarouselItems;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.of(context).size.width;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    // Target portrait width; clamp to available width minus margins
    final targetWidth = 260.0;
    final maxWidth = (screenWidth - 2 * carouselItemMargin - 8).clamp(180.0, targetWidth);
    final newCardWidth = maxWidth;
    final newViewportFraction = ((newCardWidth + 2 * carouselItemMargin) / screenWidth).clamp(0.6, 1.0);

    final fractionChanged = (newViewportFraction - _viewportFraction).abs() > 0.001;
    final widthChanged = (newCardWidth - _cardWidth).abs() > 0.5;
    if (fractionChanged || widthChanged) {
      final oldPage = _currentPage;
      _viewportFraction = newViewportFraction;
      _cardWidth = newCardWidth;
      final oldController = _pageController;
      _pageController = PageController(initialPage: oldPage, viewportFraction: _viewportFraction);
      // Dispose old controller to avoid leaks
      oldController.dispose();
      // No need to call setState here; rebuild will happen naturally
    }

    // Precache carousel images with appropriate cacheWidth once
    if (!_imagesPrecached) {
      final cacheWidthPx = (newCardWidth * devicePixelRatio).round();
      for (final it in items) {
        final provider = ResizeImage(AssetImage(it.image), width: cacheWidthPx);
        precacheImage(provider, context);
      }
      _imagesPrecached = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: items.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (BuildContext context, int position) {
              return imageSlider(position);
            },
          ),
        ),
        const SizedBox(height: 8),
        _buildDotsIndicator(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget imageSlider(int position) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (BuildContext context, widget) {
        return Container(
          margin: EdgeInsets.all(carouselItemMargin),
          child: Center(child: widget),
        );
      },
      child: _CarouselCard(
        item: items[position],
        cardWidth: _cardWidth,
        onNavigateToMap: widget.onNavigateToMap,
        onLocate: widget.onLocate,
      ),
    );
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(items.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive 
                ? const Color(0xFF123CBE)
                : const Color(0xFF123CBE).withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _CarouselItem {
  final String image;
  final String name;
  const _CarouselItem({required this.image, required this.name});
}

class _CarouselCard extends StatefulWidget {
  final _CarouselItem item;
  final double cardWidth;
  final VoidCallback? onNavigateToMap;
  final ValueChanged<String>? onLocate;
  const _CarouselCard({required this.item, required this.cardWidth, this.onNavigateToMap, this.onLocate});

  @override
  State<_CarouselCard> createState() => _CarouselCardState();
}

class _CarouselCardState extends State<_CarouselCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheWidthPx = (widget.cardWidth * dpr).round();
    return Container(
      width: widget.cardWidth, // Ensure portrait aspect (taller than wide)
  height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.5),
        boxShadow: isDark
            ? const [
                BoxShadow(
                  color: Color(0xCC000000),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 3,
                  spreadRadius: 0,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 1,
                  spreadRadius: 0,
                  offset: Offset(0, 1),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 3,
                  spreadRadius: 0,
                  offset: Offset(0, 2),
                ),
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 1,
                  spreadRadius: 0,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.5),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full card image
            Image.asset(
              widget.item.image,
              fit: BoxFit.cover,
              cacheWidth: cacheWidthPx,
            ),
            // Dark overlay
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
              ),
            ),
            // Content on top
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    widget.item.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: LocateButton(
                      onPressed: () {
                        String? target;
                        switch (widget.item.name) {
                          case 'Gym & Fitness':
                            target = 'gym_top_right';
                            break;
                          case 'Campus Café':
                            target = 'building_c';
                            break;
                          case 'Library':
                            target = 'building_b';
                            break;
                        }
                        if (target != null) {
                          widget.onLocate?.call(target);
                        }
                        widget.onNavigateToMap?.call();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple, easy-to-edit in-file data for the carousel.
const List<_CarouselItem> _kCarouselItems = <_CarouselItem>[
  _CarouselItem(
    image: 'assets/images/home_cafe.jpg',
    name: 'Campus Café',
  ),
  _CarouselItem(
    image: 'assets/images/home_gym.jpg',
    name: 'Gym & Fitness',
  ),
  _CarouselItem(
    image: 'assets/images/home_library.jpg',
    name: 'Library',
  ),
];
