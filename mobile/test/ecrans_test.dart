import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:senalert_mobile/features/auth/auth_screens.dart';
import 'package:senalert_mobile/features/auth/bienvenue_screen.dart';
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
    await t.tap(find.text('Se connecter en tant que citoyen'));
    await t.pump();
    expect(find.text('Renseignez votre e-mail et votre mot de passe.'), findsOneWidget);
  });

  testWidgets('connexion Google signalée comme non configurée sans identifiant client', (t) async {
    await t.pumpWidget(envelopper(const ConnexionScreen()));
    expect(find.textContaining('Connexion Google non configurée'), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsNothing);
  });

  testWidgets('connexion : onglet Superviseur sans création de compte ni Google', (t) async {
    await t.pumpWidget(envelopper(const ConnexionScreen()));
    await t.tap(find.text('Superviseur'));
    await t.pump();
    expect(find.text('Se connecter en tant que superviseur'), findsOneWidget);
    expect(find.textContaining('Créer un compte'), findsNothing);
    expect(find.textContaining('Connexion Google'), findsNothing);
    expect(find.textContaining('administrateur du serveur'), findsOneWidget);
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
}
