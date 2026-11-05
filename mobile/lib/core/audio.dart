import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';

import 'api.dart';

/// Durée maximale d'un message vocal (≈ 1,9 Mo en WAV 16 kHz mono).
const dureeMaxDictee = Duration(seconds: 60);
const _frequence = 16000;

/// En-tête WAV (PCM 16 bits, mono) devant les échantillons bruts : format lu par Whisper sur toutes les plateformes.
Uint8List wavDepuisPcm(Uint8List pcm, {int frequence = _frequence}) {
  final entete = ByteData(44);
  void texte(int position, String s) {
    for (var i = 0; i < s.length; i++) {
      entete.setUint8(position + i, s.codeUnitAt(i));
    }
  }
  texte(0, 'RIFF');
  entete.setUint32(4, 36 + pcm.length, Endian.little);
  texte(8, 'WAVE');
  texte(12, 'fmt ');
  entete.setUint32(16, 16, Endian.little);
  entete.setUint16(20, 1, Endian.little); // PCM
  entete.setUint16(22, 1, Endian.little); // mono
  entete.setUint32(24, frequence, Endian.little);
  entete.setUint32(28, frequence * 2, Endian.little);
  entete.setUint16(32, 2, Endian.little);
  entete.setUint16(34, 16, Endian.little);
  texte(36, 'data');
  entete.setUint32(40, pcm.length, Endian.little);
  return (BytesBuilder(copy: false)..add(entete.buffer.asUint8List())..add(pcm)).toBytes();
}

/// Texte lu à voix haute : sans puces ni symboles que la synthèse prononcerait.
String texteAParler(String texte) => texte.replaceAll(RegExp(r'[•*#_>]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

enum EtatDictee { repos, enregistrement, transcription }

/// Dictée : enregistre la voix puis la fait transcrire par le serveur (Whisper).
/// L'audio reste en mémoire le temps de l'envoi : il n'est jamais écrit sur l'appareil ni conservé par le serveur.
class Dictee extends ChangeNotifier {
  Dictee({required this.surTexte, required this.surErreur});

  final void Function(String texte) surTexte;
  final void Function(String message) surErreur;

  final _micro = AudioRecorder();
  final _morceaux = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _flux;
  Timer? _minuteur;
  DateTime? _debut;
  bool _annule = false;
  bool _libere = false;

  EtatDictee etat = EtatDictee.repos;
  Duration duree = Duration.zero;

  void _changer(EtatDictee e) {
    etat = e;
    if (!_libere) notifyListeners();
  }

  Future<void> demarrer() async {
    if (etat != EtatDictee.repos) return;
    try {
      if (!await _micro.hasPermission()) {
        surErreur('Micro refusé. Autorisez le micro pour SenAlert dans les réglages, puis réessayez.');
        return;
      }
      if (!await _micro.isEncoderSupported(AudioEncoder.pcm16bits)) {
        surErreur('La dictée vocale n’est pas prise en charge sur cet appareil.');
        return;
      }
      _morceaux.clear();
      _annule = false;
      final flux = await _micro.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits, sampleRate: _frequence, numChannels: 1, echoCancel: true, noiseSuppress: true));
      _flux = flux.listen(_morceaux.add);
    } catch (_) {
      surErreur('Impossible d’utiliser le micro.');
      return;
    }
    _debut = DateTime.now();
    duree = Duration.zero;
    _changer(EtatDictee.enregistrement);
    _minuteur = Timer.periodic(const Duration(milliseconds: 250), (_) {
      duree = DateTime.now().difference(_debut!);
      if (!_libere) notifyListeners();
      if (duree >= dureeMaxDictee) terminer();
    });
  }

  Future<void> annuler() async {
    _annule = true;
    await terminer();
  }

  Future<void> terminer() async {
    if (etat != EtatDictee.enregistrement) return;
    _minuteur?.cancel();
    try {
      await _micro.stop();
    } catch (_) {/* micro déjà arrêté */}
    await _flux?.cancel();
    _flux = null;
    final pcm = _morceaux.takeBytes();
    if (_annule || pcm.length < _frequence * 2 ~/ 4) { // moins d'un quart de seconde : rien à transcrire
      _changer(EtatDictee.repos);
      return;
    }
    _changer(EtatDictee.transcription);
    try {
      final form = FormData.fromMap({'audio': MultipartFile.fromBytes(wavDepuisPcm(pcm), filename: 'message.wav')});
      final r = await Api.instance.post<Map<String, dynamic>>('/analyse/assistant/transcrire/', data: form);
      if (!_libere) surTexte('${r['texte']}');
    } on ApiException catch (e) {
      if (!_libere) surErreur(e.message);
    }
    _changer(EtatDictee.repos);
  }

  @override
  void dispose() {
    _libere = true;
    _annule = true;
    _minuteur?.cancel();
    _flux?.cancel();
    _micro.dispose().catchError((_) {}); // module natif absent (tests) ou déjà libéré
    super.dispose();
  }
}

/// Lecture à voix haute des réponses (synthèse vocale de l'appareil, en français). Un seul message à la fois.
class Lecteur extends ChangeNotifier {
  Lecteur() {
    _tts.setCompletionHandler(_fin);
    _tts.setCancelHandler(_fin);
    _tts.setErrorHandler((_) => _fin());
  }

  final _tts = FlutterTts();
  bool _pret = false;
  bool _libere = false;
  int? enCours;

  void _fin() {
    enCours = null;
    if (!_libere) notifyListeners();
  }

  Future<void> lire(int id, String texte) async {
    if (enCours == id) return arreter();
    try {
      await _tts.stop();
    } catch (_) {
      return; // synthèse vocale indisponible sur cet appareil
    }
    if (!_pret) {
      _pret = true;
      try {
        await _tts.setLanguage('fr-FR');
        await _tts.setSpeechRate(kIsWeb ? 1.0 : 0.5);
      } catch (_) {/* voix par défaut de l'appareil */}
    }
    enCours = id;
    notifyListeners();
    await _tts.speak(texteAParler(texte));
  }

  Future<void> arreter() async {
    try {
      await _tts.stop();
    } catch (_) {/* synthèse vocale indisponible */}
    _fin();
  }

  @override
  void dispose() {
    _libere = true;
    Future.sync(_tts.stop).catchError((_) {});
    super.dispose();
  }
}
