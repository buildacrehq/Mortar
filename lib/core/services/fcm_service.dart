import 'package:buildacre_crm/main.dart';

// ─── FCM Service (stub — activate when google-services.json is added) ─────────
// To enable:
//   1. Create Firebase project at console.firebase.google.com
//   2. Add google-services.json to android/app/
//   3. Uncomment firebase_core + firebase_messaging in pubspec.yaml
//   4. Uncomment Firebase.initializeApp() in main.dart
//   5. Replace this stub with the full implementation

class FcmService {
  static Future<void> initialize(String userId) async {
    // Stub — FCM disabled until Firebase is configured
  }

  static Future<void> clearToken(String userId) async {
    try {
      await supabase
          .from('profiles')
          .update({'fcm_token': null})
          .eq('id', userId);
    } catch (_) {}
  }
}
