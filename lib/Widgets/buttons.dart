import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sticampuscentralguide/utils/firebase_cache_service.dart';

class TopButtons extends StatelessWidget {
  final VoidCallback onFaqTap;
  final VoidCallback onNotificationTap;
  final GlobalKey<NotificationButtonWithBadgeState>? notificationButtonKey;
  
  const TopButtons({
    super.key,
    required this.onFaqTap,
    required this.onNotificationTap,
    this.notificationButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // FAQ Button
        _TopButton(
          icon: Icons.help_outline_rounded,
          onTap: onFaqTap,
        ),
        const SizedBox(width: 8),
        // Notification Button with badge
        NotificationButtonWithBadge(
          key: notificationButtonKey,
          onTap: onNotificationTap,
        ),
      ],
    );
  }
}

/// Notification button with unread badge
class NotificationButtonWithBadge extends StatefulWidget {
  final VoidCallback onTap;

  const NotificationButtonWithBadge({
    super.key,
    required this.onTap,
  });

  @override
  State<NotificationButtonWithBadge> createState() => NotificationButtonWithBadgeState();
}

class NotificationButtonWithBadgeState extends State<NotificationButtonWithBadge>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  Set<String> _readNotificationIds = {};
  int _cachedNotificationCount = 0;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _notificationsStream;

  static const String _readIdsKey = 'read_notification_ids';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _shadowAnimation = Tween<double>(
      begin: 1.0,
      end: 0.4,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _loadReadIds();
    _loadCachedCount();
    _notificationsStream = FirebaseFirestore.instance
        .collection('notifications_outbox')
        .limit(50)
        .snapshots();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refreshBadge();
    }
  }

  /// Public method to refresh the badge count
  Future<void> refreshBadge() async {
    await _loadReadIds();
  }

  Future<void> _loadReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_readIdsKey) ?? [];
    if (mounted) {
      setState(() {
        _readNotificationIds = ids.toSet();
      });
    }
  }

  Future<void> _loadCachedCount() async {
    final cached = await FirebaseCacheService().getCachedNotifications();
    if (cached != null && mounted) {
      setState(() {
        _cachedNotificationCount = cached.where((n) {
          final id = n['id'] as String? ?? '';
          return !_readNotificationIds.contains(id);
        }).length;
      });
    }
  }

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  void _handleTapEnd() {
    _animationController.reverse().then((_) {
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width / 411.0;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonSize = (44 * sw).clamp(38, 54).toDouble();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        int unreadCount = _cachedNotificationCount; // Default to cached count
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          unreadCount = docs.where((doc) => !_readNotificationIds.contains(doc.id)).length;
          // Update cached count
          _cachedNotificationCount = unreadCount;
        }

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTapDown: (details) => _onTapDown(details),
                  onTapCancel: _onTapCancel,
                  onTap: _handleTapEnd,
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: buttonSize + 8, // Extra space for badge
                    height: buttonSize + 4,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Button
                        Positioned(
                          left: 0,
                          top: 2,
                          child: Ink(
                            width: buttonSize,
                            height: buttonSize,
                            decoration: BoxDecoration(
                              color: isDark ? cs.surfaceContainerHighest : cs.surface,
                              borderRadius: BorderRadius.circular(12),
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
                            child: Icon(
                              Icons.notifications_outlined,
                              color: const Color(0xFF123CBE),
                              size: (22 * sw).clamp(18, 28).toDouble(),
                            ),
                          ),
                        ),
                        // Badge
                        if (unreadCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark ? cs.surface : Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TopButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  
  const _TopButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_TopButton> createState() => _TopButtonState();
}

class _TopButtonState extends State<_TopButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200), // Slower animation
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _shadowAnimation = Tween<double>(
      begin: 1.0,
      end: 0.4,
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

  void _onTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  void _handleTapEnd() {
    // Always play the reverse animation for visual feedback
    _animationController.reverse().then((_) {
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width / 411.0;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTapDown: (details) => _onTapDown(details),
              onTapCancel: _onTapCancel,
              onTap: _handleTapEnd,
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                width: (44 * sw).clamp(38, 54).toDouble(),
                height: (44 * sw).clamp(38, 54).toDouble(),
                decoration: BoxDecoration(
                  color: isDark ? cs.surfaceVariant : cs.surface,
                  borderRadius: BorderRadius.circular(12),
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
                child: Icon(
                  widget.icon,
                  color: const Color(0xFF123CBE), // Navy blue
                  size: (22 * sw).clamp(18, 28).toDouble(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}