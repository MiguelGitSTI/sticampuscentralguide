import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// Task identifiers
const String taskScheduleClassNotifications = 'scheduleClassNotifications';
const String taskDailyRefresh = 'dailyRefresh';

/// This is the callback that runs in the background isolate
/// MUST be a top-level function (not inside a class)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('Background task started: $task');
    
    try {
      switch (task) {
        case taskScheduleClassNotifications:
          await _scheduleClassNotificationsInBackground();
          break;
        case taskDailyRefresh:
          await _dailyRefreshTask();
          break;
        case Workmanager.iOSBackgroundTask:
          // iOS background fetch
          await _scheduleClassNotificationsInBackground();
          break;
        default:
          debugPrint('Unknown task: $task');
      }
      return true;
    } catch (e) {
      debugPrint('Background task error: $e');
      return false;
    }
  });
}

/// Schedule class notifications from background
Future<void> _scheduleClassNotificationsInBackground() async {
  // Initialize timezone
  tz.initializeTimeZones();
  
  final prefs = await SharedPreferences.getInstance();
  final String fullName = prefs.getString('user_full_name') ?? 'Student';
  final String section = (prefs.getString('user_section') ?? 'MAWD302').trim();
  
  // Load classes for today
  final classes = await _loadClassesForToday(section);
  
  if (classes.isEmpty) {
    debugPrint('Background: No classes to schedule');
    return;
  }
  
  // Initialize notifications plugin
  final FlutterLocalNotificationsPlugin notificationsPlugin = 
      FlutterLocalNotificationsPlugin();
  
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
  );
  
  await notificationsPlugin.initialize(initSettings);
  
  // Cancel existing notifications to avoid duplicates
  await notificationsPlugin.cancelAll();
  
  final now = DateTime.now();
  int notificationId = 0;
  
  for (final classItem in classes) {
    final int startHour = classItem['startHour'] as int;
    final int startMinute = classItem['startMinute'] as int;
    
    // Calculate notification time (10 minutes before class)
    final classStartTime = DateTime(
      now.year,
      now.month,
      now.day,
      startHour,
      startMinute,
    );
    
    final notificationTime = classStartTime.subtract(const Duration(minutes: 10));
    
    // Only schedule if notification time is in the future
    if (notificationTime.isAfter(now)) {
      final String className = classItem['name'] as String;
      final String room = classItem['room'] as String;
      final String time = classItem['time'] as String;
      
      // Schedule the notification
      await notificationsPlugin.zonedSchedule(
        notificationId,
        'Class at $room! 📚',
        'Dear $fullName, $className starts at $time!',
        tz.TZDateTime.from(notificationTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'class_reminders',
            'Class Reminders',
            channelDescription: 'Notifications for upcoming classes',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      debugPrint('Background: Scheduled notification for $className at $notificationTime');
      notificationId++;
    }
  }
  
  debugPrint('Background: Scheduled $notificationId notifications');
}

/// Daily refresh task - reschedule notifications for the new day
Future<void> _dailyRefreshTask() async {
  await _scheduleClassNotificationsInBackground();
  debugPrint('Background: Daily refresh completed');
}

/// Load classes for today from assets
Future<List<Map<String, dynamic>>> _loadClassesForToday(String section) async {
  try {
    String jsonStr;
    try {
      final path = 'assets/data/schedules/${section.toUpperCase()}.json';
      jsonStr = await rootBundle.loadString(path);
    } catch (_) {
      jsonStr = await rootBundle.loadString('assets/data/class_schedule.json');
    }
    
    final Map<String, dynamic> decoded = json.decode(jsonStr) as Map<String, dynamic>;
    
    final now = DateTime.now();
    final String dayKey = _dayKeyFor(now.weekday);
    final dynamic dayData = decoded[dayKey];
    
    if (dayData is List) {
      return dayData.cast<Map<String, dynamic>>();
    }
    
    return <Map<String, dynamic>>[];
  } catch (e) {
    debugPrint('Background: Error loading schedule: $e');
    return <Map<String, dynamic>>[];
  }
}

String _dayKeyFor(int weekday) {
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
      return 'sunday';
  }
}

/// Service class to manage background tasks
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();
  
  bool _isInitialized = false;
  
  /// Initialize the background service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
    
    _isInitialized = true;
    debugPrint('BackgroundService initialized');
  }
  
  /// Register periodic task to reschedule notifications daily
  Future<void> registerDailyTask() async {
    // Cancel any existing tasks first
    await Workmanager().cancelAll();
    
    // Register a periodic task that runs every 12 hours
    // This ensures class notifications are always scheduled
    await Workmanager().registerPeriodicTask(
      'daily_class_notifications',
      taskDailyRefresh,
      frequency: const Duration(hours: 12),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
    
    debugPrint('Daily background task registered');
  }
  
  /// Run the notification scheduling task immediately
  Future<void> scheduleClassNotificationsNow() async {
    await Workmanager().registerOneOffTask(
      'immediate_class_notifications',
      taskScheduleClassNotifications,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    
    debugPrint('Immediate notification task queued');
  }
  
  /// Cancel all background tasks
  Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
    debugPrint('All background tasks cancelled');
  }
}
