import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/audio.dart';
import 'package:senalert_mobile/features/citoyen/assistant_screen.dart';
import 'package:senalert_mobile/state/configuration.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget assistant({required bool vocal}) => ChangeNotifierProvider(
      create: (_) => Configuration()..assistantVocal = vocal,
      child: const MaterialApp(home: AssistantScreen()),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('WAV : en-tête PCM 16 bits mono 16 kHz devant les échantillons', () {
    final wav = wavDepuisPcm(Uint8List.fromList(List.filled(320, 7)));
    final b = ByteData.sublistView(wav);
    expect(wav.length, 44 + 320);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    expect(b.getUint32(4, Endian.little), 36 + 320);
    expect(b.getUint16(22, Endian.little), 1);
    expect(b.getUint32(24, Endian.little), 16000);
    expect(b.getUint16(34, Endian.little), 16);
    expect(b.getUint32(40, Endian.little), 320);
    expect(wav.last, 7);
  });

  test('texte lu sans puces ni symboles', () {
    expect(texteAParler('• Refroidissez **la zone**\n# Titre'), 'Refroidissez la zone Titre');
  });

  testWidgets('assistant : micro affiché quand le serveur propose la dictée', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(assistant(vocal: true));
    expect(find.byTooltip('Dicter ma question'), findsOneWidget);
  });

  testWidgets('assistant : micro masqué sans dictée sur le serveur', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(assistant(vocal: false));
    expect(find.byTooltip('Dicter ma question'), findsNothing);
    expect(find.byTooltip('Envoyer'), findsOneWidget);
  });

  testWidgets('assistant : bouton « Écouter » sur les réponses, pas sur les questions', (t) async {
    SharedPreferences.setMockInitialValues({'assistant_historique':
        '[{"role":"user","content":"brûlure ?"},{"role":"assistant","content":"Refroidissez la zone.","source":"groq"}]'});
    await t.pumpWidget(assistant(vocal: false));
    await t.pumpAndSettle();
    expect(find.text('Écouter'), findsOneWidget);
  });
}
