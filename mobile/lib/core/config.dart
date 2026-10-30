import 'package:flutter/foundation.dart';

/// Configuration de compilation (aucun secret ici : uniquement des URL et
/// identifiants publics, passés par --dart-define).
class AppConfig {
  /// Adresse de l'API. Par défaut : émulateur Android → 10.0.2.2, sinon localhost.
  /// Sur un téléphone réel : --dart-define=API_BASE_URL=http://<IP-du-Mac>:8000/api
  static String get apiBaseUrl {
    const defini = String.fromEnvironment('API_BASE_URL');
    if (defini.isNotEmpty) return defini;
    // Servie par Django sous /mobile/ (simulateur) : l'API est sur la même origine.
    if (kIsWeb && Uri.base.path.startsWith('/mobile/')) return '${Uri.base.origin}/api';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000/api';
    return 'http://127.0.0.1:8000/api';
  }

  /// Identifiant client OAuth « Web » utilisé comme audience du jeton Google
  /// (serverClientId). Public, non secret. Vide = connexion Google désactivée.
  static const googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Identifiant client iOS (requis par google_sign_in sur iOS).
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
}
