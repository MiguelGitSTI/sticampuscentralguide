import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessagingHelper {
  static const _sectionKey = 'user_section';
  static const _lastSubscribedSectionKey = 'messaging_last_section';
  static const _defaultSection = 'MAWD302';

  static Future<void> ensureTopicSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final section = prefs.getString(_sectionKey) ?? _defaultSection;
    final last = prefs.getString(_lastSubscribedSectionKey);

    // Always ensure subscription to the global topic
    await FirebaseMessaging.instance.subscribeToTopic('all');

    if (last != section && last != null && last.isNotEmpty) {
      // Unsubscribe from the old section if it changed
      await FirebaseMessaging.instance.unsubscribeFromTopic(last);
    }

    // Subscribe to the current section topic
    await FirebaseMessaging.instance.subscribeToTopic(section);
    await prefs.setString(_lastSubscribedSectionKey, section);
  }
}
