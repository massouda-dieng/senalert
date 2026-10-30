import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../state/configuration.dart';
import '../../state/session.dart';
import '../../ui/alertes_zone.dart';
import '../../ui/kit.dart';
import '../../ui/photo.dart';

class AccueilAgent extends StatefulWidget {
  const AccueilAgent({super.key});
  @override
  State<AccueilAgent> createState() => _AccueilAgentState();
}

class _AccueilAgentState extends State<AccueilAgent> {
  List<Dossier> _miens = [];
  List<Dossier> _nouveaux = [];
  Map<String, dynamic>? _activite;
  ApiException? _erreur;
  bool _charge = false;
  DateTime? _synchro;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<List<Dossier>> _liste(String chemin, Map<String, dynamic> p, bool sos) async =>
      ((await Api.instance.get<Map<String, dynamic>>(chemin, params: p))['results'] as List).map((j) => Dossier.depuis(j, estSos: sos)).toList();

  Future<void> _charger() async {
    try {
      final r = await Future.wait([
        _liste('/alertes/sos/', {'affecte_a_moi': true, 'actifs': true}, true),
        _liste('/incidents/', {'affecte_a_moi': true, 'actifs': true}, false),
        _liste('/alertes/sos/', {'statut': 'nouveau'}, true),
        _liste('/incidents/', {'statut': 'nouveau'}, false),
      ]);
      final a = await Api.instance.get<Map<String, dynamic>>('/tableau-de-bord/activite-agent/');
      setState(() {
        _miens = [...r[0], ...r[1]];
        _nouveaux = [...r[2], ...r[3]];
        _activite = a;
        _erreur = null;
        _charge = true;
        _synchro = DateTime.now();
      });
    } on ApiException catch (e) {
      setState(() { _erreur = e; _charge = true; });
    }
  }

  int _somme(String k) => ((_activite?['incidents']?[k] ?? 0) as int) + ((_activite?['sos']?[k] ?? 0) as int);

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Session>().utilisateur!;
    final config = context.watch<Configuration>();
    final zones = u.zones.map((z) => config.region(z)?.libelle ?? z).join(', ');
    Widget kpi(String l, String v, IconData i, Color c) => Expanded(child: Carte(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, color: c), const SizedBox(height: 6), Text(v, style: titre(22)), Text(l, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ])));
    Widget section(String t, List<Dossier> l, String vide) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 20, bottom: 8), child: Text(t, style: titre(17))),
          if (l.isEmpty) Text(vide, style: const TextStyle(color: AppColors.textGrey)),
          for (final d in l) Padding(padding: const EdgeInsets.only(bottom: 10),
              child: TuileDossier(d, onTap: () => context.push('/dossier/${d.estSos ? 'sos' : 'incident'}/${d.id}').then((_) => _charger()))),
        ]);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _charger,
        child: !_charge
            ? const Chargement()
            : ListView(padding: EdgeInsets.zero, children: [
                SizedBox(
                  height: 170 + MediaQuery.of(context).padding.top,
                  child: PhotoIllustration('pompiers-bnsp', credit: false, superposition: DecoratedBox(
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xF2003A1B), Color(0x99006E33)])),
                    child: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                        const Text('ESPACE AGENT', style: TextStyle(color: AppColors.jaune, fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 12)),
                        Text('Bonjour ${u.prenom}'.trim(), style: titre(26, couleur: Colors.white)),
                        Text('${u.serviceNom ?? 'Service non défini'} · ${zones.isEmpty ? 'aucune zone' : zones}', style: const TextStyle(color: Colors.white70)),
                      ]))),
                  )),
                ),
                BandeauAlertesZone(region: u.zones.isEmpty ? null : u.zones.first),
                Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (u.serviceNom == null || u.zones.isEmpty) const Padding(padding: EdgeInsets.only(top: 10),
                    child: Bandeau.alerte('Compte non rattaché à un service ou à une zone : vous ne verrez que les dossiers qui vous sont affectés.')),
                if (_erreur != null) Padding(padding: const EdgeInsets.only(top: 10), child: Bandeau.erreur(_erreur!.message)),
                const SizedBox(height: 14),
                Row(children: [
                  kpi('Nouvelles alertes', '${_nouveaux.length}', Icons.notification_important_rounded, AppColors.crimson),
                  const SizedBox(width: 10),
                  kpi('En attente', '${_somme('en_attente')}', Icons.hourglass_top_rounded, AppColors.warning),
                  const SizedBox(width: 10),
                  kpi('Résolues 7 j', '${_activite?['resolus_7j'] ?? 0}', Icons.check_circle_rounded, AppColors.success),
                ]),
                section('Mes interventions en cours', _miens, 'Aucune intervention active.'),
                section('Nouvelles alertes de ma zone', _nouveaux, 'Aucune nouvelle alerte dans vos zones.'),
                if (_synchro != null) Padding(padding: const EdgeInsets.only(top: 12),
                    child: Text('Actualisé ${ilYa(_synchro)} · tirez pour rafraîchir', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
                ])),
              ]),
      ),
    );
  }
}
