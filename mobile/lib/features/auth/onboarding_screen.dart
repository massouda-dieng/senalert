import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';

/// Clé SharedPreferences pour mémoriser que l'onboarding a déjà été vu.
const _kOnboardingVu = 'onboarding_vu';

/// Vérifie si l'onboarding doit être affiché (première ouverture seulement).
Future<bool> onboardingAVoir() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool(_kOnboardingVu) ?? false);
}

Future<void> _marquerVu() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingVu, true);
}

// ─────────────────────────────────────────────
// Données des slides
// ─────────────────────────────────────────────

class _Slide {
  final String titre;
  final String description;
  final Widget illustration;
  const _Slide({required this.titre, required this.description, required this.illustration});
}

List<_Slide> _buildSlides() => [
      const _Slide(
        titre: 'SOS en un geste',
        description: 'Appuyez sur le bouton et votre alerte part immédiatement vers le service de secours de votre zone.',
        illustration: _IllustrationSOS(),
      ),
      const _Slide(
        titre: 'Suivi en direct',
        description: 'Suivez chaque étape de votre signalement. Vous savez toujours où en est votre dossier.',
        illustration: _IllustrationSuivi(),
      ),
      const _Slide(
        titre: 'Signalez une urgence',
        description: 'Incendie, inondation, accident… Choisissez la catégorie et décrivez la situation en quelques secondes.',
        illustration: _IllustrationSignaler(),
      ),
      const _Slide(
        titre: 'Ensemble, protégeons des vies',
        description: 'Rejoignez la communauté SenAlert. Confirmez les incidents autour de vous et renforcez les alertes.',
        illustration: _IllustrationCommunaute(),
      ),
    ];

// ─────────────────────────────────────────────
// Écran principal
// ─────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _ctrl = PageController();
  late final List<_Slide> slides = _buildSlides();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _ctrl.animateToPage(index, duration: const Duration(milliseconds: 380), curve: Curves.easeInOutCubic);
  }

  void _suivant() {
    if (_page < slides.length - 1) {
      _goTo(_page + 1);
    } else {
      _terminer();
    }
  }

  Future<void> _terminer() async {
    await _marquerVu();
    if (mounted) context.go('/bienvenue');
  }

  @override
  Widget build(BuildContext context) {
    final dernier = _page == slides.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Column(
          children: [
            // Bouton « Passer »
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
                child: TextButton(
                  onPressed: _terminer,
                  style: TextButton.styleFrom(foregroundColor: Colors.white54),
                  child: const Text('Passer', style: TextStyle(fontSize: 14)),
                ),
              ),
            ),

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlidePage(slide: slides[i], actif: _page == i),
              ),
            ),

            // Indicateurs de page + bouton
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  // Points
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(slides.length, (i) => _Dot(actif: i == _page, onTap: () => _goTo(i))),
                  ),
                  const SizedBox(height: 24),
                  // Bouton principal
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _suivant,
                      style: FilledButton.styleFrom(
                        backgroundColor: dernier ? AppColors.rouge : AppColors.marine600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          dernier ? 'Commencer' : 'Suivant',
                          key: ValueKey(dernier),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Slide individuel
// ─────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  final _Slide slide;
  final bool actif;
  const _SlidePage({required this.slide, required this.actif});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            flex: 6,
            child: AnimatedScale(
              scale: actif ? 1.0 : 0.94,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              child: slide.illustration,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  slide.titre,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  slide.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.white60, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Indicateur de page (point)
// ─────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final bool actif;
  final VoidCallback onTap;
  const _Dot({required this.actif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: actif ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: actif ? AppColors.marine600 : Colors.white24,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Illustration 1 — SOS
// ─────────────────────────────────────────────

class _IllustrationSOS extends StatefulWidget {
  const _IllustrationSOS();

  @override
  State<_IllustrationSOS> createState() => _IllustrationSOSState();
}

class _IllustrationSOSState extends State<_IllustrationSOS> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _SOSPainter(_ctrl.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SOSPainter extends CustomPainter {
  final double t;
  _SOSPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final baseR = math.min(cx, cy) * 0.28;

    // Anneaux pulsants
    for (int i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1.0;
      final r = baseR + (size.shortestSide * 0.35) * phase;
      final opacity = (1 - phase) * 0.25;
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = const Color(0xFFEF4444).withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Cercle bouton SOS
    canvas.drawCircle(Offset(cx, cy), baseR, Paint()..color = const Color(0xFFEF4444));

    // Texte SOS
    final tp = TextPainter(
      text: const TextSpan(
        text: 'SOS',
        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    // Petit indicateur tactile
    final dotPos = Offset(cx + baseR * 0.4, cy + baseR * 0.65);
    canvas.drawCircle(dotPos, 8, Paint()..color = Colors.white.withOpacity(0.35));
    canvas.drawCircle(dotPos, 4, Paint()..color = Colors.white.withOpacity(0.7));
  }

  @override
  bool shouldRepaint(_SOSPainter old) => old.t != t;
}

// ─────────────────────────────────────────────
// Illustration 2 — Suivi en direct
// ─────────────────────────────────────────────

class _IllustrationSuivi extends StatefulWidget {
  const _IllustrationSuivi();

  @override
  State<_IllustrationSuivi> createState() => _IllustrationSuiviState();
}

class _IllustrationSuiviState extends State<_IllustrationSuivi> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _SuiviPainter(_ctrl.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SuiviPainter extends CustomPainter {
  final double t;
  _SuiviPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final p0 = Offset(w * 0.15, h * 0.62);
    final p1 = Offset(w * 0.40, h * 0.38);
    final p2 = Offset(w * 0.65, h * 0.55);
    final p3 = Offset(w * 0.85, h * 0.32);

    // Chemin complet (gris subtil)
    final cheminPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);
    canvas.drawPath(path, cheminPaint);

    // Portion animée (teal) via PathMetrics
    final cheminActif = Paint()
      ..color = const Color(0xFF14B8A6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final metrics = path.computeMetrics();
    if (metrics.isNotEmpty) {
      final metric = metrics.first;
      final portion = metric.extractPath(0, metric.length * t);
      canvas.drawPath(portion, cheminActif);

      // Position de l'agent animé
      final tangent = metric.getTangentForOffset(metric.length * t);
      if (tangent != null) {
        _dessinerPin(canvas, tangent.position, const Color(0xFF14B8A6));
      }
    }

    // Point citoyen (rouge fixe)
    _dessinerPin(canvas, p0, const Color(0xFFEF4444));
    // Point destination (marine fixe)
    _dessinerPin(canvas, p3, AppColors.marine600);

    // Étapes intermédiaires
    for (final pt in [p1, p2]) {
      canvas.drawCircle(pt, 5, Paint()..color = Colors.white24);
      canvas.drawCircle(pt, 3, Paint()..color = Colors.white38);
    }

    // Badges statut
    _dessinerBadge(canvas, Offset(w * 0.28, h * 0.22), 'Recu', const Color(0xFF14B8A6));
    _dessinerBadge(canvas, Offset(w * 0.58, h * 0.70), 'En cours', const Color(0xFFF59E0B));
    _dessinerBadge(canvas, Offset(w * 0.72, h * 0.17), 'Resolu', const Color(0xFF22C55E));
  }

  void _dessinerPin(Canvas canvas, Offset pos, Color couleur) {
    canvas.drawCircle(pos, 16, Paint()..color = couleur.withOpacity(0.2));
    canvas.drawCircle(pos, 12, Paint()..color = couleur);
    canvas.drawCircle(pos, 4, Paint()..color = Colors.white);
  }

  void _dessinerBadge(Canvas canvas, Offset pos, String texte, Color couleur) {
    final tp = TextPainter(
      text: TextSpan(
        text: texte,
        style: TextStyle(color: couleur, fontSize: 10, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 8.0;
    const padV = 4.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pos.dx, pos.dy, tp.width + padH * 2, tp.height + padV * 2),
      const Radius.circular(6),
    );
    canvas.drawRRect(rect, Paint()..color = couleur.withOpacity(0.15));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = couleur.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    tp.paint(canvas, Offset(pos.dx + padH, pos.dy + padV));
  }

  @override
  bool shouldRepaint(_SuiviPainter old) => old.t != t;
}

// ─────────────────────────────────────────────
// Illustration 3 — Signaler
// ─────────────────────────────────────────────

class _IllustrationSignaler extends StatefulWidget {
  const _IllustrationSignaler();

  @override
  State<_IllustrationSignaler> createState() => _IllustrationSignalerState();
}

class _IllustrationSignalerState extends State<_IllustrationSignaler> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _SignalerPainter(_ctrl.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SignalerPainter extends CustomPainter {
  final double t;
  _SignalerPainter(this.t);

  static const List<(String, String, Color)> _categories = [
    ('Incendie', 'FIRE', Color(0xFFEF4444)),
    ('Inondation', 'WAVE', Color(0xFF3B82F6)),
    ('Accident', 'CAR', Color(0xFFF59E0B)),
    ('Medical', 'MED', Color(0xFF22C55E)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 - 20;

    final cardW = size.width * 0.35;
    final cardH = size.height * 0.22;
    final gap = size.width * 0.06;

    final positions = [
      Offset(cx - cardW - gap / 2, cy - cardH - gap / 2),
      Offset(cx + gap / 2, cy - cardH - gap / 2),
      Offset(cx - cardW - gap / 2, cy + gap / 2),
      Offset(cx + gap / 2, cy + gap / 2),
    ];

    final activeIdx = (t * _categories.length).floor() % _categories.length;

    for (int i = 0; i < _categories.length; i++) {
      final (label, code, couleur) = _categories[i];
      final pos = positions[i];
      final isActive = i == activeIdx;
      _dessinerCarte(canvas, pos, cardW, cardH, label, code, couleur, isActive);
    }

    // Bouclier central avec checkmark
    _dessinerBouclier(canvas, Offset(cx, cy), 26);
  }

  void _dessinerCarte(Canvas canvas, Offset pos, double w, double h, String label, String code, Color couleur, bool active) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pos.dx, pos.dy, w, h),
      const Radius.circular(14),
    );

    canvas.drawRRect(rect, Paint()..color = active ? couleur.withOpacity(0.18) : Colors.white.withOpacity(0.06));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = active ? couleur.withOpacity(0.7) : Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 1.6 : 1.0,
    );

    // Icone texte court (pas d'emoji pour eviter les problemes de rendu)
    final tpCode = TextPainter(
      text: TextSpan(
        text: code,
        style: TextStyle(color: active ? couleur : Colors.white38, fontSize: 13, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpCode.paint(canvas, Offset(pos.dx + w / 2 - tpCode.width / 2, pos.dy + h * 0.18));

    final tpLabel = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: active ? couleur : Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpLabel.paint(canvas, Offset(pos.dx + w / 2 - tpLabel.width / 2, pos.dy + h * 0.62));
  }

  void _dessinerBouclier(Canvas canvas, Offset center, double r) {
    canvas.drawCircle(center, r + 8, Paint()..color = AppColors.marine600.withOpacity(0.2));
    canvas.drawCircle(center, r, Paint()..color = AppColors.marine800);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = AppColors.marine600
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(center.dx - 8, center.dy), Offset(center.dx - 2, center.dy + 6), paint);
    canvas.drawLine(Offset(center.dx - 2, center.dy + 6), Offset(center.dx + 9, center.dy - 6), paint);
  }

  @override
  bool shouldRepaint(_SignalerPainter old) => old.t != t;
}

// ─────────────────────────────────────────────
// Illustration 4 — Communauté
// ─────────────────────────────────────────────

class _IllustrationCommunaute extends StatefulWidget {
  const _IllustrationCommunaute();

  @override
  State<_IllustrationCommunaute> createState() => _IllustrationCommunauteState();
}

class _IllustrationCommunauteState extends State<_IllustrationCommunaute> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _CommunautePainter(_ctrl.value),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _CommunautePainter extends CustomPainter {
  final double t;
  _CommunautePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.58;

    const n = 6;
    final nodes = List.generate(n, (i) {
      final angle = (i / n) * 2 * math.pi - math.pi / 2;
      return Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
    });

    // Lignes de connexion
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        if ((j - i) <= 2 || (j - i) >= n - 1) {
          final phase = ((t * n + i + j) % 1.0);
          linePaint.color = const Color(0xFF22C55E).withOpacity(0.12 + 0.10 * math.sin(phase * math.pi));
          canvas.drawLine(nodes[i], nodes[j], linePaint);
        }
      }
    }

    // Nœuds
    const couleurs = [
      Color(0xFF22C55E),
      Color(0xFF14B8A6),
      Color(0xFF3B82F6),
      Color(0xFFEF4444),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
    ];

    for (int i = 0; i < n; i++) {
      final pos = nodes[i];
      final c = couleurs[i];
      final pulse = math.sin((t * 2 * math.pi) + i) * 0.5 + 0.5;

      canvas.drawCircle(pos, 18 + pulse * 4, Paint()..color = c.withOpacity(0.12));
      canvas.drawCircle(pos, 16, Paint()..color = c.withOpacity(0.2));
      canvas.drawCircle(
        pos,
        16,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      // Tete
      canvas.drawCircle(Offset(pos.dx, pos.dy - 4), 5, Paint()..color = c);
      // Corps (arc)
      canvas.drawArc(
        Rect.fromCenter(center: Offset(pos.dx, pos.dy + 5), width: 14, height: 10),
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Centre : cercle avec coeur
    final centerR = math.min(cx, cy) * 0.20;
    canvas.drawCircle(Offset(cx, cy), centerR + 10, Paint()..color = const Color(0xFF22C55E).withOpacity(0.15));
    canvas.drawCircle(Offset(cx, cy), centerR, Paint()..color = const Color(0xFF0F2240));
    canvas.drawCircle(
      Offset(cx, cy),
      centerR,
      Paint()
        ..color = const Color(0xFF22C55E).withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    _dessinerCoeur(canvas, Offset(cx, cy), centerR * 0.45, const Color(0xFF22C55E));

    // Badges notification
    _dessinerNotif(canvas, Offset(cx + r * 0.15, cy - r * 0.72), '+');
    _dessinerNotif(canvas, Offset(cx - r * 0.30, cy + r * 0.62), '!');
  }

  void _dessinerCoeur(Canvas canvas, Offset center, double r, Color couleur) {
    final path = Path();
    path.moveTo(center.dx, center.dy + r * 0.6);
    path.cubicTo(
      center.dx - r * 1.4, center.dy - r * 0.2,
      center.dx - r * 1.4, center.dy - r * 1.2,
      center.dx, center.dy - r * 0.4,
    );
    path.cubicTo(
      center.dx + r * 1.4, center.dy - r * 1.2,
      center.dx + r * 1.4, center.dy - r * 0.2,
      center.dx, center.dy + r * 0.6,
    );
    path.close();
    canvas.drawPath(path, Paint()..color = couleur);
  }

  void _dessinerNotif(Canvas canvas, Offset pos, String symbol) {
    canvas.drawCircle(pos, 10, Paint()..color = const Color(0xFF1E3A5F));
    canvas.drawCircle(
      pos,
      10,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(_CommunautePainter old) => old.t != t;
}
