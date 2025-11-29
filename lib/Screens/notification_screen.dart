import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sticampuscentralguide/utils/firebase_cache_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late Future<String> _sectionFuture;
  static const String _readIdsKey = 'read_notification_ids';
  Set<String> _readNotificationIds = {};
  List<Map<String, dynamic>>? _cachedNotifications;
  bool _isLoadingCache = true;

  @override
  void initState() {
    super.initState();
    _sectionFuture = _loadUserSection();
    _loadReadIds();
    _loadCachedNotifications();
  }

  Future<String> _loadUserSection() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_section') ?? 'MAWD302';
  }

  Future<void> _loadCachedNotifications() async {
    final cached = await FirebaseCacheService().getCachedNotifications();
    if (mounted) {
      setState(() {
        _cachedNotifications = cached;
        _isLoadingCache = false;
      });
    }
  }

  void _cacheNotifications(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final notifications = docs.map((doc) {
      final d = doc.data();
      return {
        'id': doc.id,
        'from': d['from'],
        'topic': d['topic'],
        'message': d['message'],
        'createdAt': d['createdAt'],
      };
    }).toList();
    FirebaseCacheService().cacheNotifications(notifications);
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

  /// Marks a single notification ID as read
  Future<void> _markAsRead(String notificationId) async {
    if (_readNotificationIds.contains(notificationId)) return;
    final prefs = await SharedPreferences.getInstance();
    _readNotificationIds.add(notificationId);
    // Keep only the most recent 200 IDs to prevent unbounded growth
    final trimmedList = _readNotificationIds.toList();
    if (trimmedList.length > 200) {
      trimmedList.removeRange(0, trimmedList.length - 200);
    }
    await prefs.setStringList(_readIdsKey, trimmedList);
    if (mounted) setState(() {});
  }

  /// Marks all provided notification IDs as read
  Future<void> _markAllAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _readNotificationIds.addAll(notificationIds);
    // Keep only the most recent 200 IDs to prevent unbounded growth
    final trimmedList = _readNotificationIds.toList();
    if (trimmedList.length > 200) {
      trimmedList.removeRange(0, trimmedList.length - 200);
    }
    await prefs.setStringList(_readIdsKey, trimmedList);
    if (mounted) setState(() {});
  }

  /// Marks all notifications as unread
  Future<void> _markAllAsUnread() async {
    final prefs = await SharedPreferences.getInstance();
    _readNotificationIds.clear();
    await prefs.setStringList(_readIdsKey, []);
    if (mounted) setState(() {});
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dateTime.year, dateTime.month, dateTime.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  /// Build notifications list from cached data
  Widget _buildNotificationsList(List<Map<String, dynamic>> cachedData, {bool isOffline = false}) {
    final items = cachedData.map((data) {
      final ts = data['createdAt'];
      DateTime when;
      if (ts is Timestamp) {
        when = ts.toDate();
      } else if (ts is DateTime) {
        when = ts;
      } else if (ts is String) {
        when = DateTime.tryParse(ts) ?? DateTime.now();
      } else {
        when = DateTime.now();
      }
      final id = data['id'] as String? ?? '';
      return (
        id: id,
        item: _NotificationItem(
          id: id,
          from: (data['from'] as String?)?.trim().isNotEmpty == true
              ? data['from'] as String
              : 'Campus Announcement',
          topic: (data['topic'] as String?) ?? '',
          message: (data['message'] as String?) ?? '',
          timestamp: _formatTimestamp(when),
          isRead: _readNotificationIds.contains(id),
        ),
        createdAt: when,
      );
    }).toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final sortedItems = items.map((e) => e.item).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (isOffline)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 16,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Showing cached data',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: sortedItems.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _NotificationCard(
                    notification: sortedItems[index],
                    onMarkAsRead: () => _markAsRead(sortedItems[index].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Options',
            onSelected: (value) async {
              if (value == 'read_all') {
                final docs = await FirebaseFirestore.instance
                    .collection('notifications_outbox')
                    .limit(50)
                    .get();
                final allIds = docs.docs.map((d) => d.id).toList();
                await _markAllAsRead(allIds);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All notifications marked as read')),
                  );
                }
              } else if (value == 'unread_all') {
                await _markAllAsUnread();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All notifications marked as unread')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'read_all',
                child: Row(
                  children: [
                    Icon(Icons.done_all, size: 20),
                    SizedBox(width: 12),
                    Text('Mark all as read'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'unread_all',
                child: Row(
                  children: [
                    Icon(Icons.markunread, size: 20),
                    SizedBox(width: 12),
                    Text('Mark all as unread'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _sectionFuture,
          builder: (context, sectionSnap) {
            if (sectionSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final query = FirebaseFirestore.instance
              .collection('notifications_outbox')
              .limit(50);

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: query.snapshots(),
              builder: (context, snap) {
                // Handle error state - show cached data if available
                if (snap.hasError) {
                  if (_cachedNotifications != null && _cachedNotifications!.isNotEmpty) {
                    return _buildNotificationsList(_cachedNotifications!, isOffline: true);
                  }
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Failed to load notifications.\n${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // Handle loading state - show cached data if available
                if (!snap.hasData) {
                  if (_cachedNotifications != null && _cachedNotifications!.isNotEmpty && !_isLoadingCache) {
                    return _buildNotificationsList(_cachedNotifications!, isOffline: false);
                  }
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = snap.data!.docs;
                
                // Cache the fresh data
                if (docs.isNotEmpty) {
                  _cacheNotifications(docs);
                }
                
                if (docs.isEmpty) {
                  // Show cached notifications if Firebase is empty
                  if (_cachedNotifications != null && _cachedNotifications!.isNotEmpty) {
                    return _buildNotificationsList(_cachedNotifications!, isOffline: true);
                  }
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme.onSurface
                              .withOpacity(0.6),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context)
                                .colorScheme.onSurface
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Convert docs to notification items
                final items = docs
                    .map((d) {
                      final data = d.data();
                      final ts = (data['createdAt']);
                      DateTime when;
                      if (ts is Timestamp) {
                        when = ts.toDate();
                      } else if (ts is DateTime) {
                        when = ts;
                      } else {
                        when = DateTime.now();
                      }
                      return (
                        id: d.id,
                        item: _NotificationItem(
                          id: d.id,
                          from: (data['from'] as String?)?.trim().isNotEmpty == true
                              ? data['from'] as String
                              : 'Campus Announcement',
                          topic: (data['topic'] as String?) ?? '',
                          message: (data['message'] as String?) ?? '',
                          timestamp: _formatTimestamp(when),
                          isRead: _readNotificationIds.contains(d.id),
                        ),
                        createdAt: when,
                      );
                    })
                    .toList(growable: false)
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                final sortedItems = items.map((e) => e.item).toList(growable: false);

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView.builder(
                    itemCount: sortedItems.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _NotificationCard(
                          notification: sortedItems[index],
                          onMarkAsRead: () => _markAsRead(sortedItems[index].id),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationItem {
  final String id;
  final String from;
  final String topic;
  final String message;
  final String timestamp;
  final bool isRead;
  bool isExpanded = false;

  _NotificationItem({
    required this.id,
    required this.from,
    required this.topic,
    required this.message,
    required this.timestamp,
    required this.isRead,
  });
}

class _NotificationCard extends StatefulWidget {
  final _NotificationItem notification;
  final VoidCallback onMarkAsRead;

  const _NotificationCard({
    required this.notification,
    required this.onMarkAsRead,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      widget.notification.isExpanded = !widget.notification.isExpanded;
      if (widget.notification.isExpanded) {
        _animationController.forward();
        // Mark as read when opening
        widget.onMarkAsRead();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRead = widget.notification.isRead;

    // All notifications use the same styling (no gray for read)
    final cardColor = isDark ? cs.surfaceContainerHighest : cs.surface;
    final textColor = cs.onSurface;
    final subtitleColor = cs.onSurface.withOpacity(0.7);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        children: [
          // Notification header
          InkWell(
            onTap: _toggleExpansion,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From and timestamp row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Unread indicator dot
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: cs.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            'From: ${widget.notification.from}',
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.notification.timestamp,
                            style: TextStyle(
                              fontSize: 12,
                              color: subtitleColor,
                            ),
                          ),
                          if (isRead)
                            Text(
                              ' (Read)',
                              style: TextStyle(
                                fontSize: 12,
                                color: subtitleColor,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Topic and expand icon row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.notification.topic,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedRotation(
                        turns: widget.notification.isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: cs.primary,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Message content
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? cs.surface : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.notification.message,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
