import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:buildacre_crm/main.dart';

// ─── FCM Service ──────────────────────────────────────────────────────────────
// Handles push notification setup and token management
// Called once after user logs in

class FcmService {
  static final _messaging = FirebaseMessaging.instance;

  /// Initialize FCM — request permission and save token to Supabase
  static Future<void> initialize(String userId) async {
    try {
      // Request permission (iOS requires explicit permission)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return; // User denied — no notifications
      }

      // Get FCM token for this device
      final token = await _messaging.getToken();
      if (token == null) return;

      // Save token to Supabase profiles
      await supabase
          .from('profiles')
          .update({'fcm_token': token})
          .eq('id', userId);

      // Listen for token refresh (device resets token periodically)
      _messaging.onTokenRefresh.listen((newToken) async {
        await supabase
            .from('profiles')
            .update({'fcm_token': newToken})
            .eq('id', userId);
      });

      // Handle notification when app is in foreground
      FirebaseMessaging.onMessage.listen((message) {
        // In-app notification already shown via Mortar notification center
        // No need to show duplicate system notification
        print('[FCM] Foreground message: ${message.notification?.title}');
      });

      print('[FCM] Initialized for user $userId — token saved');
    } catch (e) {
      // FCM not configured yet (no google-services.json) — silently skip
      print('[FCM] Not configured: $e');
    }
  }

  /// Clear FCM token on logout
  static Future<void> clearToken(String userId) async {
    try {
      await supabase
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', userId);
    } catch (_) {}
  }
}
