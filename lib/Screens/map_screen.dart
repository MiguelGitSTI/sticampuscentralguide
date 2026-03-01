import 'package:flutter/material.dart';
import 'dart:ui' show ImageFilter;
import '../Items/building_items.dart';
import '../Items/building_special.dart';
import '../theme/theme_provider.dart';
// Local soft-shadow helper to avoid extra imports in this screen.

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  late final TransformationController _transformationController;
  final GlobalKey _viewerKey = GlobalKey();
  String? _activeBuildingId; // building with overlay card open (also drives scale)
  bool _cardVisible = false; // when true, show the info card above the map
  _OverlayAction _activeAction = _OverlayAction.info; // which action's content to show
  bool _hasInitializedPosition = false;

  late final AnimationController _zoomController;
  Matrix4? _zoomBegin;
  Matrix4? _zoomEnd;

  List<BoxShadow> _softShadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.10),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    } else {
      return const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 3,
          offset: Offset(0, 1.5),
        ),
      ];
    }
  }

  // Allow external callers (HomeScreen) to highlight a building
  void highlightBuilding(String buildingId) {
    final b = _tryGetBuilding(buildingId);
    if (b == null) return;
    setState(() {
      _activeBuildingId = buildingId;
      _cardVisible = false;
    });
    _zoomToBuilding(b);
  }

  BuildingItem? _tryGetBuilding(String buildingId) {
    for (final b in kBuildingItems) {
      if (b.id == buildingId) return b;
    }
    return null;
  }

  void _clearSelection() {
    if (_activeBuildingId == null && !_cardVisible) return;
    setState(() {
      _activeBuildingId = null;
      _cardVisible = false;
    });
  }

  void _cancelZoomAnimation() {
    // Null out BEFORE reset so _onZoomTick won't snap back to _zoomBegin
    _zoomBegin = null;
    _zoomEnd = null;
    _zoomController.reset();
  }

  void _animateTransformTo(Matrix4 target) {
    // Stop any in-flight animation
    _zoomController.reset();
    _zoomBegin = _transformationController.value.clone();
    _zoomEnd = target.clone();
    _zoomController.forward();
  }

  /// Compute building center in the coordinate space of the constrained child.
  /// With constrained:true, the SizedBox(1024,768) is sized to the viewport.
  /// Building widget width = b.scale * MapSpec.width (absolute px, unclamped).
  /// Align formula: offset = (parent - child) * (alignment + 1) / 2.
  Offset _buildingViewportCenter(BuildingItem b, Size viewportSize) {
    final cw = b.scale * MapSpec.width;
    final cx = (viewportSize.width - cw) * (b.x + 1) / 2.0 + cw / 2.0;
    final cy = (b.y + 1) / 2.0 * viewportSize.height;
    return Offset(cx, cy);
  }

  void _zoomToBuilding(BuildingItem b) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewerContext = _viewerKey.currentContext;
      if (viewerContext == null) return;
      final render = viewerContext.findRenderObject();
      if (render is! RenderBox || !render.hasSize) return;

      final vp = render.size;
      final currentScale = _transformationController.value.getMaxScaleOnAxis();
      // Use 2.4 as default, but if user is zoomed in more, bring it back down to 2.4
      final targetScale = currentScale > 2.4 ? 2.4 : (currentScale < 2.4 ? 2.4 : currentScale);

      final center = _buildingViewportCenter(b, vp);

      assert(() {
        debugPrint('[Map] Zoom → ${b.id}: center=(${center.dx.toStringAsFixed(1)}, ${center.dy.toStringAsFixed(1)}), vp=(${vp.width.toStringAsFixed(0)}x${vp.height.toStringAsFixed(0)})');
        return true;
      }());

      final target = Matrix4.identity()
        ..translate(vp.width / 2, vp.height / 2)
        ..scale(targetScale)
        ..translate(-center.dx, -center.dy);

      _animateTransformTo(target);
    });
  }

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();

    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _zoomController.addListener(_onZoomTick);
  }

  void _onZoomTick() {
    final begin = _zoomBegin;
    final end = _zoomEnd;
    if (begin == null || end == null) return;
    final t = Curves.easeOutCubic.transform(_zoomController.value);
    final lerped = Matrix4Tween(begin: begin, end: end).lerp(t);
    _transformationController.value = lerped;
  }

  String _buildActionBodyText(BuildingOverlaySpec spec) {
    switch (_activeAction) {
      case _OverlayAction.info:
        return spec.description;
      case _OverlayAction.navigate:
        return spec.navigateText ?? 'Navigate to ${spec.title}. This opens your preferred maps app with campus directions and nearest entrances.';
      case _OverlayAction.rooms:
        return spec.roomsText ?? 'Rooms and facilities for ${spec.title} will appear here. Check back for detailed room listings, schedules, and points of interest.';
    }
  }

  @override
  void dispose() {
    _zoomBegin = null;
    _zoomEnd = null;
    _zoomController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Map'),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  // Map viewport background image
                  image: const DecorationImage(
                    image: AssetImage('assets/images/map_map_background.webp'),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _softShadow(context),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: InteractiveViewer(
                    key: _viewerKey,
                    transformationController: _transformationController,
                    minScale: 1.0,
                    maxScale: 4.0,
                    boundaryMargin: EdgeInsets.zero,
                    clipBehavior: Clip.hardEdge,
                    panEnabled: true,
                    scaleEnabled: true,
                    onInteractionStart: (_) {
                      _cancelZoomAnimation();
                      // Mark as initialized once user interacts
                      if (!_hasInitializedPosition) {
                        _hasInitializedPosition = true;
                      }
                    },
                    child: SizedBox(
                      width: MapSpec.width,
                      height: MapSpec.height,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/map_map.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          // Tap empty space to clear the current selection.
                          if (_activeBuildingId != null || _cardVisible)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: _clearSelection,
                                child: const SizedBox.expand(),
                              ),
                            ),
                          // Non-selected buildings first
                          ..._buildings(excludeId: _activeBuildingId),
                          // Blur the rest of the map when a building is active
                          if (_activeBuildingId != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: true,
                                child: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                                    child: Container(color: Colors.black.withOpacity(0.08)),
                                  ),
                                ),
                              ),
                            ),
                          // Selected building drawn above blur to stay crisp
                          if (_activeBuildingId != null)
                            ..._buildSelectedBuilding(_activeBuildingId!),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Bottom buttons outside the map, above nav bar
            if (_activeBuildingId != null && !_cardVisible)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _buildBottomButtons(_activeBuildingId!),
                ),
              ),
            if (_activeBuildingId != null && _cardVisible)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _buildOverlayCard(_activeBuildingId!),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildings({String? excludeId}) {
    final items = List<BuildingItem>.from(kBuildingItems)
      ..removeWhere((b) => b.hidden)
      ..sort((a, b) => a.z.compareTo(b.z));
    return items.where((b) => b.id != excludeId).map((b) {
      return _buildBuildingWidget(b);
    }).toList();
  }

  List<Widget> _buildSelectedBuilding(String buildingId) {
    final match = kBuildingItems.firstWhere((b) => b.id == buildingId, orElse: () => const BuildingItem(id: '', asset: '', x: 0, y: 0, scale: 0, hidden: true));
    if (match.hidden || match.id.isEmpty) return const [];
    return [_buildBuildingWidget(match)];
  }

  Widget _buildBuildingWidget(BuildingItem b) {
    final w = b.scale * MapSpec.width;
    final isActive = _activeBuildingId == b.id;
    return Align(
      alignment: Alignment(b.x, b.y),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          final alreadyActive = _activeBuildingId == b.id;
          setState(() {
            _activeBuildingId = b.id;
            _cardVisible = false;
          });
          if (!alreadyActive) {
            _zoomToBuilding(b);
          }
        },
        child: AnimatedScale(
          scale: isActive ? 1.10 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: SizedBox(
            width: w,
            child: Stack(
              children: [
                Image.asset(
                  b.asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
                if (isActive)
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Color(0x66FFD200),
                      BlendMode.srcATop,
                    ),
                    child: Image.asset(
                      b.asset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayCard(String buildingId) {
    final spec = kBuildingOverlays[buildingId];
    if (spec == null) return const SizedBox.shrink();
    // Top-centered overlay card (above the map view)
    final media = MediaQuery.of(context).size;
    final maxW = media.width * 0.85;
    final cardW = maxW.clamp(260.0, 420.0);

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 150),
      child: Material(
        color: Colors.white.withOpacity(0.96),
        elevation: 12,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: cardW,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                // Building description images (e.g., files named like `<id>_desc*.png/jpg/webp`)
                _BuildingDescImages(buildingId: buildingId),
                const SizedBox(height: 8),
                Text(
                  _buildActionBodyText(spec),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Bottom button bar outside the map canvas
  Widget _buildBottomButtons(String buildingId) {
    final isBC = buildingId == 'building_b' || buildingId == 'building_c';
    final buttons = <_OverlayBtnSpec>[
      const _OverlayBtnSpec(icon: Icons.info_outline, label: 'Info', action: _OverlayAction.info),
      const _OverlayBtnSpec(icon: Icons.map_outlined, label: 'Navigate', action: _OverlayAction.navigate),
      if (isBC) const _OverlayBtnSpec(icon: Icons.meeting_room_outlined, label: 'Rooms', action: _OverlayAction.rooms),
    ];

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double containerHPad = 12; // matches Container horizontal padding
          final double innerSpacing = 8; // spacing between buttons
          final int count = buttons.length;
          final double availableW = constraints.maxWidth - (2 * containerHPad) - ((count - 1) * innerSpacing);
          final double perBtnW = (availableW / count).clamp(92.0, 160.0);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: ThemeProvider.navyBlue.withOpacity(0.70),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < buttons.length; i++) ...[
                      SizedBox(
                        width: perBtnW,
                        child: _OverlayButton(
                          icon: buttons[i].icon,
                          label: buttons[i].label,
                          onTap: () => setState(() {
                            _activeAction = buttons[i].action;
                            _cardVisible = true;
                          }),
                        ),
                      ),
                      if (i != buttons.length - 1) SizedBox(width: innerSpacing),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

}

class _OverlayBtnSpec {
  final IconData icon;
  final String label;
  final _OverlayAction action;
  const _OverlayBtnSpec({required this.icon, required this.label, required this.action});
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OverlayButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: ThemeProvider.navyBlue,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: ThemeProvider.gold),
            const SizedBox(width: 6),
            Flexible(child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ThemeProvider.gold,
              ),
            )),
          ],
        ),
      ),
    );
  }
}

enum _OverlayAction { info, navigate, rooms }

class _BuildingDescImages extends StatelessWidget {
  final String buildingId;
  const _BuildingDescImages({required this.buildingId});

  List<String> _filesFor(String id) {
    switch (id) {
      case 'airport':
        return ['assets/images/airport_desc.jpg'];
      case 'building_b':
        return [
          'assets/images/buildingb_desc.jpg',
          'assets/images/buildingb2_desc.jpg',
        ];
      case 'building_c':
        return [
          'assets/images/buildingc_desc.jpg',
          'assets/images/buildingc2_desc.jpg',
        ];
      case 'cottage':
        return ['assets/images/cottage_desc.jpg'];
      case 'gym_top_right':
        return [
          'assets/images/gym_desc.jpg',
          'assets/images/gym2_desc.jpg',
          // 'assets/images/gympearea_desc.jpg', // explicitly excluded for now
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = _filesFor(buildingId);
    if (files.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = (w * 9 / 16).clamp(120.0, 220.0); // fit to card width, reasonable height
        if (files.length == 1) {
          final path = files.first;
          return SizedBox(
            width: w,
            height: h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                path,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stack) => _ImageNameFallback(path: path, width: w, height: h),
              ),
            ),
          );
        }

        // 2+ images: snapping carousel
        final controller = PageController(viewportFraction: 1.0);
        return SizedBox(
          width: w,
          height: h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PageView.builder(
              controller: controller,
              physics: const PageScrollPhysics(),
              itemCount: files.length,
              itemBuilder: (context, index) {
                final path = files[index];
                return Image.asset(
                  path,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (context, error, stack) => _ImageNameFallback(path: path, width: w, height: h),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ImageNameFallback extends StatelessWidget {
  final String path;
  final double width;
  final double height;
  const _ImageNameFallback({required this.path, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final fileName = path.split('/').last;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          fileName,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
      ),
    );
  }
}
