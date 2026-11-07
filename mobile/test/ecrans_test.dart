import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:senalert_mobile/features/auth/auth_screens.dart';
import 'package:senalert_mobile/features/auth/bienvenue_screen.dart';
import 'package:senalert_mobile/features/citoyen/report_screen.dart';
import 'package:senalert_mobile/core/models.dart';
import 'package:senalert_mobile/state/configuration.dart';
import 'package:senalert_mobile/state/session.dart';
import 'package:senalert_mobile/ui/kit.dart';

Widget envelopper(Widget enfant) => MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => Session()), ChangeNotifierProvider(create: (_) => Configuration())],
      child: MaterialApp(home: enfant),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('connexion : champs vides refusés sans appel réseau', (t) async {
    await t.pumpWidget(envelopper(const ConnexionScreen()));
    await t.tap(find.text('Se connecter'));
    await t.pump();
    expect(find.text('Renseignez votre identifiant et votre mot de passe.'), findsOneWidget);
  });

  testWidgets('connexion Google signalée comme non configurée sans identifiant client', (t) async {
    await t.pumpWidget(envelopper(const ConnexionScreen()));
    expect(find.textContaining('Connexion Google non configurée'), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsNothing);
  });

  testWidgets('connexion unique : identifiant et mot de passe, sans choix de profil', (t) async {
    await t.pumpWidget(envelopper(const ConnexionScreen()));
    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.text('E-mail ou identifiant'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.textContaining('superviseur national'), findsNothing);
    expect(find.textContaining('remis par votre structure'), findsOneWidget);
  });

  testWidgets('création de compte : choix Citoyen, Agent, Superviseur', (t) async {
    await t.pumpWidget(envelopper(const InscriptionScreen()));
    for (final libelle in ['Citoyen', 'Agent', 'Superviseur']) {
      expect(find.text(libelle), findsOneWidget);
    }
  });

  testWidgets('accueil : présentation en pages, « Passer » mène aux deux actions et aux premiers secours', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(envelopper(const BienvenueScreen()));
    await t.pumpAndSettle();
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Une urgence ? Un seul geste'), findsOneWidget);
    await t.tap(find.text('Passer'));
    await t.pumpAndSettle();
    expect(find.text('Créer mon compte'), findsOneWidget);
    expect(find.text('J’ai déjà un compte'), findsOneWidget);
    expect(find.text('Premiers secours, sans compte'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getBool('presentation_vue'), isTrue);
  });

  testWidgets('accueil : présentation déjà vue, ouverture directe sur les actions', (t) async {
    SharedPreferences.setMockInitialValues({'presentation_vue': true});
    await t.pumpWidget(envelopper(const BienvenueScreen()));
    await t.pumpAndSettle();
    expect(find.text('Créer mon compte'), findsOneWidget);
  });

  testWidgets('badge de statut lisible', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: BadgeStatut('en_cours'))));
    expect(find.text('En cours'), findsOneWidget);
  });

  testWidgets('signalement : type, détails puis lieu ; sans localisation, recherche et carte restent possibles', (t) async {
    SharedPreferences.setMockInitialValues({});
    // Localisation refusée par l'utilisateur (canaux du module geolocator, générique et iOS/macOS).
    for (final canal in ['flutter.baseflow.com/geolocator', 'flutter.baseflow.com/geolocator_apple']) {
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(MethodChannel(canal), (appel) async => switch (appel.method) {
            'isLocationServiceEnabled' => true,
            'checkPermission' || 'requestPermission' => 0, // LocationPermission.denied
            _ => null,
          });
    }
    final config = Configuration()
      ..categories = [Categorie.depuis({'code': 'incendie', 'libelle': 'Incendie', 'couleur': '#DC2626', 'service_defaut_nom': 'Sapeurs-pompiers'})];
    await t.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => Session()), ChangeNotifierProvider.value(value: config)],
      child: const MaterialApp(home: SignalerScreen()),
    ));
    await t.pump();
    await t.tap(find.text('Incendie'));
    await t.pump();
    expect(find.text('Décrivez la situation'), findsOneWidget);
    expect(find.text('Ajouter'), findsOneWidget, reason: 'photo facultative avec aperçu');
    expect(find.textContaining('Date'), findsNothing, reason: 'la date et l’heure ne sont jamais demandées');
    await t.tap(find.text('Continuer'));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Où se passe l’incident ?'), findsOneWidget);
    expect(find.textContaining('Rechercher une adresse'), findsOneWidget);
    expect(find.text('Utiliser ma position actuelle'), findsOneWidget);
    // Pas de GPS dans le test (comme une permission refusée) : message clair et repli proposé.
    expect(find.textContaining('Autorisation de localisation refusée'), findsOneWidget);
    expect(find.textContaining('Recherchez l’adresse ou déplacez la carte'), findsOneWidget);
    expect(find.text('Région'), findsNothing, reason: 'la région est déduite de la position');
    final confirmer = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirmer ce lieu'));
    expect(confirmer.onPressed, isNull, reason: 'pas d’envoi sans lieu');
  });
}
