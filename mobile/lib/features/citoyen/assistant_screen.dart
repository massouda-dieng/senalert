import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../ui/kit.dart';

/// Assistant (Groq côté serveur, repli local sans IA). Historique conservé sur l'appareil uniquement.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _ctrl = TextEditingController();
  final _defilement = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _envoi = false;
  static const _suggestions = ['Comment signaler une inondation ?', 'Que faire en cas de brûlure ?', 'Comment suivre mon dossier ?'];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final h = p.getString('assistant_historique');
      if (h != null && mounted) setState(() => _messages = List<Map<String, dynamic>>.from(jsonDecode(h)));
    });
  }

  Future<void> _sauver() async =>
      (await SharedPreferences.getInstance()).setString('assistant_historique', jsonEncode(_messages.length > 30 ? _messages.sublist(_messages.length - 30) : _messages));

  Future<void> _envoyer([String? texte]) async {
    final m = (texte ?? _ctrl.text).trim();
    if (m.isEmpty || _envoi) return;
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Assistant'), actions: [
          if (_messages.isNotEmpty) IconButton(tooltip: 'Effacer l’historique', icon: const Icon(Icons.delete_outline),
              onPressed: () { setState(() => _messages = []); _sauver(); }),
        ]),
        body: SafeArea(child: Column(children: [
          Expanded(child: ListView(controller: _defilement, padding: const EdgeInsets.all(16), children: [
            const Bandeau('Conseils de prévention et aide à l’application. Ne remplace ni les secours ni un avis médical. N’indiquez pas d’informations personnelles.'),
            const SizedBox(height: 12),
            if (_messages.isEmpty) Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in _suggestions) ActionChip(label: Text(s), onPressed: () => _envoyer(s)),
            ]),
            for (final m in _messages) Align(
              alignment: m['role'] == 'user' ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: m['role'] == 'user' ? AppColors.vert800 : m['erreur'] == true ? const Color(0xFFFEE2E2) : AppColors.white,
                  borderRadius: BorderRadius.circular(16), border: m['role'] == 'user' ? null : Border.all(color: AppColors.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (m['alerte'] != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Bandeau.erreur(m['alerte'],
                      action: TextButton(onPressed: () => context.push('/sos'), child: const Text('Ouvrir le SOS')))),
                  Text(m['content'] ?? '', style: TextStyle(color: m['role'] == 'user' ? Colors.white : AppColors.textDark, height: 1.4)),
                  if (m['source'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(
                      m['source'] == 'groq' ? 'Réponse générée par IA — indicative' : 'Mode secours (sans IA), d’après les fiches SenAlert',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
                ]),
              ),
            ),
            if (_envoi) const Text('L’assistant rédige une réponse…', style: TextStyle(color: AppColors.textGrey)),
          ])),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(children: [
              Expanded(child: TextField(controller: _ctrl, maxLength: 1000, textInputAction: TextInputAction.send, onSubmitted: (_) => _envoyer(),
                  decoration: const InputDecoration(hintText: 'Votre question…', counterText: ''))),
              const SizedBox(width: 8),
              IconButton.filled(tooltip: 'Envoyer', onPressed: _envoi ? null : _envoyer, icon: const Icon(Icons.send_rounded)),
            ]),
          ),
        ])),
      );
}
