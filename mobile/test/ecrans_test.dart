import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/features/auth/auth_screens.dart';
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

  testWidgets('badge de statut lisible', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: BadgeStatut('en_cours'))));
    expect(find.text('En cours'), findsOneWidget);
  });
}
