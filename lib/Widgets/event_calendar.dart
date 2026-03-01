import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sticampuscentralguide/utils/firebase_cache_service.dart';

class EventCalendar extends StatefulWidget {
  const EventCalendar({super.key});

  @override
  State<EventCalendar> createState() => _EventCalendarState();
}

class _EventCalendarState extends State<EventCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Stream<QuerySnapshot<Map<String, dynamic>>>? _eventsStream;
  List<_CalendarEvent>? _cachedEvents;
  bool _isLoadingCache = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadCachedEvents();
    _eventsStream = FirebaseFirestore.instance
        .collection('events')
        .orderBy('date', descending: false)
        .limit(50)
        .snapshots();
  }

  Future<void> _loadCachedEvents() async {
    final cached = await FirebaseCacheService().getCachedEvents();
    if (cached != null && mounted) {
      setState(() {
        _cachedEvents = cached.map(_parseEvent).toList();
        _isLoadingCache = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingCache = false);
    }
  }

  _CalendarEvent _parseEvent(Map<String, dynamic> d) {
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

    DateTime? endDate;
    final endTs = d['endDate'];
    if (endTs is DateTime) {
      endDate = endTs;
    } else if (endTs is Timestamp) {
      endDate = endTs.toDate();
    } else if (endTs is String) {
      endDate = DateTime.tryParse(endTs);
    }

    // Prefer startTime/endTime, fall back to old 'time' field
    String timeDisplay;
    final startTime = d['startTime'] as String?;
    final endTime = d['endTime'] as String?;
    if (startTime != null && startTime.isNotEmpty &&
        endTime != null && endTime.isNotEmpty) {
      timeDisplay = '$startTime – $endTime';
    } else {
      timeDisplay = d['time'] as String? ?? '';
    }

    return _CalendarEvent(
      title: d['title'] as String? ?? '',
      date: date,
      endDate: endDate,
      time: timeDisplay,
      location: d['location'] as String? ?? '',
      description: d['description'] as String? ?? '',
    );
  }

  List<_CalendarEvent> _parseFirestoreEvents(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    // Also cache them
    final raw = docs.map((doc) {
      final d = doc.data();
      return {
        'title': d['title'],
        'date': d['date'],
        'endDate': d['endDate'],
        'time': d['time'],
        'startTime': d['startTime'],
        'endTime': d['endTime'],
        'location': d['location'],
        'description': d['description'],
      };
    }).toList();
    FirebaseCacheService().cacheEvents(raw);

    return docs.map((doc) {
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

      DateTime? endDate;
      final endTs = d['endDate'];
      if (endTs is Timestamp) {
        endDate = endTs.toDate();
      } else if (endTs is String) {
        endDate = DateTime.tryParse(endTs);
      }

      // Prefer startTime/endTime, fall back to old 'time' field
      String timeDisplay;
      final startTime = d['startTime'] as String?;
      final endTime = d['endTime'] as String?;
      if (startTime != null && startTime.isNotEmpty &&
          endTime != null && endTime.isNotEmpty) {
        timeDisplay = '$startTime – $endTime';
      } else {
        timeDisplay = d['time'] as String? ?? '';
      }

      return _CalendarEvent(
        title: d['title'] as String? ?? '',
        date: date,
        endDate: endDate,
        time: timeDisplay,
        location: d['location'] as String? ?? '',
        description: d['description'] as String? ?? '',
      );
    }).toList();
  }

  /// Group events by day (normalized to midnight).
  /// Multi-day events are added to every day in their range.
  Map<DateTime, List<_CalendarEvent>> _groupByDay(List<_CalendarEvent> events) {
    final map = <DateTime, List<_CalendarEvent>>{};
    for (final e in events) {
      final startKey = DateTime(e.date.year, e.date.month, e.date.day);
      if (e.endDate != null) {
        final endKey = DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day);
        var current = startKey;
        while (!current.isAfter(endKey)) {
          map.putIfAbsent(current, () => []).add(e);
          current = current.add(const Duration(days: 1));
        }
      } else {
        map.putIfAbsent(startKey, () => []).add(e);
      }
    }
    return map;
  }

  List<_CalendarEvent> _getEventsForDay(
      DateTime day, Map<DateTime, List<_CalendarEvent>> grouped) {
    final key = DateTime(day.year, day.month, day.day);
    return grouped[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _eventsStream,
      builder: (context, snapshot) {
        List<_CalendarEvent> events;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          events = _parseFirestoreEvents(snapshot.data!.docs);
          _cachedEvents = events;
        } else if (_cachedEvents != null && _cachedEvents!.isNotEmpty) {
          events = _cachedEvents!;
        } else if (snapshot.connectionState == ConnectionState.waiting &&
            _isLoadingCache) {
          return const Center(child: CircularProgressIndicator());
        } else {
          events = [];
        }

        final grouped = _groupByDay(events);
        final selectedEvents = _selectedDay != null
            ? _getEventsForDay(_selectedDay!, grouped)
            : <_CalendarEvent>[];

        return _buildCalendarUI(grouped, selectedEvents);
      },
    );
  }

  Widget _buildCalendarUI(
    Map<DateTime, List<_CalendarEvent>> grouped,
    List<_CalendarEvent> selectedEvents,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceContainerHighest : cs.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? [
                    const BoxShadow(
                      color: Color(0xCC000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ]
                : [
                    const BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: TableCalendar<_CalendarEvent>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: (day) => _getEventsForDay(day, grouped),
              startingDayOfWeek: StartingDayOfWeek.monday,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF123CBE).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Color(0xFF123CBE),
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                defaultTextStyle: TextStyle(color: cs.onSurface),
                weekendTextStyle: TextStyle(color: cs.onSurface.withOpacity(0.7)),
                outsideTextStyle: TextStyle(color: cs.onSurface.withOpacity(0.3)),
                markerDecoration: const BoxDecoration(
                  color: Color(0xFFFFB206),
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                markerSize: 6,
                markerMargin: const EdgeInsets.symmetric(horizontal: 1),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                formatButtonShowsNext: false,
                titleCentered: true,
                formatButtonDecoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF123CBE)),
                  borderRadius: BorderRadius.circular(12),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: Color(0xFF123CBE),
                  fontSize: 12,
                ),
                titleTextStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: cs.onSurface,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: cs.onSurface,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: cs.onSurface.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                weekendStyle: TextStyle(
                  color: cs.onSurface.withOpacity(0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Selected day events
        if (selectedEvents.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              _formatDayHeader(_selectedDay!),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          ...selectedEvents.map((e) => _EventTile(event: e)),
        ] else if (_selectedDay != null) ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No events on this day',
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatDayHeader(DateTime day) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[day.month - 1]} ${day.day}, ${day.year}';
  }
}

class _EventTile extends StatelessWidget {
  final _CalendarEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    // "Today" if today falls within the event's date range
    final startKey = DateTime(event.date.year, event.date.month, event.date.day);
    final endKey = event.endDate != null
        ? DateTime(event.endDate!.year, event.endDate!.month, event.endDate!.day)
        : startKey;
    final isToday = !todayKey.isBefore(startKey) && !todayKey.isAfter(endKey);
    final isMultiDay = event.endDate != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFF123CBE)
            : (isDark ? cs.surfaceContainerHighest : cs.surface),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? [
                const BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ]
            : [
                const BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isToday ? Colors.white : cs.onSurface,
                  ),
                ),
              ),
              if (isMultiDay)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isToday
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFF123CBE).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'MULTI-DAY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: isToday ? Colors.white70 : const Color(0xFF123CBE),
                    ),
                  ),
                ),
              if (isToday)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB206),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'TODAY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF123CBE),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.access_time, size: 13,
                  color: isToday
                      ? Colors.white70
                      : cs.onSurface.withOpacity(0.6)),
              const SizedBox(width: 4),
              Text(
                event.time,
                style: TextStyle(
                  fontSize: 13,
                  color: isToday
                      ? Colors.white70
                      : cs.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.location_on_outlined, size: 13,
                  color: isToday
                      ? Colors.white70
                      : cs.onSurface.withOpacity(0.6)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  event.location,
                  style: TextStyle(
                    fontSize: 13,
                    color: isToday
                        ? Colors.white70
                        : cs.onSurface.withOpacity(0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (event.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              event.description,
              style: TextStyle(
                fontSize: 12,
                color: isToday
                    ? Colors.white.withOpacity(0.85)
                    : cs.onSurface.withOpacity(0.7),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _CalendarEvent {
  final String title;
  final DateTime date;
  final DateTime? endDate;
  final String time;
  final String location;
  final String description;

  _CalendarEvent({
    required this.title,
    required this.date,
    this.endDate,
    required this.time,
    required this.location,
    required this.description,
  });
}
