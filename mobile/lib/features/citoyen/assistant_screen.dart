import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';
import '../../core/audio.dart';
import '../../core/constants/app_colors.dart';
import '../../state/configuration.dart';
import '../../state/session.dart';
import '../../ui/kit.dart';

/// Assistant (Groq côté serveur, repli local sans IA), à la manière d'une messagerie IA : chaque ouverture
/// démarre une discussion vide, gardée en mémoire le temps de l'écran uniquement.
/// Audio : dictée en français ou en wolof (transcrite et traduite par le serveur, relue avant envoi)
/// et lecture des réponses à voix haute.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _ctrl = TextEditingController();
  final _defilement = ScrollController();
  final _focus = FocusNode();
  final List<Map<String, dynamic>> _messages = [];
  bool _envoi = false;
  bool _traduit = false;
  String? _erreurVocale;
  late final Dictee _dictee;
  final _lecteur = Lecteur();
  static const _suggestions = ['Comment signaler une inondation ?', 'Que faire en cas de brûlure ?', 'Comment suivre mon dossier ?',
      'Comment me préparer à l’hivernage ?'];

  @override
  void initState() {
    super.initState();
    _dictee = Dictee(surTexte: _surTexte, surErreur: (m) { if (mounted) setState(() => _erreurVocale = m); });
    _dictee.addListener(_rafraichir);
    _lecteur.addListener(_rafraichir);
    // Les anciennes versions gardaient l'historique sur l'appareil : on l'efface.
    SharedPreferences.getInstance().then((p) => p.remove('assistant_historique')).catchError((_) => false);
  }

  void _rafraichir() { if (mounted) setState(() {}); }

  /// Le texte reconnu (traduit en français s'il était en wolof) s'ajoute au champ : le citoyen le relit avant d'envoyer.
  void _surTexte(String reconnu, bool traduit) {
    if (!mounted) return;
    final actuel = _ctrl.text.trim();
    final texte = (actuel.isEmpty ? reconnu : '$actuel $reconnu');
    _ctrl.text = texte.length > 1000 ? texte.substring(0, 1000) : texte;
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    setState(() { _erreurVocale = null; _traduit = traduit; });
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

  void _nouvelleDiscussion() {
    _lecteur.arreter();
    _dictee.annuler();
    _ctrl.clear();
    setState(() { _messages.clear(); _traduit = false; _erreurVocale = null; });
  }

  Future<void> _envoyer([String? texte]) async {
    final m = (texte ?? _ctrl.text).trim();
    if (m.isEmpty || _envoi || _dictee.etat != EtatDictee.repos) return;
    _ctrl.clear();
    final historique = _messages.where((x) => x['erreur'] != true).toList();
    final contexte = historique.length > 6 ? historique.sublist(historique.length - 6) : historique;
    setState(() { _messages.add({'role': 'user', 'content': m}); _envoi = true; _traduit = false; });
    _descendre();
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
    _descendre();
  }

  void _descendre() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_defilement.hasClients) _defilement.animateTo(_defilement.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  String _prenom(BuildContext context) {
    try {
      return context.watch<Session>().utilisateur?.prenom ?? '';
    } catch (_) {
      return ''; // écran affiché sans session (tests)
    }
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
        Expanded(child: Semantics(liveRegion: true, child: Text('Je vous écoute… $s s / ${dureeMaxDictee.inSeconds} s\nfrançais ou wolof',
            style: const TextStyle(fontWeight: FontWeight.w600)))),
        TextButton(onPressed: _dictee.annuler, child: const Text('Annuler')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: _dictee.terminer, icon: const Icon(Icons.stop_rounded), label: const Text('Terminer')),
      ]),
    );
  }

  Widget _accueil(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 48, 20, 16), children: [
        const Icon(Icons.smart_toy_outlined, size: 44, color: AppColors.marine800),
        const SizedBox(height: 12),
        Text('${'Bonjour ${_prenom(context)}'.trim()}, comment puis-je vous aider ?', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Text('Conseils de prévention et aide à l’application. Ne remplace ni les secours ni un avis médical. '
            'Vous pouvez écrire ou parler en français ou en wolof.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, height: 1.4)),
        const SizedBox(height: 20),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
          for (final s in _suggestions) ActionChip(label: Text(s), onPressed: () => _envoyer(s)),
        ]),
      ]);

  Widget _discussion(BuildContext context) => ListView(controller: _defilement, padding: const EdgeInsets.all(16), children: [
        for (final (i, m) in _messages.indexed) Align(
          alignment: m['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (m['role'] == 'user' ? 0.8 : 0.92)),
            padding: m['role'] == 'user' || m['erreur'] == true ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10) : const EdgeInsets.symmetric(vertical: 4),
            decoration: m['role'] == 'user'
                ? BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border))
                : m['erreur'] == true ? BoxDecoration(color: Jetons.rougeClair, borderRadius: BorderRadius.circular(16)) : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (m['alerte'] != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Bandeau.erreur(m['alerte'],
                  action: TextButton(onPressed: () => context.push('/sos'), child: const Text('Ouvrir le SOS')))),
              Text(m['content'] ?? '', style: TextStyle(color: AppColors.textDark, height: 1.45)),
              if (m['source'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(
                  m['source'] == 'groq' ? 'Réponse générée par IA — indicative' : 'Mode secours (sans IA), d’après les fiches SenAlert',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
              if (m['role'] == 'assistant' && m['erreur'] != true) _boutonEcouter(i, m),
            ]),
          ),
        ),
        if (_envoi) Text('L’assistant rédige une réponse…', style: TextStyle(color: AppColors.textGrey)),
      ]);

  @override
  Widget build(BuildContext context) {
    final avecMicro = context.watch<Configuration>().assistantVocal;
    final transcription = _dictee.etat == EtatDictee.transcription;
    final occupe = _envoi || _dictee.etat != EtatDictee.repos;
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant'), actions: [
        if (_messages.isNotEmpty) IconButton(tooltip: 'Nouvelle discussion', icon: const Icon(Icons.add_comment_outlined), onPressed: _nouvelleDiscussion),
      ]),
      body: SafeArea(child: Column(children: [
        Expanded(child: _messages.isEmpty ? _accueil(context) : _discussion(context)),
        if (_erreurVocale != null) Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Bandeau.erreur(_erreurVocale!, action: TextButton(onPressed: () => setState(() => _erreurVocale = null), child: const Text('OK'))),
        ),
        if (_traduit) Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(children: [
            const Icon(Icons.translate_rounded, size: 16, color: AppColors.marine800),
            const SizedBox(width: 6),
            Expanded(child: Text('Message vocal traduit du wolof : relisez-le avant d’envoyer.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.info))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: _dictee.etat == EtatDictee.enregistrement ? _barreEnregistrement() : Row(children: [
            Expanded(child: TextField(controller: _ctrl, focusNode: _focus, maxLength: 1000, enabled: !transcription,
                textInputAction: TextInputAction.send, onSubmitted: (_) => _envoyer(),
                onChanged: (t) { if (t.isEmpty && _traduit) setState(() => _traduit = false); },
                decoration: InputDecoration(hintText: transcription ? 'Transcription de votre message vocal…' : 'Posez votre question…', counterText: ''))),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('N’indiquez pas d’informations personnelles. Pour une urgence, utilisez le SOS.', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ),
      ])),
    );
  }
}
