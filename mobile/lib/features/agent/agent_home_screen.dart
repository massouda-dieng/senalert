import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../state/session.dart';
import '../../ui/alertes_zone.dart';
import '../../ui/cloche.dart';
import '../../ui/kit.dart';
import '../../ui/photo.dart';

class AccueilAgent extends StatefulWidget {
  const AccueilAgent({super.key});
  @override
  State<AccueilAgent> createState() => _AccueilAgentState();
}

class _AccueilAgentState extends State<AccueilAgent> {
  List<Dossier> _miens = [];
  Map<String, dynamic>? _activite;
  bool _bascule = false;
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

  /// L'agent se déclare disponible ou non : seuls les agents disponibles sont proposés aux citoyens.
  Future<void> _basculerDisponibilite(bool disponible) async {
    setState(() => _bascule = true);
    try {
      final j = await Api.instance.post<Map<String, dynamic>>('/auth/disponibilite/', data: {'disponible': disponible});
      if (!mounted) return;
      context.read<Session>().remplacerProfil(j);
      afficherMessage(context, disponible ? 'Vous êtes disponible.' : 'Vous êtes indisponible : les citoyens ne peuvent plus vous choisir.');
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _bascule = false);
    }
  }

  Future<void> _charger() async {
    try {
      final r = await Future.wait([
        _liste('/alertes/sos/', {'affecte_a_moi': true, 'actifs': true}, true),
        _liste('/incidents/', {'affecte_a_moi': true, 'actifs': true}, false),
      ]);
      final a = await Api.instance.get<Map<String, dynamic>>('/tableau-de-bord/activite-agent/');
      setState(() {
        // Les missions les plus urgentes d'abord
        _miens = [...r[0], ...r[1]]..sort((a, b) => rangGravite(a.gravite).compareTo(rangGravite(b.gravite)));
        _activite = a;
        _erreur = null;
        _charge = true;
        _synchro = DateTime.now();
      });
    } on ApiException catch (e) {
      setState(() { _erreur = e; _charge = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Session>().utilisateur!;
    Widget kpi(String l, String v, IconData i, Color c, {VoidCallback? onTap}) => Expanded(child: Carte(onTap: onTap, padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(i, color: c), const SizedBox(height: 6), Text(v, style: titre(22)),
          Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ])));
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _charger,
        child: !_charge
            ? const Chargement()
            : ListView(padding: EdgeInsets.zero, children: [
                SizedBox(
                  height: 170 + MediaQuery.of(context).padding.top,
                  child: PhotoIllustration('pompiers-bnsp', credit: false, superposition: DecoratedBox(
                    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Jetons.voileFort, Jetons.voileLeger])),
                    child: SafeArea(child: Stack(children: [
                      const Positioned(top: 4, right: 4, child: ClocheNotifications()),
                      Positioned.fill(child: Padding(padding: const EdgeInsets.all(20), child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                        const Text('ESPACE AGENT', style: TextStyle(color: AppColors.marine100, fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 12)),
                        Text('Bonjour ${u.prenom}'.trim(), style: titre(26, couleur: Colors.white)),
                        Text([if (u.fonction.isNotEmpty) u.fonction, u.structureNom ?? 'Aucune structure'].join(' · '),
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                      ]))),
                    ])),
                  )),
                ),
                BandeauAlertesZone(region: u.zones.isEmpty ? null : u.zones.first),
                Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (u.structureId == null) const Padding(padding: EdgeInsets.only(top: 10),
                    child: Bandeau.alerte('Compte non rattaché à une structure : aucun citoyen ne peut vous choisir. Contactez votre superviseur.')),
                Padding(padding: const EdgeInsets.only(top: 10), child: Carte(padding: EdgeInsets.zero, child: SwitchListTile(
                  value: u.disponible,
                  onChanged: _bascule ? null : _basculerDisponibilite,
                  secondary: Icon(Icons.power_settings_new_rounded, color: u.disponible ? AppColors.success : AppColors.textMuted),
                  title: Text(u.disponible ? 'Disponible' : 'Indisponible', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Les citoyens ne peuvent vous choisir que lorsque vous êtes disponible.'),
                ))),
                if (_erreur != null) Padding(padding: const EdgeInsets.only(top: 10), child: Bandeau.erreur(_erreur!.message)),
                const SizedBox(height: 14),
                Row(children: [
                  kpi('À accepter', '${_miens.where((d) => d.statut == 'affecte').length}', Icons.hourglass_top_rounded, AppColors.warning, onTap: () => context.go('/interventions')),
                  const SizedBox(width: 10),
                  kpi('En cours', '${_miens.where((d) => d.statut == 'accepte' || d.statut == 'en_cours').length}', Icons.assignment_outlined, AppColors.marine600),
                  const SizedBox(width: 10),
                  kpi('Finies 7 j', '${_activite?['resolus_7j'] ?? 0}', Icons.check_circle_rounded, AppColors.success),
                ]),
                Padding(padding: const EdgeInsets.only(top: 20, bottom: 8), child: Row(children: [
                  Expanded(child: Text('Mes interventions en cours', style: titre(17))),
                  TextButton(onPressed: () => context.go('/interventions'), child: const Text('Tout voir')),
                ])),
                if (_miens.isEmpty) Text('Aucune intervention active.', style: TextStyle(color: AppColors.textGrey)),
                for (final d in _miens) Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: TuileDossier(d, onTap: () => context.push('/dossier/${d.estSos ? 'sos' : 'incident'}/${d.id}').then((_) => _charger()))),
                if (_synchro != null) Padding(padding: const EdgeInsets.only(top: 12),
                    child: Text('Actualisé ${ilYa(_synchro)} · tirez pour rafraîchir', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
                ])),
              ]),
      ),
    );
  }
}
