import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/api.dart';
import 'package:senalert_mobile/core/audio.dart';
import 'package:senalert_mobile/features/citoyen/assistant_screen.dart';
import 'package:senalert_mobile/state/configuration.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget assistant({required bool vocal}) => ChangeNotifierProvider(
      create: (_) => Configuration()..assistantVocal = vocal,
      child: const MaterialApp(home: AssistantScreen()),
    );

/// Faux serveur : l'assistant répond toujours la même chose.
class FauxServeur implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(jsonEncode({'reponse': 'Refroidissez la zone.', 'source': 'groq'}), 200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  @override
  void close({bool force = false}) {}
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
    Api.instance.dio.httpClientAdapter = FauxServeur();
  });

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
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(assistant(vocal: false));
    await t.tap(find.text('Que faire en cas de brûlure ?'));
    await t.pumpAndSettle();
    expect(find.text('Refroidissez la zone.'), findsOneWidget);
    expect(find.text('Écouter'), findsOneWidget);
  });

  testWidgets('assistant : chaque ouverture démarre une discussion vide (comme une messagerie IA)', (t) async {
    SharedPreferences.setMockInitialValues({'assistant_historique': '[{"role":"user","content":"ancienne question"}]'});
    await t.pumpWidget(assistant(vocal: false));
    await t.pumpAndSettle();
    expect(find.text('ancienne question'), findsNothing);
    expect(find.textContaining('comment puis-je vous aider'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('assistant_historique'), isNull);
  });

  testWidgets('assistant : « Nouvelle discussion » efface la conversation', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(assistant(vocal: false));
    await t.tap(find.text('Comment suivre mon dossier ?'));
    await t.pumpAndSettle();
    expect(find.text('Refroidissez la zone.'), findsOneWidget);
    await t.tap(find.byTooltip('Nouvelle discussion'));
    await t.pumpAndSettle();
    expect(find.text('Refroidissez la zone.'), findsNothing);
    expect(find.textContaining('comment puis-je vous aider'), findsOneWidget);
  });
}
