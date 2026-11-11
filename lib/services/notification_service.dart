import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('Handling background FCM message: ${message.messageId}');
  }
}

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      // Initialize Firebase App
      await Firebase.initializeApp();

      // Set Background Handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request Permission (iOS / Android 13+)
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Enable Foreground Heads-up Notification Presentation
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      if (kDebugMode) {
        print('FCM Permission Status: ${settings.authorizationStatus}');
      }

      // Get FCM Device Token
      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('========================================');
        print('FCM DEVICE TOKEN: $token');
        print('========================================');
      }

      // Listen for Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Foreground FCM Message received: ${message.notification?.title}');
        }
      });

      // Listen for Opened Messages (When user taps notification)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('FCM Message Opened App: ${message.notification?.title}');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('NotificationService Initialize Error: $e');
      }
    }
  }
}
