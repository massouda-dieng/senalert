import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';
import 'package:senalert_mobile/features/incidents/models/incident_model.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

/// Accueil citoyen. Toutes les données affichées viennent de
/// AuthProvider / IncidentProvider (aucun chiffre en dur).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.navy800,
        onRefresh: () => context.read<IncidentProvider>().fetchIncidents(),
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: const [
            _HomeHeader(),
            SizedBox(height: 22),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SaFadeSlide(index: 2, child: _TypeGrid()),
                  SizedBox(height: 26),
                  SaFadeSlide(index: 3, child: _QuickAccess()),
                  SizedBox(height: 26),
                  SaFadeSlide(index: 4, child: _ActivitySection()),
                  SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SaBottomNav(currentIndex: 0),
    );
  }
}

// ---------------------------------------------------------------------------
// En-tête bleu nuit : salutation, carte « Signaler », bouton SOS
// ---------------------------------------------------------------------------
class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.userName.contains('@') ? auth.userName.split('@').first : auth.userName;

    return SaNightBackdrop(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const SaLogo(size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SenAlert', style: SaText.display(17, color: Colors.white)),
                    Row(children: [
                      Icon(Icons.location_on_rounded, size: 13, color: Colors.white.withOpacity(0.7)),
                      const SizedBox(width: 3),
                      Text('Sénégal', style: SaText.body(12, color: Colors.white.withOpacity(0.7))),
                    ]),
                  ]),
                ),
                SaIconButton(
                  icon: Icons.person_rounded,
                  tooltip: 'Profil',
                  onTap: () => context.go('/profile'),
                ),
              ]),
              const SizedBox(height: 22),
              SaFadeSlide(
                child: Text(
                  name.isEmpty ? 'Bonjour 👋' : 'Bonjour $name 👋',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SaText.display(25, color: Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Text('Ensemble, faisons la différence !',
                  style: SaText.body(14, color: Colors.white.withOpacity(0.75))),
              const SizedBox(height: 20),

              // SOS — action la plus visible
              const SaFadeSlide(index: 1, child: _SosHero()),
              const SizedBox(height: 14),

              // Signaler un incident (carte verre)
              SaFadeSlide(
                index: 1,
                child: SaGlass(
                  onTap: () => context.go('/report'),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.photo_camera_rounded, color: AppColors.navy800, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Signaler un incident', style: SaText.display(16, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text('Photo, description et position GPS',
                            style: SaText.body(12.5, color: Colors.white.withOpacity(0.75))),
                      ]),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(gradient: AppColors.orangeGradient, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grand bouton SOS rouge lumineux (pulsation).
class _SosHero extends StatelessWidget {
  const _SosHero();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Alerte SOS géolocalisée',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => context.go('/sos'),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
            decoration: BoxDecoration(
              gradient: AppColors.sosGradient,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
              boxShadow: [
                BoxShadow(color: AppColors.crimson.withOpacity(0.55), blurRadius: 28, offset: const Offset(0, 10)),
              ],
            ),
            child: Row(children: [
              SaPulse(
                size: 84,
                color: Colors.white,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                  ),
                  alignment: Alignment.center,
                  child: Text('SOS', style: SaText.display(17, color: AppColors.crimson, weight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Alerte SOS', style: SaText.display(20, color: Colors.white, weight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text('Maintenez 3 s pour alerter les secours avec votre position',
                      style: SaText.body(12.5, color: Colors.white.withOpacity(0.92), weight: FontWeight.w600)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Types d'incident réels → ouvre le formulaire avec le type pré-sélectionné
// ---------------------------------------------------------------------------
class _TypeGrid extends StatelessWidget {
  const _TypeGrid();

  static const _types = [
    ('accident', 'Accident', SaIncidentType.accident),
    ('incendie', 'Incendie', SaIncidentType.incendie),
    ('inondation', 'Inondation', SaIncidentType.inondation),
    ('urgence_medicale', 'Urgence\nmédicale', SaIncidentType.medical),
    ('electricite', 'Électricité', SaIncidentType.electricite),
    ('insecurite', 'Insécurité', SaIncidentType.insecurite),
    ('autre', 'Autre', SaIncidentType.autre),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SaSectionTitle('Que voulez-vous signaler ?',
          actionLabel: 'Signaler', onAction: () => context.go('/report')),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
        children: _types.map((t) {
          return SaCard(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            onTap: () => context.go('/report?type=${t.$1}'),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              SaTypeIcon(t.$1, size: 42),
              const SizedBox(height: 8),
              Text(t.$2,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: SaText.body(11, color: AppColors.textDark, weight: FontWeight.w700)
                      .copyWith(height: 1.15)),
            ]),
          );
        }).toList(),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Accès rapide vers des écrans existants
// ---------------------------------------------------------------------------
class _QuickAccess extends StatelessWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.smart_toy_rounded, 'Assistant IA', 'Premiers secours', AppColors.blue600, '/first-aid'),
      (Icons.local_hospital_rounded, 'Services proches', 'Hôpitaux, police…', AppColors.emerald, '/services'),
      (Icons.receipt_long_rounded, 'Mes signalements', 'Suivi des statuts', AppColors.orangeDeep, '/incidents'),
      (Icons.map_rounded, 'Carte', 'Incidents autour', const Color(0xFF7C3AED), '/map'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SaSectionTitle('Accès rapide'),
      const SizedBox(height: 10),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: items.map((it) {
          return SaCard(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onTap: () => context.go(it.$5),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: it.$4.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(it.$1, color: it.$4, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SaText.body(13, color: AppColors.textDark, weight: FontWeight.w700)),
                    Text(it.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: SaText.body(11)),
                  ],
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Activité réelle : compteurs + derniers signalements (IncidentProvider)
// ---------------------------------------------------------------------------
class _ActivitySection extends StatelessWidget {
  const _ActivitySection();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IncidentProvider>();
    final list = p.incidents;
    final enCours = list.where((i) => i.status == 'en_cours').length;
    final resolus = list.where((i) => i.status == 'resolu' || i.status == 'traite').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SaSectionTitle('Derniers signalements',
          actionLabel: list.isEmpty ? null : 'Tout voir', onAction: () => context.go('/incidents')),
      const SizedBox(height: 10),
      if (p.isLoading && list.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: AppColors.navy800)),
        )
      else ...[
        if (p.error != null) ...[
          SaInfoBanner(p.error!),
          const SizedBox(height: 12),
        ],
        if (list.isNotEmpty) ...[
          Row(children: [
            _Counter(label: 'Total', value: list.length, color: AppColors.navy800, icon: Icons.layers_rounded),
            const SizedBox(width: 10),
            _Counter(label: 'En cours', value: enCours, color: AppColors.blue600, icon: Icons.autorenew_rounded),
            const SizedBox(width: 10),
            _Counter(label: 'Résolus', value: resolus, color: AppColors.emerald, icon: Icons.check_circle_rounded),
          ]),
          const SizedBox(height: 12),
          ...list.take(3).map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MiniIncident(incident: i),
              )),
        ] else if (p.error == null)
          const SaCard(
            child: SaEmptyState(
              icon: Icons.inbox_rounded,
              title: 'Aucun signalement pour le moment',
              message: 'Vos signalements apparaîtront ici.',
            ),
          ),
      ],
    ]);
  }
}

class _Counter extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  const _Counter({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SaCard(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text('${v.round()}', style: SaText.display(22, color: color)),
          ),
          Text(label, style: SaText.body(11.5, weight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _MiniIncident extends StatelessWidget {
  final Incident incident;
  const _MiniIncident({required this.incident});

  @override
  Widget build(BuildContext context) {
    final t = SaIncidentType.of(incident.type);
    return SaCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.go('/incidents/${incident.id}'),
      child: Row(children: [
        SaTypeIcon(incident.type, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.label, style: SaText.body(14, color: AppColors.textDark, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              [incident.location, incident.date].where((s) => s.isNotEmpty).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SaText.body(12),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        SaStatusBadge(incident.status, dense: true),
      ]),
    );
  }
}
