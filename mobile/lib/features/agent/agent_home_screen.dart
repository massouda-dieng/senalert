import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../ui/credits_photos.dart';

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
  Timer? _actualisation;
  Set<String>? _connus;

  @override
  void initState() {
    super.initState();
    _charger();
    // Les dossiers affectés par le superviseur apparaissent d'eux-mêmes, avec une alerte (sans recharger l'écran).
    _actualisation = Timer.periodic(const Duration(seconds: 10), (_) { if (mounted) _charger(); });
  }

  @override
  void dispose() {
    _actualisation?.cancel();
    super.dispose();
  }

  void _signalerNouvelles(List<Dossier> missions) {
    final cles = {for (final d in missions) '${d.estSos ? 's' : 'i'}${d.id}'};
    final nouvelles = _connus == null ? const <Dossier>[] : missions.where((d) => !_connus!.contains('${d.estSos ? 's' : 'i'}${d.id}')).toList();
    _connus = cles;
    if (nouvelles.isEmpty || !mounted) return;
    HapticFeedback.heavyImpact();
    final d = nouvelles.first;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 8),
      backgroundColor: d.estSos ? AppColors.rougeFonce : AppColors.marine800,
      content: Text(nouvelles.length > 1 ? '${nouvelles.length} nouvelles interventions vous ont été affectées.'
          : '${d.estSos ? 'SOS' : 'Nouvelle intervention'} ${d.reference} vous a été affecté${d.estSos ? '' : 'e'} par votre superviseur.'),
      action: SnackBarAction(label: 'Ouvrir', textColor: Colors.white,
          onPressed: () => context.push('/dossier/${d.estSos ? 'sos' : 'incident'}/${d.id}')),
    ));
  }

  Future<List<Dossier>> _liste(String chemin, Map<String, dynamic> p, bool sos) async =>
      ((await Api.instance.get<Map<String, dynamic>>(chemin, params: p))['results'] as List).map((j) => Dossier.depuis(j, estSos: sos)).toList();

  /// L'agent se déclare disponible ou non : son superviseur le voit au moment d'affecter un dossier.
  Future<void> _basculerDisponibilite(bool disponible) async {
    setState(() => _bascule = true);
    try {
      final j = await Api.instance.post<Map<String, dynamic>>('/auth/disponibilite/', data: {'disponible': disponible});
      if (!mounted) return;
      context.read<Session>().remplacerProfil(j);
      afficherMessage(context, disponible ? 'Vous êtes disponible.' : 'Vous êtes indisponible : votre superviseur le voit avant de vous affecter un dossier.');
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
      if (!mounted) return;
      _signalerNouvelles([...r[0], ...r[1]]);
      setState(() {
        // Les missions les plus urgentes d'abord
        _miens = [...r[0], ...r[1]]..sort((a, b) => rangGravite(a.gravite).compareTo(rangGravite(b.gravite)));
        _activite = a;
        _erreur = null;
        _charge = true;
        _synchro = DateTime.now();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _erreur = e; _charge = true; });
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
                  kpi('À prendre en charge', '${_miens.where((d) => d.statut == 'affecte').length}', Icons.hourglass_top_rounded, AppColors.warning, onTap: () => context.go('/interventions')),
                  const SizedBox(width: 10),
                  kpi('En cours', '${_miens.where((d) => d.statut == 'accepte' || d.statut == 'en_cours').length}', Icons.assignment_outlined, AppColors.marine600),
                  const SizedBox(width: 10),
                  kpi('Finies 7 j', '${_activite?['resolus_7j'] ?? 0}', Icons.check_circle_rounded, AppColors.success),
                ]),
                if (_miens.isNotEmpty) ...[
                  Padding(padding: const EdgeInsets.only(top: 20, bottom: 8), child: Text('Mission la plus urgente', style: titre(17))),
                  _MissionPrincipale(_miens.first, onOuvrir: () => context.push('/dossier/${_miens.first.estSos ? 'sos' : 'incident'}/${_miens.first.id}').then((_) => _charger())),
                ],
                Padding(padding: const EdgeInsets.only(top: 20, bottom: 8), child: Row(children: [
                  Expanded(child: Text(_miens.length > 1 ? 'Autres missions' : 'Mes missions', style: titre(17))),
                  TextButton(onPressed: () => context.go('/interventions'), child: const Text('Tout voir')),
                ])),
                if (_miens.isEmpty) Carte(child: Row(children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Aucune mission active. Restez disponible : les citoyens et le superviseur vous transmettent les dossiers.',
                      style: TextStyle(color: AppColors.textGrey))),
                ])),
                for (final d in _miens.skip(1)) Padding(padding: const EdgeInsets.only(bottom: 10),
                    child: TuileDossier(d, onTap: () => context.push('/dossier/${d.estSos ? 'sos' : 'incident'}/${d.id}').then((_) => _charger()))),
                if (_synchro != null) Padding(padding: const EdgeInsets.only(top: 12),
                    child: Text('Actualisé ${ilYa(_synchro)} · tirez pour rafraîchir', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
                ])),
              ]),
      ),
    );
  }
}

/// Mission la plus urgente : grande photo du type, lieu, ancienneté et l'action suivante en un appui.
class _MissionPrincipale extends StatelessWidget {
  final Dossier d;
  final VoidCallback onOuvrir;
  const _MissionPrincipale(this.d, {required this.onOuvrir});
  @override
  Widget build(BuildContext context) {
    final action = switch (d.statut) { 'affecte' => 'Voir et prendre en charge', 'accepte' => 'Démarrer l’intervention', _ => 'Mettre à jour / clôturer' };
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onOuvrir, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: 130, child: Stack(fit: StackFit.expand, children: [
          if (d.estSos) const ColoredBox(color: AppColors.rougeFonce, child: Icon(Icons.sos_rounded, size: 64, color: Colors.white))
          else Image.asset('assets/images/photos/${photoCategorie[d.typeIncident] ?? 'dakar-vue'}.jpg', fit: BoxFit.cover, excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.marine50)),
          Positioned(left: 12, top: 12, child: BadgeStatut(d.statut)),
        ])),
        Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(d.estSos ? 'Alerte SOS${d.typeUrgenceLibelle != null && d.typeUrgence != 'non_precise' ? ' · ${d.typeUrgenceLibelle}' : ''}' : d.titre, style: titre(18)),
          const SizedBox(height: 4),
          Text('${d.reference} · ${ilYa(d.creation)}', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
          if (d.adresse.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
            Icon(Icons.place_outlined, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Expanded(child: Text(d.adresse, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ])),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: onOuvrir, icon: const Icon(Icons.arrow_forward_rounded), label: Text(action))),
            if (d.lat != null) ...[
              const SizedBox(width: 8),
              IconButton.outlined(tooltip: 'Itinéraire', onPressed: () => itineraire(d.lat!, d.lng!), icon: const Icon(Icons.navigation_rounded)),
            ],
          ]),
        ])),
      ])),
    );
  }
}
