import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../state/configuration.dart';
import '../../ui/kit.dart';

/// Fiches de premiers secours : version embarquée dans l'application (hors ligne dès
/// l'installation), remplacée par la version du serveur dès qu'elle est disponible.
class PremiersSecoursScreen extends StatefulWidget {
  const PremiersSecoursScreen({super.key});
  @override
  State<PremiersSecoursScreen> createState() => _PremiersSecoursScreenState();
}

class _PremiersSecoursScreenState extends State<PremiersSecoursScreen> {
  List<Map<String, dynamic>> _fiches = [];
  String _source = 'intégrée';
  String _q = '';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final prefs = await SharedPreferences.getInstance();
    final cache = prefs.getString('fiches_secours');
    if (cache != null) {
      _fiches = List<Map<String, dynamic>>.from(jsonDecode(cache));
      _source = 'enregistrée';
    } else {
      final embarquee = jsonDecode(await rootBundle.loadString('assets/data/fiches_secours.json'));
      _fiches = List<Map<String, dynamic>>.from(embarquee['fiches']).map((f) => {...f, 'validee': false, 'date_mise_a_jour': embarquee['version']}).toList();
    }
    if (mounted) setState(() {});
    try {
      final r = await Api.instance.get<List>('/fiches-secours/');
      _fiches = List<Map<String, dynamic>>.from(r);
      _source = 'à jour';
      await prefs.setString('fiches_secours', jsonEncode(r));
      if (mounted) setState(() {});
    } catch (_) {/* hors ligne : la version locale reste affichée */}
  }

  String _n(String s) => s.toLowerCase().replaceAll(RegExp('[éèê]'), 'e').replaceAll(RegExp('[àâ]'), 'a').replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final filtrees = _fiches.where((f) => _q.isEmpty || _n('${f['titre']} ${f['resume']} ${f['categorie']}').contains(_n(_q))).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Premiers secours')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(onChanged: (v) => setState(() => _q = v), decoration: const InputDecoration(hintText: 'Brûlure, saignement…', prefixIcon: Icon(Icons.search))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Version $_source · disponible hors connexion', style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
        for (final f in filtrees) Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Carte(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FicheScreen(f))),
            child: Row(children: [
              const Icon(Icons.healing_rounded, color: AppColors.crimson),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f['titre'], style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(f['resume'], style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              ])),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _FicheScreen extends StatelessWidget {
  final Map<String, dynamic> f;
  const _FicheScreen(this.f);
  @override
  Widget build(BuildContext context) {
    final numeros = context.watch<Configuration>().numeros;
    final etapes = List<String>.from(f['etapes']);
    return Scaffold(
      appBar: AppBar(title: Text(f['titre'])),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(f['resume'], style: TextStyle(color: AppColors.textGrey, fontSize: 15)),
        if (f['validee'] != true) const Padding(padding: EdgeInsets.only(top: 12),
            child: Bandeau.alerte('Fiche rédigée d’après les recommandations citées, en attente de validation par un professionnel de santé.')),
        const SizedBox(height: 14),
        for (var i = 0; i < etapes.length; i++) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 14, backgroundColor: AppColors.vert800, child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
            const SizedBox(width: 12),
            Expanded(child: Text(etapes[i], style: const TextStyle(fontSize: 15.5, height: 1.4))),
          ]),
        ),
        for (final a in List<String>.from(f['a_eviter'] ?? const [])) Padding(padding: const EdgeInsets.only(bottom: 8), child: Bandeau.alerte(a)),
        if ((f['appeler_si'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Carte(couleur: const Color(0xFFFFE4E9), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Appelez les secours : ${f['appeler_si']}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.crimsonDeep)),
            const SizedBox(height: 8),
            NumerosUrgence(numeros),
          ])),
        ],
        const SizedBox(height: 12),
        Text('Sources : ${List<String>.from(f['sources']).join(' ; ')} · mise à jour ${f['date_mise_a_jour']}',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]),
    );
  }
}
