import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:senalert_mobile/core/services/api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint("Notification FCM reçue en arrière-plan: ${message.messageId}");
  } catch (e) {
    debugPrint("Erreur background handler FCM: $e");
  }
}

class PushService {
  static final PushService _instance = PushService._internal();
  factory PushService() => _instance;
  PushService._internal();

  FirebaseMessaging? _messaging;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Notification FCM reçue au premier plan!');
        if (message.notification != null) {
          debugPrint('Titre: ${message.notification?.title}');
          debugPrint('Corps: ${message.notification?.body}');
        }
      });
    } catch (e) {
      debugPrint('Initialisation Firebase Push impossible (mode secours/web): $e');
    }
  }

  Future<void> registerDeviceToken() async {
    try {
      if (_messaging == null) {
        await init();
      }
      NotificationSettings? settings = await _messaging?.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings?.authorizationStatus == AuthorizationStatus.authorized ||
          settings?.authorizationStatus == AuthorizationStatus.provisional) {
        String? token = await _messaging?.getToken();
        if (token != null && token.isNotEmpty) {
          await ApiService().dio.post(
            '/api/auth/device-token/',
            data: {'token': token},
          );
          debugPrint('Token FCM enregistré sur le serveur: $token');
        }
      }
    } catch (e) {
      debugPrint('Erreur enregistrement Token FCM: $e');
    }
  }
}
