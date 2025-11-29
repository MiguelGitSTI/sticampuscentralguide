import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to cache Firebase data locally for offline access
class FirebaseCacheService {
  static final FirebaseCacheService _instance = FirebaseCacheService._internal();
  factory FirebaseCacheService() => _instance;
  FirebaseCacheService._internal();

  // Cache keys
  static const String _eventsKey = 'cached_events';
  static const String _notificationsKey = 'cached_notifications';
  static const String _eventsTimestampKey = 'cached_events_timestamp';
  static const String _notificationsTimestampKey = 'cached_notifications_timestamp';

  /// Cache events data
  Future<void> cacheEvents(List<Map<String, dynamic>> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert Timestamps to ISO strings for JSON serialization
      final serializable = events.map((e) {
        final copy = Map<String, dynamic>.from(e);
        if (copy['date'] is Timestamp) {
          copy['date'] = (copy['date'] as Timestamp).toDate().toIso8601String();
        }
        if (copy['createdAt'] is Timestamp) {
          copy['createdAt'] = (copy['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        return copy;
      }).toList();
      
      await prefs.setString(_eventsKey, jsonEncode(serializable));
      await prefs.setInt(_eventsTimestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('Cached ${events.length} events');
    } catch (e) {
      debugPrint('Failed to cache events: $e');
    }
  }

  /// Get cached events
  Future<List<Map<String, dynamic>>?> getCachedEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_eventsKey);
      if (cached == null) return null;
      
      final List<dynamic> decoded = jsonDecode(cached);
      return decoded.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        // Convert ISO strings back to DateTime for consistency
        if (map['date'] is String) {
          map['date'] = DateTime.parse(map['date'] as String);
        }
        if (map['createdAt'] is String) {
          map['createdAt'] = DateTime.parse(map['createdAt'] as String);
        }
        return map;
      }).toList();
    } catch (e) {
      debugPrint('Failed to get cached events: $e');
      return null;
    }
  }

  /// Cache notifications data
  Future<void> cacheNotifications(List<Map<String, dynamic>> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert Timestamps to ISO strings for JSON serialization
      final serializable = notifications.map((e) {
        final copy = Map<String, dynamic>.from(e);
        if (copy['createdAt'] is Timestamp) {
          copy['createdAt'] = (copy['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        return copy;
      }).toList();
      
      await prefs.setString(_notificationsKey, jsonEncode(serializable));
      await prefs.setInt(_notificationsTimestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('Cached ${notifications.length} notifications');
    } catch (e) {
      debugPrint('Failed to cache notifications: $e');
    }
  }

  /// Get cached notifications
  Future<List<Map<String, dynamic>>?> getCachedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_notificationsKey);
      if (cached == null) return null;
      
      final List<dynamic> decoded = jsonDecode(cached);
      return decoded.map((e) {
        final map = Map<String, dynamic>.from(e as Map);
        // Convert ISO strings back to DateTime for consistency
        if (map['createdAt'] is String) {
          map['createdAt'] = DateTime.parse(map['createdAt'] as String);
        }
        return map;
      }).toList();
    } catch (e) {
      debugPrint('Failed to get cached notifications: $e');
      return null;
    }
  }

  /// Get cache age in minutes
  Future<int?> getEventsCacheAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_eventsTimestampKey);
      if (timestamp == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now().difference(cacheTime).inMinutes;
    } catch (e) {
      return null;
    }
  }

  /// Get cache age in minutes
  Future<int?> getNotificationsCacheAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_notificationsTimestampKey);
      if (timestamp == null) return null;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now().difference(cacheTime).inMinutes;
    } catch (e) {
      return null;
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_eventsKey);
      await prefs.remove(_notificationsKey);
      await prefs.remove(_eventsTimestampKey);
      await prefs.remove(_notificationsTimestampKey);
      debugPrint('Cache cleared');
    } catch (e) {
      debugPrint('Failed to clear cache: $e');
    }
  }
}
