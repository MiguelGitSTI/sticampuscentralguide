import 'package:flutter/material.dart';

class GradientButtonFb1 extends StatefulWidget {
  final String text;
  final Function() onPressed;
  final bool showBorder;
  // Optional sizing controls
  final double horizontalPadding;
  final double verticalPadding;
  final double fontSize;
  const GradientButtonFb1({
    required this.text, 
    required this.onPressed, 
    this.showBorder = true,
    this.horizontalPadding = 75,
    this.verticalPadding = 15,
    this.fontSize = 18,
    super.key,
  });

  @override
  State<GradientButtonFb1> createState() => _GradientButtonFb1State();
}

class _GradientButtonFb1State extends State<GradientButtonFb1>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250), // Slower animation
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _shadowAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_animationController.isAnimating) return;
    try {
      await _animationController.forward();
      // brief hold for tactile feel
      await Future.delayed(const Duration(milliseconds: 40));
      await _animationController.reverse();
    } finally {
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF123CBE); // NavyBlue
    const secondaryColor = Color(0xFF123CBE); // solid navy gradient
    const accentColor = Color(0xFFFFB206); // Gold text
    const double borderRadius = 15;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(borderRadius),
              onTap: _handleTap,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  gradient: const LinearGradient(colors: [primaryColor, secondaryColor]),
                  border: widget.showBorder ? Border.all(
                    color: const Color(0xFFFFB206), // Gold border
                    width: 2,
                  ) : null,
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: const Color(0xCC000000).withOpacity(0.7 * _shadowAnimation.value),
                            blurRadius: 4 * _shadowAnimation.value,
                            spreadRadius: 0,
                            offset: Offset(0, 2 * _shadowAnimation.value),
                          ),
                          BoxShadow(
                            color: const Color(0x66000000).withOpacity(0.6 * _shadowAnimation.value),
                            blurRadius: 2 * _shadowAnimation.value,
                            spreadRadius: 0,
                            offset: Offset(0, 1 * _shadowAnimation.value),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: const Color(0x18000000),
                            blurRadius: 4 * _shadowAnimation.value,
                            spreadRadius: 0,
                            offset: Offset(0, 2 * _shadowAnimation.value),
                          ),
                          BoxShadow(
                            color: const Color(0x12000000),
                            blurRadius: 2 * _shadowAnimation.value,
                            spreadRadius: 0,
                            offset: Offset(0, 1 * _shadowAnimation.value),
                          ),
                        ],
                ),
                child: Container(
                  padding: EdgeInsets.only(
                    right: widget.horizontalPadding,
                    left: widget.horizontalPadding,
                    top: widget.verticalPadding,
                    bottom: widget.verticalPadding,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                  child: Text(
                    widget.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: widget.fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}