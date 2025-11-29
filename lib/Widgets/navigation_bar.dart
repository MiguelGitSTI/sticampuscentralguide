import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BottomNavBarFb2 extends StatelessWidget {
  const BottomNavBarFb2({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Responsive scale based on baseline ~411x914 logical
    final sw = MediaQuery.of(context).size.width / 411.0;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        // Add a little top space above the navbar to avoid snug fit
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: Container(
          width: width,
          height: (72 * sw).clamp(60, 84).toDouble(),
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceVariant : cs.surface,
            borderRadius: BorderRadius.circular(36),
            boxShadow: isDark
                ? const [
                    // Subtle dark shadows in dark mode (no white glow)
                    BoxShadow(
                      color: Color(0xCC000000),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 4,
                      spreadRadius: 0,
                      offset: Offset(0, 2),
                    ),
                  ]
                : const [
                    // Dark shadows for light mode
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
          padding: EdgeInsets.zero,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalW = constraints.maxWidth;
              final segmentW = totalW / 3;
              const royal = Color(0xFF123CBE); // Force brand NavyBlue highlight
              return Stack(
                children: [
                  // Sliding highlight background
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: segmentW * currentIndex,
                    width: segmentW,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: royal,
                        borderRadius: BorderRadius.circular(36),
                      ),
                    ),
                  ),
                  // Content row above the highlight
                  Row(
                    children: [
                      _NavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        selected: currentIndex == 0,
                        onTap: () => onTap(0),
                      ),
                      _NavItem(
                        icon: Icons.map_rounded,
                        label: 'Map',
                        selected: currentIndex == 1,
                        onTap: () => onTap(1),
                      ),
                      _NavItem(
                        icon: Icons.calendar_month_rounded,
                        label: 'Hub',
                        selected: currentIndex == 2,
                        onTap: () => onTap(2),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
  // Background is handled by a unified sliding highlight in the parent Stack.
  final sw = MediaQuery.of(context).size.width / 411.0;
  final cs = Theme.of(context).colorScheme;
  final segmentBg = Colors.transparent;
  final iconColor = selected ? const Color(0xFFFFB206) : cs.onSurface.withOpacity(0.85);

    return Expanded(
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          height: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: segmentBg,
            borderRadius: BorderRadius.circular(36),
          ),
          duration: 250.ms,
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: selected ? (24 * sw).clamp(20, 28).toDouble() : (22 * sw).clamp(18, 26).toDouble())
                  .animate(target: selected ? 1 : 0)
                  .moveY(begin: 0, end: -4, duration: 160.ms, curve: Curves.easeOut)
                  .scale(begin: const Offset(1, 1), end: const Offset(1.06, 1.06), duration: 160.ms),
              AnimatedSwitcher(
                duration: 180.ms,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: selected
                    ? Padding(
                        key: const ValueKey('label'),
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: (10 * sw).clamp(9, 12).toDouble(),
                            height: 1.0,
                            color: const Color(0xFFFFB206),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 180.ms)
                            .slideY(begin: 0.2, end: 0, duration: 180.ms, curve: Curves.easeOut),
                      )
        : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
