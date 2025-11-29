import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sticampuscentralguide/utils/firebase_cache_service.dart';

class EventCarousel extends StatefulWidget {
  const EventCarousel({super.key});

  @override
  State<EventCarousel> createState() => _EventCarouselState();
}

class _EventCarouselState extends State<EventCarousel> {
  PageController? _pageController;
  int _currentPage = 0;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _eventsStream;
  List<EventItem>? _cachedEvents;
  bool _isLoadingCache = true;

  @override
  void initState() {
    super.initState();
    _loadCachedEvents();
    _eventsStream = FirebaseFirestore.instance
        .collection('events')
        .orderBy('date', descending: false)
        .limit(20)
        .snapshots();
  }

  Future<void> _loadCachedEvents() async {
    final cached = await FirebaseCacheService().getCachedEvents();
    if (cached != null && mounted) {
      setState(() {
        _cachedEvents = cached.map((d) {
          final ts = d['date'];
          DateTime date;
          if (ts is DateTime) {
            date = ts;
          } else if (ts is Timestamp) {
            date = ts.toDate();
          } else if (ts is String) {
            date = DateTime.tryParse(ts) ?? DateTime.now();
          } else {
            date = DateTime.now();
          }
          return EventItem(
            title: d['title'] as String? ?? '',
            date: date,
            time: d['time'] as String? ?? '',
            location: d['location'] as String? ?? '',
            description: d['description'] as String? ?? '',
          );
        }).toList();
        _isLoadingCache = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingCache = false);
    }
  }

  void _cacheEvents(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final events = docs.map((doc) {
      final d = doc.data();
      return {
        'title': d['title'],
        'date': d['date'],
        'time': d['time'],
        'location': d['location'],
        'description': d['description'],
      };
    }).toList();
    FirebaseCacheService().cacheEvents(events);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _ensureController(int eventCount) {
    if (_pageController == null) {
      _pageController = PageController(
        viewportFraction: 0.85,
        initialPage: _currentPage,
      );
    }
    // Ensure _currentPage is within bounds
    if (_currentPage >= eventCount && eventCount > 0) {
      _currentPage = eventCount - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        // Show cached data while loading or on error
        if (snapshot.hasError || 
            (snapshot.connectionState == ConnectionState.waiting && !_isLoadingCache)) {
          if (_cachedEvents != null && _cachedEvents!.isNotEmpty) {
            return _buildCarousel(_cachedEvents!, today, isOffline: snapshot.hasError);
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Unable to load events',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            );
          }
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show cached events while waiting for fresh data
          if (_cachedEvents != null && _cachedEvents!.isNotEmpty) {
            return _buildCarousel(_cachedEvents!, today, isOffline: false);
          }
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // Show cached events if Firebase has no data
          if (_cachedEvents != null && _cachedEvents!.isNotEmpty) {
            return _buildCarousel(_cachedEvents!, today, isOffline: true);
          }
          return Center(
            child: Text(
              'No upcoming events',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.7),
              ),
            ),
          );
        }

        // Cache the fresh data
        _cacheEvents(snapshot.data!.docs);

        final events = snapshot.data!.docs.map((doc) {
          final d = doc.data();
          final ts = d['date'];
          DateTime date;
          if (ts is Timestamp) {
            date = ts.toDate();
          } else if (ts is String) {
            date = DateTime.tryParse(ts) ?? DateTime.now();
          } else {
            date = DateTime.now();
          }
          return EventItem(
            title: d['title'] as String? ?? '',
            date: date,
            time: d['time'] as String? ?? '',
            location: d['location'] as String? ?? '',
            description: d['description'] as String? ?? '',
          );
        }).toList();

        // Update cached events for immediate access
        _cachedEvents = events;

        return _buildCarousel(events, today, isOffline: false);
      },
    );
  }

  Widget _buildCarousel(List<EventItem> events, DateTime today, {bool isOffline = false}) {
    if (events.isEmpty) {
      return Center(
        child: Text(
          'No upcoming events',
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withOpacity(0.7),
          ),
        ),
      );
    }

    // Initialize or update controller based on event count
    _ensureController(events.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isOffline)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 14,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Cached',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _pageController!,
            itemCount: events.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final event = events[index];
              final isToday = _isSameDay(event.date, today);

              return Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                child: _EventCard(event: event, isToday: isToday),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Dots indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(events.length, (index) {
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
        ),
      ],
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}

class _EventCard extends StatelessWidget {
  final EventItem event;
  final bool isToday;

  const _EventCard({required this.event, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isToday 
            ? const Color(0xFF123CBE)
            : (isDark ? cs.surfaceVariant : cs.surface),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? const [
                // Dark, subtle shadows in dark mode (no white glow)
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
            : [
                // Tighter, more natural light-mode shadow
                BoxShadow(
                  color: const Color(0x18000000),
                  blurRadius: 6,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: const Color(0x12000000),
                  blurRadius: 2,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isToday ? Colors.white : cs.onSurface,
                    ),
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB206),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF123CBE),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Time above date to avoid horizontal overflow; both wrap if needed
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: isToday 
                          ? Colors.white.withOpacity(0.9)
                          : cs.onSurface.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.time,
                        style: TextStyle(
                          fontSize: 14,
                          color: isToday 
                              ? Colors.white.withOpacity(0.9)
                              : cs.onSurface.withOpacity(0.7),
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: isToday 
                          ? Colors.white.withOpacity(0.9)
                          : cs.onSurface.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatDate(event.date),
                        style: TextStyle(
                          fontSize: 14,
                          color: isToday 
                              ? Colors.white.withOpacity(0.9)
                              : cs.onSurface.withOpacity(0.7),
                        ),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: isToday 
                      ? Colors.white.withOpacity(0.9)
                      : cs.onSurface.withOpacity(0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  event.location,
                  style: TextStyle(
                    fontSize: 14,
                    color: isToday 
                        ? Colors.white.withOpacity(0.9)
                        : cs.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.description,
              style: TextStyle(
                fontSize: 13,
                color: isToday 
                    ? Colors.white.withOpacity(0.85)
                    : cs.onSurface.withOpacity(0.8),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class EventItem {
  final String title;
  final DateTime date;
  final String time;
  final String location;
  final String description;

  EventItem({
    required this.title,
    required this.date,
    required this.time,
    required this.location,
    required this.description,
  });
}
