import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

/// Background message handler - MUST be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background FCM message: ${message.messageId}');
  // The notification will be automatically shown by the system
  // We can add custom handling here if needed
}

/// Service to handle local notifications for class reminders
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone database
    tz.initializeTimeZones();

    // Get device timezone
    try {
      final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      // Fallback to UTC if timezone detection fails
      debugPrint('Failed to get timezone: $e. Using UTC.');
      tz.setLocalLocation(tz.UTC);
    }

    // Android initialization settings - using app icon
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;

    // Request permissions on Android 13+
    if (Platform.isAndroid) {
      await _requestAndroidPermissions();
    }
    
    // Initialize Firebase Cloud Messaging for background notifications
    await _initializeFirebaseMessaging();
  }
  
  /// Initialize Firebase Cloud Messaging
  Future<void> _initializeFirebaseMessaging() async {
    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Request permission for iOS
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Get FCM token (useful for sending targeted notifications)
    final token = await messaging.getToken();
    debugPrint('FCM Token: $token');
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground FCM message: ${message.messageId}');
      
      // Show local notification for foreground messages
      if (message.notification != null) {
        _showImmediateNotification(
          id: message.hashCode,
          title: message.notification!.title ?? 'Notification',
          body: message.notification!.body ?? '',
          payload: message.data.toString(),
        );
      }
    });
    
    // Handle notification tap when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM notification opened app: ${message.messageId}');
      // Handle navigation based on message data if needed
    });
    
    debugPrint('Firebase Messaging initialized');
  }

  /// Request notification permissions on Android 13+
  Future<void> _requestAndroidPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // You can add navigation logic here if needed
  }

  /// Schedule class notifications for today
  /// Call this when the app starts or when the user logs in
  Future<void> scheduleClassNotifications() async {
    // Cancel all existing notifications first to avoid duplicates
    await _notificationsPlugin.cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final String fullName = prefs.getString('user_full_name') ?? 'Student';
    final String section = (prefs.getString('user_section') ?? 'MAWD302').trim();

    // Load class schedule
    final classes = await _loadClassesForToday(section);

    if (classes.isEmpty) {
      debugPrint('No classes to schedule notifications for today');
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    int notificationId = 0;

    for (final classItem in classes) {
      // Calculate the notification time (10 minutes before class)
      final classStartTime = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        classItem['startHour'] as int,
        classItem['startMinute'] as int,
      );

      // Notification time is 10 minutes before class
      final notificationTime =
          classStartTime.subtract(const Duration(minutes: 10));

      // Only schedule if the notification time is in the future
      if (notificationTime.isAfter(now)) {
        final String className = classItem['name'] as String;
        final String room = classItem['room'] as String;
        final String time = classItem['time'] as String;

        await _scheduleNotification(
          id: notificationId,
          title: 'Class at $room! 📚',
          body: 'Dear $fullName, $className starts at $time!',
          scheduledTime: notificationTime,
          payload: 'class_$className',
        );

        debugPrint(
            'Scheduled notification for $className at ${notificationTime.toString()}');
        notificationId++;
      }
    }

    debugPrint('Scheduled $notificationId class notifications for today');
  }

  /// Load classes for today from JSON
  Future<List<Map<String, dynamic>>> _loadClassesForToday(
      String section) async {
    try {
      String jsonStr;
      try {
        final path = 'assets/data/schedules/${section.toUpperCase()}.json';
        jsonStr = await rootBundle.loadString(path);
      } catch (_) {
        // Fallback to legacy single-schedule file
        jsonStr = await rootBundle.loadString('assets/data/class_schedule.json');
      }

      final Map<String, dynamic> decoded =
          json.decode(jsonStr) as Map<String, dynamic>;

      final now = DateTime.now();
      final String dayKey = _dayKeyFor(now.weekday);
      final dynamic dayData = decoded[dayKey];

      if (dayData is List) {
        return dayData.cast<Map<String, dynamic>>();
      }

      return <Map<String, dynamic>>[];
    } catch (e) {
      debugPrint('Error loading class schedule: $e');
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

  /// Schedule a single notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'class_reminders',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Class reminder',
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Show an immediate notification (for testing)
  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'class_reminders',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      999,
      'Test Notification 🔔',
      'This is a test class reminder notification!',
      notificationDetails,
      payload: 'test_notification',
    );
  }

  /// Show immediate notifications for all today's classes (for admin testing)
  Future<void> showImmediateClassNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final String fullName = prefs.getString('user_full_name') ?? 'Student';
    final String section = (prefs.getString('user_section') ?? 'MAWD302').trim();

    // Load class schedule
    final classes = await _loadClassesForToday(section);

    if (classes.isEmpty) {
      debugPrint('No classes to send notifications for today');
      // Show a notification saying no classes
      await _showImmediateNotification(
        id: 1000,
        title: 'No Classes Today 📅',
        body: 'There are no scheduled classes for today.',
      );
      return;
    }

    int notificationId = 1001;
    for (final classItem in classes) {
      final String className = classItem['name'] as String;
      final String room = classItem['room'] as String;
      final String time = classItem['time'] as String;

      await _showImmediateNotification(
        id: notificationId,
        title: 'Class at $room! 📚',
        body: 'Dear $fullName, $className starts at $time!',
        payload: 'class_$className',
      );

      debugPrint('Sent immediate notification for $className');
      notificationId++;
      
      // Small delay between notifications to prevent overwhelming
      await Future.delayed(const Duration(milliseconds: 500));
    }

    debugPrint('Sent $notificationId immediate class notifications');
  }

  /// Get today's classes for display in admin panel
  Future<List<Map<String, dynamic>>> getTodayClasses() async {
    final prefs = await SharedPreferences.getInstance();
    final String section = (prefs.getString('user_section') ?? 'MAWD302').trim();
    return _loadClassesForToday(section);
  }

  /// Show immediate notification for a single class (for admin testing)
  Future<void> showSingleClassNotification(Map<String, dynamic> classItem) async {
    final prefs = await SharedPreferences.getInstance();
    final String fullName = prefs.getString('user_full_name') ?? 'Student';

    final String className = classItem['name'] as String;
    final String room = classItem['room'] as String;
    final String time = classItem['time'] as String;

    await _showImmediateNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: 'Class at $room! 📚',
      body: 'Dear $fullName, $className starts at $time!',
      payload: 'class_$className',
    );

    debugPrint('Sent immediate notification for $className');
  }

  /// Show a single immediate notification
  Future<void> _showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'class_reminders',
      'Class Reminders',
      channelDescription: 'Notifications for upcoming classes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Get pending notification count
  Future<int> getPendingNotificationCount() async {
    final List<PendingNotificationRequest> pending =
        await _notificationsPlugin.pendingNotificationRequests();
    return pending.length;
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firebaseSubscription;
  Set<String> _shownNotificationIds = {};

  /// Start listening to Firebase class notifications and show them as local notifications
  Future<void> startFirebaseNotificationListener() async {
    // Cancel existing subscription if any
    await _firebaseSubscription?.cancel();
    
    // Load already shown notification IDs from prefs
    final prefs = await SharedPreferences.getInstance();
    final shownIds = prefs.getStringList('shown_firebase_notification_ids') ?? [];
    _shownNotificationIds = shownIds.toSet();

    _firebaseSubscription = FirebaseFirestore.instance
        .collection('class_notifications')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) async {
      // Only process document changes, not the entire snapshot
      for (final change in snapshot.docChanges) {
        // Only show notification for newly added documents
        if (change.type != DocumentChangeType.added) continue;
        
        final doc = change.doc;
        final docId = doc.id;
        
        // Skip if we've already shown this notification
        if (_shownNotificationIds.contains(docId)) continue;
        
        final data = doc.data();
        if (data == null) continue;
        
        final ts = data['createdAt'];
        if (ts == null) continue;

        DateTime createdAt;
        if (ts is Timestamp) {
          createdAt = ts.toDate();
        } else {
          continue;
        }

        // Only show notifications from the last 5 minutes (to avoid old ones on app start)
        final now = DateTime.now();
        if (now.difference(createdAt).inMinutes > 5) {
          // Mark as shown so we don't check again
          _shownNotificationIds.add(docId);
          continue;
        }

        final title = data['title'] as String? ?? 'Class Notification';
        final body = data['body'] as String? ?? '';

        await _showImmediateNotification(
          id: docId.hashCode,
          title: title,
          body: body,
          payload: 'firebase_class_$docId',
        );

        // Mark this notification as shown
        _shownNotificationIds.add(docId);
        
        // Persist shown IDs (keep only last 50 to prevent unbounded growth)
        if (_shownNotificationIds.length > 50) {
          _shownNotificationIds = _shownNotificationIds.toList().sublist(_shownNotificationIds.length - 50).toSet();
        }
        await prefs.setStringList('shown_firebase_notification_ids', _shownNotificationIds.toList());
        
        debugPrint('Showed Firebase notification: $title');
      }
    }, onError: (e) {
      debugPrint('Firebase notification listener error: $e');
    });
  }

  /// Stop listening to Firebase class notifications
  Future<void> stopFirebaseNotificationListener() async {
    await _firebaseSubscription?.cancel();
    _firebaseSubscription = null;
  }
}