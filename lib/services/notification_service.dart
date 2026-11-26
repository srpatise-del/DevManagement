import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    debugPrint('Handling background FCM message: ${message.messageId}');
  }
}

class NotificationService {
  static bool _initialized = false;
  static String? _cachedToken;
  static RemoteMessage? _pendingInitialMessage;
  static void Function(String newToken)? onTokenRefreshed;
  static void Function(RemoteMessage message)? onForegroundMessage;
  static void Function(RemoteMessage message)? onNotificationOpened;

  static RemoteMessage? consumeInitialMessage() {
    final msg = _pendingInitialMessage;
    _pendingInitialMessage = null;
    return msg;
  }

  static bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static String get currentPlatformName {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      default:
        return 'android';
    }
  }

  static String? get cachedToken => _cachedToken;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (!_isMobilePlatform) {
      // Desktop / Web without Firebase Web config uses Supabase Realtime for live notifications
      _initialized = true;
      return;
    }

    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (kDebugMode) {
        debugPrint('FCM Permission Status: ${settings.authorizationStatus}');
      }

      _cachedToken = await messaging.getToken();
      if (kDebugMode && _cachedToken != null) {
        debugPrint('FCM DEVICE TOKEN: $_cachedToken');
      }

      messaging.onTokenRefresh.listen((newToken) {
        _cachedToken = newToken;
        onTokenRefreshed?.call(newToken);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('Foreground FCM Message received: ${message.notification?.title}');
        }
        onForegroundMessage?.call(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('FCM Message Opened App: ${message.notification?.title}');
        }
        onNotificationOpened?.call(message);
      });

      _pendingInitialMessage = await messaging.getInitialMessage();

      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService Initialize Error: $e');
      }
    }
  }

  static Future<String?> getToken() async {
    if (!_isMobilePlatform) return _cachedToken;
    try {
      if (!_initialized) {
        await initialize();
      }
      _cachedToken ??= await FirebaseMessaging.instance.getToken();
      return _cachedToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService getToken Error: $e');
      }
      return _cachedToken;
    }
  }
}
