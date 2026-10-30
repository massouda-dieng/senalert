import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';

@pragma('vm:entry-point')
Future<void> _arrierePlan(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

/// Notifications push (FCM). Si Firebase n'est pas configuré pour la plateforme,
/// l'application fonctionne normalement : les notifications restent consultables
/// dans l'écran « Notifications » (historique serveur).
class Push {
  Push._();
  static final Push instance = Push._();

  bool _pret = false;
  String? _jeton;
  final messages = ValueNotifier<RemoteMessage?>(null);

  bool get disponible => _pret;

  Future<void> initialiser() async {
    if (kIsWeb) return; // le web utilise l'historique et l'actualisation périodique
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_arrierePlan);
      FirebaseMessaging.onMessage.listen((m) => messages.value = m);
      _pret = true;
    } catch (e) {
      debugPrint('Push indisponible (Firebase non configuré) : ${e.runtimeType}');
    }
  }

  Future<void> enregistrerAppareil() async {
    if (!_pret) return;
    try {
      final reglages = await FirebaseMessaging.instance.requestPermission();
      if (reglages.authorizationStatus == AuthorizationStatus.denied) return;
      _jeton = await FirebaseMessaging.instance.getToken();
      if (_jeton == null) return;
      await Api.instance.post('/auth/appareils/', data: {
        'token': _jeton,
        'plateforme': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
    } catch (e) {
      debugPrint('Enregistrement de l’appareil impossible : ${e.runtimeType}');
    }
  }

  Future<void> oublierAppareil() async {
    if (!_pret || _jeton == null) return;
    try {
      await Api.instance.delete('/auth/appareils/', data: {'token': _jeton});
    } catch (_) {}
  }
}
