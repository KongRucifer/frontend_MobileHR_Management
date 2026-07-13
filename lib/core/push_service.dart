import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../firebase_options.dart';
import 'api.dart';
import 'storage.dart';

/// Firebase Cloud Messaging setup. Registers the device's FCM token with the
/// backend so approvers get push notifications when it's their turn.
///
/// Safe to call before `flutterfire configure` has been run — if Firebase
/// isn't configured yet, it fails silently (in-app notifications still work).
class PushService {
  static bool _inited = false;

  static Future<void> setup() async {
    try {
      if (!_inited) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _inited = true;
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null) await _register(token);
      messaging.onTokenRefresh.listen(_register);
    } catch (_) {
      // Firebase not configured yet — run `flutterfire configure`.
    }
  }

  static Future<void> _register(String token) async {
    try {
      if (await Storage.getToken() == null) return; // only when logged in
      await Api.dio.post('/notifications/device-token', data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
    } catch (_) {}
  }

  static Future<void> unregister() async {
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) {
        await Api.dio.delete('/notifications/device-token', data: {'token': t});
      }
    } catch (_) {}
  }
}
