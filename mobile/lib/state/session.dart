import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/models.dart';
import '../core/push.dart';

/// Session de l'utilisateur. Le rôle vient TOUJOURS du serveur (profil).
class Session extends ChangeNotifier {
  Session() {
    _abonnement = Api.instance.sessionExpiree.listen((_) {
      utilisateur = null;
      expiree = true;
      notifyListeners();
    });
  }
  late final StreamSubscription _abonnement;

  Utilisateur? utilisateur;
  bool initialisee = false;
  bool expiree = false;

  bool get connecte => utilisateur != null;

  Future<void> restaurer() async {
    if (await Api.instance.aUneSession()) {
      try {
        utilisateur = Utilisateur.depuis(await Api.instance.get('/auth/profil/'));
      } on ApiException catch (e) {
        if (!e.estReseau) await Api.instance.effacerJetons();
        // Hors connexion : on ne fabrique pas de session, l'utilisateur se reconnectera.
      }
    }
    initialisee = true;
    notifyListeners();
    if (connecte) Push.instance.enregistrerAppareil();
  }

  Future<void> _ouvrir(Map<String, dynamic> r) async {
    await Api.instance.enregistrerJetons(r['access'], r['refresh']);
    utilisateur = Utilisateur.depuis(r['utilisateur']);
    expiree = false;
    notifyListeners();
    Push.instance.enregistrerAppareil();
  }

  Future<void> connexion(String identifiant, String motDePasse) async => _ouvrir(await Api.instance
      .post('/auth/connexion/', data: {'username': identifiant.trim(), 'password': motDePasse}, auth: false));

  Future<void> inscription(Map<String, dynamic> donnees) async =>
      _ouvrir(await Api.instance.post('/auth/inscription/', data: donnees, auth: false));

  static bool get googleConfigure => AppConfig.googleServerClientId.isNotEmpty;

  /// Connexion Google : l'ID token est envoyé au backend qui le vérifie (signature, audience, expiration).
  /// Retourne false si l'utilisateur annule.
  Future<bool> connexionGoogle() async {
    if (!googleConfigure) {
      throw const ApiException(0, 'La connexion Google n’est pas configurée dans cette version de l’application.');
    }
    final google = GoogleSignIn(
      scopes: const ['email'],
      serverClientId: AppConfig.googleServerClientId,
      clientId: AppConfig.googleIosClientId.isEmpty ? null : AppConfig.googleIosClientId,
    );
    final GoogleSignInAccount? compte;
    try {
      await google.signOut();
      compte = await google.signIn();
    } catch (e) {
      throw ApiException(0, 'Connexion Google impossible : ${e.toString().split(':').first}.');
    }
    if (compte == null) return false;
    final jeton = (await compte.authentication).idToken;
    if (jeton == null) throw const ApiException(0, 'Google n’a pas fourni de jeton d’identité.');
    await _ouvrir(await Api.instance.post('/auth/google/', data: {'id_token': jeton}, auth: false));
    return true;
  }

  Future<void> rechargerProfil() async {
    utilisateur = Utilisateur.depuis(await Api.instance.get('/auth/profil/'));
    notifyListeners();
  }

  void remplacerProfil(Map<String, dynamic> j) {
    utilisateur = Utilisateur.depuis(j);
    notifyListeners();
  }

  Future<void> ouvrirDepuisReponse(Map<String, dynamic> r) => _ouvrir(r);

  Future<void> deconnexion({bool partout = false}) async {
    try {
      await Push.instance.oublierAppareil();
      final refresh = await Api.instance.refreshActuel();
      await Api.instance.post('/auth/deconnexion/', data: partout ? {'tout': true} : {'refresh': refresh});
    } catch (_) {/* la session locale est fermée quoi qu'il arrive */}
    await Api.instance.effacerJetons();
    utilisateur = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _abonnement.cancel();
    super.dispose();
  }
}
