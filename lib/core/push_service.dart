import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';
import 'api.dart';
import 'storage.dart';

/// Notification channel id — MUST match the `default_notification_channel_id`
/// meta-data in AndroidManifest.xml, so that FCM "notification" messages that
/// arrive while the app is in the background / killed are routed to this channel
/// and play our custom sound.
const String kNotifChannelId = 'hr_notifications';
const String kNotifChannelName = 'HR Notifications';
const String kNotifChannelDesc = 'Approval updates and HR alerts';

/// Custom sound, bundled at:
///   android/app/src/main/res/raw/notification_sound.mp3
/// (Android references raw resources by name, WITHOUT the extension.)
const RawResourceAndroidNotificationSound _kSound =
    RawResourceAndroidNotificationSound('notification_sound');

/// Custom sound for iOS, bundled in the Runner app bundle as:
///   ios/Runner/notification_sound.wav
/// (iOS references it BY FILENAME WITH EXTENSION; mp3 isn't supported for
/// notification sounds, so it's shipped as a Linear-PCM WAV.)
/// The same filename must be sent as the APNS `sound` by the backend so
/// background / terminated notifications ring too.
const String kIosSoundFile = 'notification_sound.wav';

final FlutterLocalNotificationsPlugin _localNotifs =
    FlutterLocalNotificationsPlugin();

/// Background / terminated message handler. Must be a top-level function marked
/// with @pragma so it survives tree-shaking and can run in its own isolate.
///
/// For plain "notification" messages Android draws the tray notification itself
/// (on our default channel → the custom sound plays). We only build one manually
/// for data-only messages, which the OS would otherwise show silently.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Platform.isAndroid && message.notification == null && message.data.isNotEmpty) {
    await PushService.ensureLocalReady();
    await PushService.showLocal(message);
  }
}

/// Firebase Cloud Messaging + local notifications.
///
/// - Registers the device's FCM token with the backend (approvals push).
/// - Rings the bundled sound on every notification, in foreground AND background.
///
/// Safe to call before `flutterfire configure` has run — if Firebase isn't
/// configured yet it fails silently (in-app notifications still work).
class PushService {
  static bool _firebaseReady = false;
  static bool _localReady = false;

  /// Called once from main(): initialise Firebase, wire up the background
  /// handler, and create the notification channel that owns the custom sound.
  static Future<void> initEarly() async {
    await _ensureFirebase();
    if (_firebaseReady) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
    await ensureLocalReady();
  }

  static Future<void> _ensureFirebase() async {
    if (_firebaseReady) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseReady = true;
    } catch (_) {
      // Firebase not configured yet — run `flutterfire configure`.
    }
  }

  /// Sets up flutter_local_notifications and the high-importance Android channel
  /// that carries the custom sound. Idempotent.
  static Future<void> ensureLocalReady() async {
    if (_localReady) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _localNotifs.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    const channel = AndroidNotificationChannel(
      kNotifChannelId,
      kNotifChannelName,
      description: kNotifChannelDesc,
      importance: Importance.high,
      sound: _kSound,
      playSound: true,
    );
    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    _localReady = true;
  }

  /// Draws a heads-up notification (with the custom sound) for [message].
  /// Used for FOREGROUND messages on both platforms (FCM never auto-presents in
  /// the foreground), and Android background data-only messages.
  static Future<void> showLocal(RemoteMessage message) async {
    final n = message.notification;
    final title = n?.title ?? message.data['title'] ?? 'HR App';
    final body = n?.body ?? message.data['body'] ?? '';
    const androidDetails = AndroidNotificationDetails(
      kNotifChannelId,
      kNotifChannelName,
      channelDescription: kNotifChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      sound: _kSound,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: kIosSoundFile,
    );
    await _localNotifs.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }

  /// Called after login: request permission, start the foreground listener,
  /// and register the FCM token with the backend.
  static Future<void> setup() async {
    await _ensureFirebase();
    if (!_firebaseReady) return;
    try {
      await ensureLocalReady();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      // Let FCM NOT auto-present in the foreground on iOS — we draw our own local
      // notification instead so it rings the CUSTOM sound (the system default
      // presentation would only play the default sound). Prevents a double banner.
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      // Foreground (both platforms): FCM doesn't show anything itself, so we draw
      // a local notification with the bundled custom sound.
      FirebaseMessaging.onMessage.listen(showLocal);

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
