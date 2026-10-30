import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models.dart';
import '../../state/configuration.dart';
import '../../state/session.dart';
import '../../ui/alertes_zone.dart';
import '../../ui/kit.dart';
import '../../ui/photo.dart';
import '../../state/langue.dart';

class AccueilCitoyen extends StatefulWidget {
  const AccueilCitoyen({super.key});
  @override
  State<AccueilCitoyen> createState() => _AccueilCitoyenState();
}

class _AccueilCitoyenState extends State<AccueilCitoyen> {
  List<Dossier>? _recents;
  ApiException? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final sos = await Api.instance.get<Map<String, dynamic>>('/alertes/sos/', params: {'taille': 3, 'actifs': true});
      final inc = await Api.instance.get<Map<String, dynamic>>('/incidents/', params: {'taille': 4});
      setState(() {
        _recents = [
          ...(sos['results'] as List).map((j) => Dossier.depuis(j, estSos: true)),
          ...(inc['results'] as List).map((j) => Dossier.depuis(j, estSos: false)),
        ];
        _erreur = null;
      });
    } on ApiException catch (e) {
      setState(() => _erreur = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Session>().utilisateur!;
    final config = context.watch<Configuration>();
    final actions = [
      (tr('Signaler'), tr('Accident, incendie…'), Icons.report_rounded, AppColors.jauneFonce, '/signaler'),
      (tr('Autour de moi'), tr('Incidents proches'), Icons.groups_rounded, const Color(0xFF1D4ED8), '/communaute'),
      (tr('Premiers secours'), tr('Fiches hors ligne'), Icons.healing_rounded, AppColors.crimson, '/secours'),
      (tr('Services proches'), tr('Hôpitaux, pharmacies…'), Icons.local_hospital_rounded, const Color(0xFF047857), '/services'),
      (tr('Assistant'), tr('Questions, prévention'), Icons.smart_toy_rounded, const Color(0xFF6D28D9), '/assistant'),
    ];
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _charger,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              child: Stack(children: [
                const Positioned.fill(child: PhotoIllustration('dakar-vue', credit: false)),
                const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xD9000000), Color(0x99000000), Color(0x33000000)])))),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 28),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('Bonjour {nom}', {'nom': u.prenom}).trim(), style: titre(24, couleur: Colors.white)),
                    Text(tr('Besoin d’aide immédiate ?'), style: const TextStyle(color: AppColors.jaune, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 22),
                    Center(
                      child: Semantics(
                        button: true,
                        label: tr('Déclencher une alerte SOS'),
                        child: GestureDetector(
                          onTap: () => context.push('/sos'),
                          child: Container(
                            width: 168, height: 168,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle, gradient: AppColors.sosGradient,
                              boxShadow: [BoxShadow(color: AppColors.crimson.withOpacity(0.5), blurRadius: 36, spreadRadius: 4)],
                              border: Border.all(color: Colors.white30, width: 8),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const Icon(Icons.crisis_alert_rounded, color: Colors.white, size: 40),
                              Text('SOS', style: titre(34, couleur: Colors.white)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(child: Text(tr('5 secondes pour annuler · position jointe si autorisée'), style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
                    const SizedBox(height: 18),
                    NumerosUrgence(config.numeros, sombre: true),
                  ]),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: BandeauAlertesZone(region: u.region.isEmpty ? null : u.region)),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid.count(
              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.55,
              children: [
                for (final a in actions)
                  Carte(onTap: () => context.push(a.$5), padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: a.$4.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(a.$3, color: a.$4)),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(a.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                    ]),
                  ])),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: Row(children: [
              Expanded(child: Text(tr('Mes derniers dossiers'), style: titre(17))),
              TextButton(onPressed: () => context.go('/dossiers'), child: Text(tr('Tout voir'))),
            ])),
          ),
          if (_erreur != null) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16),
              child: Bandeau.erreur(_erreur!.message, action: TextButton(onPressed: _charger, child: Text(tr('Réessayer'))))))
          else if (_recents == null) const SliverToBoxAdapter(child: Chargement())
          else if (_recents!.isEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Text(tr('Aucun signalement pour l’instant.'), style: TextStyle(color: AppColors.textGrey))))
          else SliverList.separated(
            itemCount: _recents!.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TuileDossier(_recents![i], onTap: () => context.push('/dossier/${_recents![i].estSos ? 'sos' : 'incident'}/${_recents![i].id}').then((_) => _charger()))),
          ),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(20),
              child: Text(config.avertissement, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)))),
        ]),
      ),
    );
  }
}
