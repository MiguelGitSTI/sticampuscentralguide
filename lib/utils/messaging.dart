import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MessagingHelper {
  static const _sectionKey = 'user_section';
  static const _lastSubscribedSectionKey = 'messaging_last_section';
  static const _defaultSection = 'MAWD302';

  static String _normalizeTopic(String v) => v.trim().toLowerCase();

  static Future<void> ensureTopicSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final sectionRaw = prefs.getString(_sectionKey) ?? _defaultSection;
    final section = _normalizeTopic(sectionRaw);
    final lastRaw = prefs.getString(_lastSubscribedSectionKey);
    final lastNorm = lastRaw == null ? null : _normalizeTopic(lastRaw);

    // Always ensure subscription to the global topic
    await FirebaseMessaging.instance.subscribeToTopic('all');

    // If the stored topic differs from the normalized current topic, unsubscribe old.
    if (lastRaw != null && lastRaw.isNotEmpty && lastNorm != section) {
      await FirebaseMessaging.instance.unsubscribeFromTopic(lastRaw);
      // Safety: if a previous version normalized differently, unsubscribe that too.
      if (lastNorm != null && lastNorm != lastRaw && lastNorm != section) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(lastNorm);
      }
    }

    // Subscribe to the current section topic
    await FirebaseMessaging.instance.subscribeToTopic(section);
    await prefs.setString(_lastSubscribedSectionKey, section);
  }
}
