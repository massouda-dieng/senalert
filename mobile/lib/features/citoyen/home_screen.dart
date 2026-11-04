import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models.dart';
import '../../state/configuration.dart';
import '../../state/session.dart';
import '../../ui/alertes_zone.dart';
import '../../ui/cloche.dart';
import '../../ui/kit.dart';
import '../../ui/photo.dart';
import 'report_screen.dart';
import '../../state/langue.dart';

class AccueilCitoyen extends StatefulWidget {
  const AccueilCitoyen({super.key});
  @override
  State<AccueilCitoyen> createState() => _AccueilCitoyenState();
}

class _AccueilCitoyenState extends State<AccueilCitoyen> {
  List<Dossier>? _enCours;
  ApiException? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final sos = await Api.instance.get<Map<String, dynamic>>('/alertes/sos/', params: {'taille': 3, 'actifs': true});
      final inc = await Api.instance.get<Map<String, dynamic>>('/incidents/', params: {'taille': 3, 'actifs': true});
      setState(() {
        _enCours = [
          ...(sos['results'] as List).map((j) => Dossier.depuis(j, estSos: true)),
          ...(inc['results'] as List).map((j) => Dossier.depuis(j, estSos: false)),
        ].take(3).toList();
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
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _charger,
        child: CustomScrollView(slivers: [
          // Une photo, une question, deux actions. Le SOS est le bouton rouge flottant, sur tous les écrans.
          SliverToBoxAdapter(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
              child: Stack(children: [
                const Positioned.fill(child: PhotoIllustration('dakar-vue', credit: false)),
                const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Jetons.voileFort, Jetons.voileMoyen, Jetons.voileLeger])))),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(tr('Bonjour {nom}', {'nom': u.prenom}).trim(), style: titre(26, couleur: Colors.white))),
                      const ClocheNotifications(),
                    ]),
                    const SizedBox(height: 4),
                    Text(tr('Signalez un problème : nous l’envoyons à la structure compétente la plus proche.'),
                        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35)),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.marine900, minimumSize: const Size.fromHeight(52)),
                        onPressed: () => context.push('/signaler'), icon: const Icon(Icons.report_rounded), label: Text(tr('Signaler')))),
                      const SizedBox(width: 10),
                      Expanded(child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), minimumSize: const Size.fromHeight(52)),
                        onPressed: () => context.push('/services'), icon: const Icon(Icons.local_hospital_rounded), label: Text(tr('Services proches')))),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      const Icon(Icons.crisis_alert_rounded, size: 16, color: Colors.white70),
                      const SizedBox(width: 6),
                      Expanded(child: Text(tr('Danger immédiat : bouton SOS rouge en bas à droite.'), style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(child: BandeauAlertesZone(region: u.region.isEmpty ? null : u.region)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            sliver: SliverToBoxAdapter(child: Text(tr('Que voulez-vous signaler ?'), style: titre(18))),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.count(
              crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.25,
              children: [for (final c in config.categories) TuileCategorie(c, onTap: () => context.push('/signaler?type=${c.code}'))],
            ),
          ),
          if (_erreur != null) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16),
              child: Bandeau.erreur(_erreur!.message, action: TextButton(onPressed: _charger, child: Text(tr('Réessayer'))))))
          else if (_enCours == null) const SliverToBoxAdapter(child: Chargement())
          else if (_enCours!.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              sliver: SliverToBoxAdapter(child: Row(children: [
                Expanded(child: Text(tr('Mes dossiers en cours'), style: titre(18))),
                TextButton(onPressed: () => context.go('/dossiers'), child: Text(tr('Tout voir'))),
              ])),
            ),
            SliverList.separated(
              itemCount: _enCours!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TuileDossier(_enCours![i], onTap: () => context.push('/dossier/${_enCours![i].estSos ? 'sos' : 'incident'}/${_enCours![i].id}').then((_) => _charger()))),
            ),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(child: Row(children: [
              Expanded(child: _Raccourci(Icons.healing_rounded, tr('Premiers secours'), () => context.push('/secours'))),
              const SizedBox(width: 10),
              Expanded(child: _Raccourci(Icons.smart_toy_rounded, tr('Assistant'), () => context.push('/assistant'))),
            ])),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Numéros d’urgence'), style: titre(16)),
              const SizedBox(height: 8),
              NumerosUrgence(config.numeros),
            ])),
          ),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              child: Text(config.avertissement, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)))),
        ]),
      ),
    );
  }
}

class _Raccourci extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final VoidCallback onTap;
  const _Raccourci(this.icone, this.libelle, this.onTap);
  @override
  Widget build(BuildContext context) => Carte(
        onTap: onTap, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Icon(icone, color: AppColors.marine700),
          const SizedBox(width: 10),
          Expanded(child: Text(libelle, style: const TextStyle(fontWeight: FontWeight.w700))),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ]),
      );
}
