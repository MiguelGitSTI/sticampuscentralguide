import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class ClassSchedule extends StatefulWidget {
  const ClassSchedule({super.key});

  @override
  State<ClassSchedule> createState() => _ClassScheduleState();
}

class _ClassScheduleState extends State<ClassSchedule> {
  late Future<List<ClassItem>> _classesFuture;

  @override
  void initState() {
    super.initState();
    _classesFuture = _loadClasses();
  }

  Future<List<ClassItem>> _loadClasses() async {
    try {
      // Determine selected section (default to MAWD302)
      final prefs = await SharedPreferences.getInstance();
      final section = (prefs.getString('user_section') ?? 'MAWD302').trim();

      // Try section-based schedule first
      String jsonStr;
      try {
        final path = 'assets/data/schedules/${section.toUpperCase()}.json';
        jsonStr = await rootBundle.loadString(path);
      } catch (_) {
        // Fallback to legacy single-schedule file
        jsonStr = await rootBundle.loadString('assets/data/class_schedule.json');
      }

      final Map<String, dynamic> decoded = json.decode(jsonStr) as Map<String, dynamic>;

      final now = DateTime.now();
      final String dayKey = _dayKeyFor(now.weekday);
      final dynamic dayData = decoded[dayKey];

      if (dayData is List) {
        return dayData
            .map((e) => ClassItem.fromJson(e as Map<String, dynamic>))
            .toList(growable: false);
      }

      return <ClassItem>[];
    } catch (_) {
      return <ClassItem>[];
    }
  }

  String _dayKeyFor(int weekday) {
    // DateTime.weekday: 1 = Monday, ..., 7 = Sunday
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
      default:
        // No classes on Sunday by default; map to an empty day.
        return 'wednesday';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = TimeOfDay.now();

    return FutureBuilder<List<ClassItem>>(
      future: _classesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final classes = snapshot.data ?? <ClassItem>[];
        if (classes.isEmpty) {
          return Center(
            child: Text(
              'No classes scheduled',
              style: TextStyle(
                fontSize: 16,
                color: cs.onSurface.withOpacity(0.7),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceVariant : cs.surface,
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
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: classes.length,
                itemBuilder: (context, index) {
                  final classItem = classes[index];
                  // Only highlight ongoing classes, not ended ones
                  final isOngoing = _isClassOngoing(classItem, now);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isOngoing
                                ? const Color(0xFF123CBE)
                                : cs.outlineVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isOngoing
                                  ? const Color(0xFF123CBE).withOpacity(0.1)
                                  : cs.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                              border: isOngoing
                                  ? Border.all(
                                      color: const Color(0xFF123CBE),
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  classItem.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isOngoing
                                        ? const Color(0xFF123CBE)
                                        : cs.onSurface,
                                  ),
                                  softWrap: true,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _compactTime(classItem.time),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurface.withOpacity(0.7),
                                  ),
                                  softWrap: true,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  classItem.room,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  bool _isClassOngoing(ClassItem classItem, TimeOfDay now) {
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = classItem.startHour * 60 + classItem.startMinute;
    final endMinutes = classItem.endHour * 60 + classItem.endMinute;
    
    // Only highlight if class is currently in progress (started but not ended)
    // Do NOT highlight if class has ended (nowMinutes >= endMinutes)
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }

  // Converts a time like "8:00 AM - 9:30 AM" to "8:00-9:30"
  String _compactTime(String timeRange) {
    // Split on dash and trim
    final parts = timeRange.split('-');
    if (parts.length != 2) return timeRange;
    String start = parts[0].trim();
    String end = parts[1].trim();
    // Remove AM/PM and extra spaces
    start = start.replaceAll(RegExp(r'\s*(AM|PM)', caseSensitive: false), '');
    end = end.replaceAll(RegExp(r'\s*(AM|PM)', caseSensitive: false), '');
    return '$start-$end';
  }
}

class ClassItem {
  final String name;
  final String time;
  final String room;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;

  ClassItem({
    required this.name,
    required this.time,
    required this.room,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  factory ClassItem.fromJson(Map<String, dynamic> json) {
    return ClassItem(
      name: json['name'] as String? ?? '',
      time: json['time'] as String? ?? '',
      room: json['room'] as String? ?? '',
      startHour: json['startHour'] as int? ?? 0,
      startMinute: json['startMinute'] as int? ?? 0,
      endHour: json['endHour'] as int? ?? 0,
      endMinute: json['endMinute'] as int? ?? 0,
    );
  }
}
