import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';
import 'package:senalert_mobile/features/incidents/models/incident_model.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _waveCtrl;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));
    _heroCtrl.forward();
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Rediriger agents/admins vers leur tableau de bord
    if (auth.isAgent) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/agent-dashboard'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.navy800,
        onRefresh: () => context.read<IncidentProvider>().fetchIncidents(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // ── HERO SECTION ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _heroFade,
                child: SlideTransition(
                  position: _heroSlide,
                  child: _HeroSection(waveCtrl: _waveCtrl),
                ),
              ),
            ),

            // ── CONTENU PRINCIPAL ──────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 28),
                  SaFadeSlide(index: 2, child: _TypeGrid()),
                  const SizedBox(height: 28),
                  SaFadeSlide(index: 3, child: _QuickAccess()),
                  const SizedBox(height: 28),
                  SaFadeSlide(index: 4, child: _ActivitySection()),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SaBottomNav(currentIndex: 0),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO SECTION : fond animé, salutation, bouton SOS, carte Signaler
// ─────────────────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final AnimationController waveCtrl;
  const _HeroSection({required this.waveCtrl});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.userName.contains('@')
        ? auth.userName.split('@').first
        : auth.userName;
    final firstName = name.isNotEmpty
        ? name[0].toUpperCase() + name.substring(1)
        : '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Fond dégradé animé
        ClipPath(
          clipper: _HeroClipper(),
          child: AnimatedBuilder(
            animation: waveCtrl,
            builder: (_, __) => Container(
              height: 420,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: const [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF0F172A)],
                  stops: [
                    0.0,
                    0.4 + 0.1 * math.sin(waveCtrl.value * 2 * math.pi),
                    1.0,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Cercles décoratifs animés
                  Positioned(
                    right: -60 + 20 * math.sin(waveCtrl.value * math.pi),
                    top: -40,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.orange.withOpacity(0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -80,
                    bottom: 60 + 10 * math.cos(waveCtrl.value * math.pi),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.crimson.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 40,
                    bottom: 100,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.03),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Contenu hero
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Topbar
                Row(children: [
                  const SaLogo(size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('SenAlert', style: SaText.display(18, color: Colors.white)),
                      Row(children: [
                        Icon(Icons.circle, size: 8,
                            color: const Color(0xFF34D399).withOpacity(0.9)),
                        const SizedBox(width: 5),
                        Text('Système d\'alerte national',
                            style: SaText.body(11, color: Colors.white.withOpacity(0.6))),
                      ]),
                    ]),
                  ),
                  // Notifications
                  _TopbarBtn(icon: Icons.notifications_rounded, onTap: () {}),
                  const SizedBox(width: 8),
                  // Profil
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.navyGradient,
                        border: Border.all(color: AppColors.orange, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                        style: SaText.display(16, color: Colors.white),
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 28),

                // Salutation principale
                Text(
                  firstName.isEmpty ? 'Bonjour 👋' : 'Bonjour, $firstName 👋',
                  style: SaText.display(28, color: Colors.white, weight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ensemble, protégeons le Sénégal',
                  style: SaText.body(14, color: Colors.white.withOpacity(0.7)),
                ),

                const SizedBox(height: 24),

                // Bouton SOS principal — le plus visible
                _SosBigButton(),

                const SizedBox(height: 14),

                // Carte Signaler un incident
                _SignalerCard(),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopbarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopbarBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withOpacity(0.1),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

/// Grand bouton SOS rouge avec pulsation
class _SosBigButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/sos'),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: AppColors.sosGradient,
          boxShadow: [
            BoxShadow(color: AppColors.crimson.withOpacity(0.5), blurRadius: 32, offset: const Offset(0, 12)),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              colors: [AppColors.crimson, const Color(0xFFBE123C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(children: [
            SaPulse(
              size: 80,
              color: Colors.white,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                ),
                alignment: Alignment.center,
                child: Text('SOS', style: SaText.display(16, color: AppColors.crimson, weight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Alerte SOS d\'urgence',
                    style: SaText.display(18, color: Colors.white, weight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Maintenez 3 secondes pour alerter\nles secours avec votre position GPS',
                    style: SaText.body(12, color: Colors.white.withOpacity(0.9))),
              ]),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Carte Signaler un incident en glassmorphisme
class _SignalerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/report'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.orangeGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add_alert_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Signaler un incident',
                  style: SaText.display(15, color: Colors.white, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('Accident, incendie, inondation…',
                  style: SaText.body(12.5, color: Colors.white.withOpacity(0.7))),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: AppColors.orangeGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Signaler', style: SaText.body(12, color: Colors.white, weight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

/// Clipper pour découper le bas du hero en courbe
class _HeroClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final p = Path();
    p.lineTo(0, s.height - 50);
    p.quadraticBezierTo(s.width * 0.5, s.height + 20, s.width, s.height - 50);
    p.lineTo(s.width, 0);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// GRILLE TYPES D'INCIDENTS
// ─────────────────────────────────────────────────────────────────────────────
class _TypeGrid extends StatelessWidget {
  const _TypeGrid();

  static const _types = [
    ('accident', 'Accident'),
    ('incendie', 'Incendie'),
    ('inondation', 'Inondation'),
    ('urgence_medicale', 'Urgence\nmédicale'),
    ('electricite', 'Électricité'),
    ('insecurite', 'Insécurité'),
    ('autre', 'Autre'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SaSectionTitle('Que voulez-vous signaler ?',
          actionLabel: 'Voir tous', onAction: () => context.go('/report')),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
        children: _types.map((t) {
          return _TypeCell(code: t.$1, label: t.$2);
        }).toList(),
      ),
    ]);
  }
}

class _TypeCell extends StatefulWidget {
  final String code;
  final String label;
  const _TypeCell({required this.code, required this.label});

  @override
  State<_TypeCell> createState() => _TypeCellState();
}

class _TypeCellState extends State<_TypeCell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = SaIncidentType.of(widget.code);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        context.go('/report?type=${widget.code}');
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: t.color.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: t.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(t.icon, color: t.color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: SaText.body(11, color: AppColors.textDark, weight: FontWeight.w700)
                  .copyWith(height: 1.2),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCÈS RAPIDE
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAccess extends StatelessWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.smart_toy_rounded, 'Assistant IA', 'Premiers secours', AppColors.blue600, '/first-aid'),
      (Icons.local_hospital_rounded, 'Services proches', 'Hôpitaux, police…', AppColors.emerald, '/services'),
      (Icons.receipt_long_rounded, 'Mes signalements', 'Suivi des statuts', AppColors.orangeDeep, '/incidents'),
      (Icons.map_rounded, 'Carte nationale', 'Incidents autour', const Color(0xFF7C3AED), '/map'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SaSectionTitle('Accès rapide'),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.4,
        children: items.map((it) {
          return _QuickCard(
            icon: it.$1, title: it.$2, sub: it.$3, color: it.$4, route: it.$5,
          );
        }).toList(),
      ),
    ]);
  }
}

class _QuickCard extends StatefulWidget {
  final IconData icon;
  final String title, sub, route;
  final Color color;
  const _QuickCard({required this.icon, required this.title, required this.sub,
      required this.color, required this.route});

  @override
  State<_QuickCard> createState() => _QuickCardState();
}

class _QuickCardState extends State<_QuickCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _hovered = true),
      onTapUp: (_) { setState(() => _hovered = false); context.go(widget.route); },
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _hovered ? widget.color.withOpacity(0.07) : AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hovered ? widget.color.withOpacity(0.4) : AppColors.border,
            width: _hovered ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(widget.icon, color: widget.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: SaText.body(13, color: AppColors.textDark, weight: FontWeight.w700)),
                Text(widget.sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: SaText.body(11)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITÉ RÉELLE
// ─────────────────────────────────────────────────────────────────────────────
class _ActivitySection extends StatelessWidget {
  const _ActivitySection();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<IncidentProvider>();
    final list = p.incidents;
    final enCours = list.where((i) => i.status == 'en_cours').length;
    final resolus = list.where((i) => i.status == 'resolu' || i.status == 'traite').length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SaSectionTitle('Mes derniers signalements',
          actionLabel: list.isEmpty ? null : 'Tout voir',
          onAction: () => context.go('/incidents')),
      const SizedBox(height: 12),

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
          const SizedBox(height: 14),
          ...list.take(3).map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MiniIncident(incident: i),
          )),
        ] else if (p.error == null)
          // État vide : incite à signaler
          GestureDetector(
            onTap: () => context.go('/report'),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
              ),
              child: Column(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.navy800.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_alert_outlined, size: 32, color: AppColors.navy800),
                ),
                const SizedBox(height: 14),
                Text('Aucun signalement', style: SaText.display(16, color: AppColors.textDark)),
                const SizedBox(height: 6),
                Text('Appuyez pour signaler votre premier incident',
                    textAlign: TextAlign.center,
                    style: SaText.body(13)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: AppColors.navyGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text('Faire un signalement',
                      style: SaText.body(13, color: Colors.white, weight: FontWeight.w700)),
                ),
              ]),
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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text('${v.round()}',
                style: SaText.display(22, color: color, weight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
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
    return GestureDetector(
      onTap: () => context.go('/incidents/${incident.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: t.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(t.icon, color: t.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.label,
                  style: SaText.body(14, color: AppColors.textDark, weight: FontWeight.w700)),
              const SizedBox(height: 3),
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
      ),
    );
  }
}
