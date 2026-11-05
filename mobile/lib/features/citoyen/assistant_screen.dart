import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';
import '../../core/audio.dart';
import '../../core/constants/app_colors.dart';
import '../../state/configuration.dart';
import '../../ui/kit.dart';

/// Assistant (Groq côté serveur, repli local sans IA). Historique conservé sur l'appareil uniquement.
/// Audio : dictée de la question (transcrite par le serveur, relue avant envoi) et lecture des réponses à voix haute.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _ctrl = TextEditingController();
  final _defilement = ScrollController();
  final _focus = FocusNode();
  List<Map<String, dynamic>> _messages = [];
  bool _envoi = false;
  String? _erreurVocale;
  late final Dictee _dictee;
  final _lecteur = Lecteur();
  static const _suggestions = ['Comment signaler une inondation ?', 'Que faire en cas de brûlure ?', 'Comment suivre mon dossier ?'];

  @override
  void initState() {
    super.initState();
    _dictee = Dictee(surTexte: _surTexte, surErreur: (m) { if (mounted) setState(() => _erreurVocale = m); });
    _dictee.addListener(_rafraichir);
    _lecteur.addListener(_rafraichir);
    SharedPreferences.getInstance().then((p) {
      final h = p.getString('assistant_historique');
      if (h != null && mounted) setState(() => _messages = List<Map<String, dynamic>>.from(jsonDecode(h)));
    });
  }

  void _rafraichir() { if (mounted) setState(() {}); }

  /// Le texte reconnu s'ajoute au champ : le citoyen le relit (et le corrige) avant d'envoyer.
  void _surTexte(String reconnu) {
    if (!mounted) return;
    final actuel = _ctrl.text.trim();
    final texte = (actuel.isEmpty ? reconnu : '$actuel $reconnu');
    _ctrl.text = texte.length > 1000 ? texte.substring(0, 1000) : texte;
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    setState(() => _erreurVocale = null);
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _dictee.dispose();
    _lecteur.dispose();
    _ctrl.dispose();
    _defilement.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _sauver() async =>
      (await SharedPreferences.getInstance()).setString('assistant_historique', jsonEncode(_messages.length > 30 ? _messages.sublist(_messages.length - 30) : _messages));

  Future<void> _envoyer([String? texte]) async {
    final m = (texte ?? _ctrl.text).trim();
    if (m.isEmpty || _envoi || _dictee.etat != EtatDictee.repos) return;
    _ctrl.clear();
    final historique = _messages.where((x) => x['erreur'] != true).toList();
    final contexte = historique.length > 6 ? historique.sublist(historique.length - 6) : historique;
    setState(() { _messages.add({'role': 'user', 'content': m}); _envoi = true; });
    try {
      final r = await Api.instance.post<Map<String, dynamic>>('/analyse/assistant/', data: {
        'message': m, 'historique': contexte.map((x) => {'role': x['role'], 'content': x['content']}).toList(),
      });
      _messages.add({'role': 'assistant', 'content': r['reponse'], 'source': r['source'], 'alerte': r['alerte_urgence']});
    } on ApiException catch (e) {
      _messages.add({'role': 'assistant', 'content': e.message, 'erreur': true});
    }
    if (!mounted) return;
    setState(() => _envoi = false);
    _sauver();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_defilement.hasClients) _defilement.animateTo(_defilement.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Widget _boutonEcouter(int i, Map<String, dynamic> m) {
    final actif = _lecteur.enCours == i;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        onPressed: () => _lecteur.lire(i, [m['alerte'], m['content']].whereType<String>().join('. ')),
        icon: Icon(actif ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 16),
        label: Text(actif ? 'Arrêter la lecture' : 'Écouter'),
      ),
    );
  }

  Widget _barreEnregistrement() {
    final s = _dictee.duree.inSeconds;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Jetons.rougeClair, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.fiber_manual_record_rounded, color: Colors.red, size: 14),
        const SizedBox(width: 8),
        Expanded(child: Semantics(liveRegion: true, child: Text('Je vous écoute… $s s / ${dureeMaxDictee.inSeconds} s',
            style: const TextStyle(fontWeight: FontWeight.w600)))),
        TextButton(onPressed: _dictee.annuler, child: const Text('Annuler')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: _dictee.terminer, icon: const Icon(Icons.stop_rounded), label: const Text('Terminer')),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avecMicro = context.watch<Configuration>().assistantVocal;
    final transcription = _dictee.etat == EtatDictee.transcription;
    final occupe = _envoi || _dictee.etat != EtatDictee.repos;
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant'), actions: [
        if (_messages.isNotEmpty) IconButton(tooltip: 'Effacer l’historique', icon: const Icon(Icons.delete_outline),
            onPressed: () { _lecteur.arreter(); setState(() => _messages = []); _sauver(); }),
      ]),
      body: SafeArea(child: Column(children: [
        Expanded(child: ListView(controller: _defilement, padding: const EdgeInsets.all(16), children: [
          const Bandeau('Conseils de prévention et aide à l’application. Ne remplace ni les secours ni un avis médical. N’indiquez pas d’informations personnelles.'),
          const SizedBox(height: 12),
          if (_messages.isEmpty) Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in _suggestions) ActionChip(label: Text(s), onPressed: () => _envoyer(s)),
          ]),
          for (final (i, m) in _messages.indexed) Align(
            alignment: m['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: m['role'] == 'user' ? AppColors.marine800 : m['erreur'] == true ? Jetons.rougeClair : AppColors.white,
                borderRadius: BorderRadius.circular(16), border: m['role'] == 'user' ? null : Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (m['alerte'] != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Bandeau.erreur(m['alerte'],
                    action: TextButton(onPressed: () => context.push('/sos'), child: const Text('Ouvrir le SOS')))),
                Text(m['content'] ?? '', style: TextStyle(color: m['role'] == 'user' ? Colors.white : AppColors.textDark, height: 1.4)),
                if (m['source'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(
                    m['source'] == 'groq' ? 'Réponse générée par IA — indicative' : 'Mode secours (sans IA), d’après les fiches SenAlert',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
                if (m['role'] == 'assistant' && m['erreur'] != true) _boutonEcouter(i, m),
              ]),
            ),
          ),
          if (_envoi) Text('L’assistant rédige une réponse…', style: TextStyle(color: AppColors.textGrey)),
        ])),
        if (_erreurVocale != null) Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Bandeau.erreur(_erreurVocale!, action: TextButton(onPressed: () => setState(() => _erreurVocale = null), child: const Text('OK'))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: _dictee.etat == EtatDictee.enregistrement ? _barreEnregistrement() : Row(children: [
            Expanded(child: TextField(controller: _ctrl, focusNode: _focus, maxLength: 1000, enabled: !transcription,
                textInputAction: TextInputAction.send, onSubmitted: (_) => _envoyer(),
                decoration: InputDecoration(hintText: transcription ? 'Transcription de votre message vocal…' : 'Votre question…', counterText: ''))),
            if (avecMicro) ...[
              const SizedBox(width: 8),
              transcription
                  ? const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2.5)))
                  : IconButton.outlined(tooltip: 'Dicter ma question', icon: const Icon(Icons.mic_rounded),
                      onPressed: occupe ? null : () { setState(() => _erreurVocale = null); _lecteur.arreter(); _dictee.demarrer(); }),
            ],
            const SizedBox(width: 8),
            IconButton.filled(tooltip: 'Envoyer', onPressed: occupe ? null : _envoyer, icon: const Icon(Icons.send_rounded)),
          ]),
        ),
      ])),
    );
  }
}
