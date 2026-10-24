import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';

/// Kit visuel SenAlert (refonte UI). Purement présentationnel :
/// aucun appel API, aucune logique métier.

// ---------------------------------------------------------------------------
// Typographie
// ---------------------------------------------------------------------------
class SaText {
  static TextStyle display(double size,
          {Color color = AppColors.textDark, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.plusJakartaSans(
          fontSize: size, fontWeight: weight, color: color, letterSpacing: -0.3, height: 1.2);

  static TextStyle body(double size,
          {Color color = AppColors.textGrey, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: 1.45);
}

// ---------------------------------------------------------------------------
// Types d'incident réels (accident, inondation, incendie, électricité,
// insécurité, urgence médicale, autre)
// ---------------------------------------------------------------------------
class SaIncidentType {
  final String label;
  final IconData icon;
  final Color color;
  const SaIncidentType(this.label, this.icon, this.color);

  static const accident   = SaIncidentType('Accident', Icons.car_crash_rounded, Color(0xFFEA580C));
  static const inondation = SaIncidentType('Inondation', Icons.water_drop_rounded, Color(0xFF0284C7));
  static const incendie   = SaIncidentType('Incendie', Icons.local_fire_department_rounded, Color(0xFFDC2626));
  static const electricite = SaIncidentType('Coupure d\'électricité', Icons.bolt_rounded, Color(0xFFCA8A04));
  static const insecurite = SaIncidentType('Insécurité', Icons.gpp_maybe_rounded, Color(0xFF7C3AED));
  static const medical    = SaIncidentType('Urgence médicale', Icons.medical_services_rounded, Color(0xFF059669));
  static const autre      = SaIncidentType('Autre', Icons.more_horiz_rounded, Color(0xFF475569));

  /// Accepte un code backend (« urgence_medicale ») ou un libellé
  /// (« Urgence médicale », « Électricité / Panne »…).
  static SaIncidentType of(String raw) {
    final t = raw
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e');
    if (t.contains('accident')) return accident;
    if (t.contains('inondation')) return inondation;
    if (t.contains('incendie')) return incendie;
    if (t.contains('electric') || t.contains('panne')) return electricite;
    if (t.contains('insecu') || t.contains('vol') || t.contains('crim')) return insecurite;
    if (t.contains('medic') || t.contains('urgence')) return medical;
    return autre;
  }
}

// ---------------------------------------------------------------------------
// Statuts réels — incidents : nouveau, en_cours, resolu, refuse
//                 SOS       : nouveau, en_cours, traite
// ---------------------------------------------------------------------------
class SaStatus {
  final String label;
  final Color fg;
  final Color bg;
  final IconData icon;
  const SaStatus(this.label, this.fg, this.bg, this.icon);

  static SaStatus of(String raw) {
    switch (raw.toLowerCase()) {
      case 'nouveau':
      case 'en_attente':
        return const SaStatus('Nouveau', Color(0xFFB45309), Color(0xFFFEF3C7), Icons.fiber_new_rounded);
      case 'en_cours':
        return const SaStatus('En cours', Color(0xFF1D4ED8), Color(0xFFDBEAFE), Icons.autorenew_rounded);
      case 'resolu':
        return const SaStatus('Résolu', Color(0xFF047857), Color(0xFFD1FAE5), Icons.check_circle_rounded);
      case 'traite':
        return const SaStatus('Traité', Color(0xFF047857), Color(0xFFD1FAE5), Icons.check_circle_rounded);
      case 'refuse':
        return const SaStatus('Refusé', Color(0xFF475569), Color(0xFFE2E8F0), Icons.block_rounded);
      default:
        return SaStatus(raw, AppColors.textGrey, AppColors.surfaceSubtle, Icons.info_outline_rounded);
    }
  }
}

class SaStatusBadge extends StatelessWidget {
  final String status;
  final bool dense;
  const SaStatusBadge(this.status, {super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final s = SaStatus.of(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: s.fg, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(s.label,
            style: SaText.body(dense ? 10.5 : 11.5, color: s.fg, weight: FontWeight.w700)),
      ]),
    );
  }
}

/// Pastille d'icône colorée pour un type d'incident.
class SaTypeIcon extends StatelessWidget {
  final String type;
  final double size;
  const SaTypeIcon(this.type, {super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final t = SaIncidentType.of(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.color.withOpacity(0.16), t.color.withOpacity(0.08)],
        ),
        border: Border.all(color: t.color.withOpacity(0.18)),
      ),
      child: Icon(t.icon, color: t.color, size: size * 0.5),
    );
  }
}

// ---------------------------------------------------------------------------
// Conteneurs
// ---------------------------------------------------------------------------
class SaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final Color color;
  final Border? border;
  const SaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 20,
    this.color = AppColors.white,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: AppColors.border.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy800.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Panneau « verre » translucide pour les en-têtes sombres.
class SaGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  const SaGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withOpacity(0.09),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: Colors.white.withOpacity(0.16)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fond bleu nuit avec halos lumineux doux (ambiance futuriste).
class SaNightBackdrop extends StatelessWidget {
  final Widget? child;
  final BorderRadius? borderRadius;
  const SaNightBackdrop({super.key, this.child, this.borderRadius});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Stack(children: [
          Positioned(
            top: -80,
            right: -60,
            child: _Halo(color: AppColors.blue500.withOpacity(0.45), size: 240),
          ),
          Positioned(
            bottom: -90,
            left: -70,
            child: _Halo(color: AppColors.orange.withOpacity(0.22), size: 220),
          ),
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          if (child != null) child!,
        ]),
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  final Color color;
  final double size;
  const _Halo({required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// En-tête bleu nuit arrondi utilisé par tous les écrans internes.
class SaHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? bottom;
  final Widget? leading;
  const SaHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
    this.bottom,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return SaNightBackdrop(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (onBack != null)
                  SaIconButton(icon: Icons.arrow_back_rounded, onTap: onBack!, tooltip: 'Retour')
                else if (leading != null)
                  leading!
                else
                  const SizedBox(width: 8),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SaText.display(19, color: Colors.white)),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SaText.body(12, color: Colors.white.withOpacity(0.72))),
                        ),
                    ],
                  ),
                ),
                ...actions,
              ]),
              if (bottom != null) ...[
                const SizedBox(height: 14),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: bottom!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton icône 48 px (zone tactile accessible) pour fonds sombres.
class SaIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool light;
  const SaIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: light ? AppColors.surfaceSubtle : Colors.white.withOpacity(0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: light ? AppColors.border : Colors.white.withOpacity(0.14)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: light ? AppColors.navy800 : Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Onglets de filtre en pilule (Tous / En cours / Résolus…)
// ---------------------------------------------------------------------------
class SaSegmentedTabs<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool onDark;
  const SaSegmentedTabs({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withOpacity(0.1) : AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: onDark ? Colors.white.withOpacity(0.14) : AppColors.border),
      ),
      child: Row(
        children: options.map((o) {
          final active = o.$1 == value;
          return Expanded(
            child: Semantics(
              selected: active,
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(o.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: active ? AppColors.actionGradient : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: active
                        ? [BoxShadow(color: AppColors.blue600.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                        : null,
                  ),
                  child: Text(
                    o.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SaText.body(12.5,
                        color: active
                            ? Colors.white
                            : (onDark ? Colors.white.withOpacity(0.8) : AppColors.textGrey),
                        weight: active ? FontWeight.w700 : FontWeight.w600),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Titres de section
// ---------------------------------------------------------------------------
class SaSectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SaSectionTitle(this.title, {super.key, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(title, style: SaText.display(17))),
      if (actionLabel != null)
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.blue600,
            minimumSize: const Size(48, 40),
          ),
          child: Text(actionLabel!, style: SaText.body(13, color: AppColors.blue600, weight: FontWeight.w700)),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Animation d'apparition (fondu + glissement) pour les cartes
// ---------------------------------------------------------------------------
class SaFadeSlide extends StatelessWidget {
  final Widget child;
  final int index;
  final double offsetY;
  const SaFadeSlide({super.key, required this.child, this.index = 0, this.offsetY = 18});

  @override
  Widget build(BuildContext context) {
    final delay = math.min(index, 8) * 60;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + delay),
      curve: Interval(delay / (420 + delay), 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * offsetY), child: c),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// États vides / erreurs
// ---------------------------------------------------------------------------
class SaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final bool onDark;
  const SaEmptyState({super.key, required this.icon, required this.title, this.message, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onDark ? Colors.white.withOpacity(0.08) : AppColors.blue50,
          ),
          child: Icon(icon, size: 34, color: onDark ? Colors.white70 : AppColors.blue600),
        ),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: SaText.display(16, color: onDark ? Colors.white : AppColors.textDark)),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message!,
              textAlign: TextAlign.center,
              style: SaText.body(13, color: onDark ? Colors.white60 : AppColors.textGrey)),
        ],
      ]),
    );
  }
}

class SaInfoBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color color;
  const SaInfoBanner(this.message,
      {super.key, this.icon = Icons.wifi_off_rounded, this.color = AppColors.warning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: SaText.body(12.5, color: AppColors.textDark))),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation basse citoyen — 4 onglets
// ---------------------------------------------------------------------------
class SaBottomNav extends StatelessWidget {
  /// 0 Accueil · 1 Signalements · 2 Carte · 3 Profil · -1 aucun
  final int currentIndex;
  const SaBottomNav({super.key, required this.currentIndex});

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Accueil', '/home'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Signalements', '/incidents'),
    (Icons.map_outlined, Icons.map_rounded, 'Carte', '/map'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil', '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: AppColors.navy800.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Row(
            children: List.generate(_items.length, (i) {
              final it = _items[i];
              final active = i == currentIndex;
              return Expanded(
                child: Semantics(
                  selected: active,
                  label: it.$3,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: active ? null : () => context.go(it.$4),
                    child: SizedBox(
                      height: 56,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(horizontal: active ? 18 : 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: active ? AppColors.blue50 : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(active ? it.$2 : it.$1,
                              size: 23, color: active ? AppColors.navy800 : AppColors.textMuted),
                        ),
                        const SizedBox(height: 3),
                        Text(it.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SaText.body(11,
                                color: active ? AppColors.navy800 : AppColors.textGrey,
                                weight: active ? FontWeight.w700 : FontWeight.w500)),
                      ]),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo vectoriel SenAlert (épingle + cloche d'alerte)
// ---------------------------------------------------------------------------
class SaLogo extends StatelessWidget {
  final double size;
  const SaLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    // Épingle de localisation
    final pin = Path()
      ..moveTo(w * 0.5, h * 0.96)
      ..cubicTo(w * 0.18, h * 0.62, w * 0.08, h * 0.48, w * 0.08, h * 0.38)
      ..arcToPoint(Offset(w * 0.92, h * 0.38), radius: Radius.circular(w * 0.42))
      ..cubicTo(w * 0.92, h * 0.48, w * 0.82, h * 0.62, w * 0.5, h * 0.96)
      ..close();
    canvas.drawShadow(pin, Colors.black, 6, false);
    canvas.drawPath(
      pin,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFDDE6FF)],
        ).createShader(Offset.zero & s),
    );
    // Disque intérieur orange
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.38),
      w * 0.27,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFFB923C), Color(0xFFEA580C)])
            .createShader(Rect.fromCircle(center: Offset(w * 0.5, h * 0.38), radius: w * 0.27)),
    );
    // Cloche
    final bell = Paint()..color = Colors.white;
    final b = Path()
      ..moveTo(w * 0.36, h * 0.47)
      ..lineTo(w * 0.64, h * 0.47)
      ..lineTo(w * 0.6, h * 0.42)
      ..lineTo(w * 0.6, h * 0.35)
      ..arcToPoint(Offset(w * 0.4, h * 0.35), radius: Radius.circular(w * 0.1), clockwise: false)
      ..lineTo(w * 0.4, h * 0.42)
      ..close();
    canvas.drawPath(b, bell);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.035, bell);
    canvas.drawCircle(Offset(w * 0.5, h * 0.235), w * 0.025, bell);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Silhouette de Dakar : Monument de la Renaissance africaine + immeubles + mer
// ---------------------------------------------------------------------------
class SaDakarSkyline extends StatelessWidget {
  final double height;
  final Color color;
  const SaDakarSkyline({super.key, this.height = 120, this.color = const Color(0x33FFFFFF)});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SkylinePainter(color)),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  final Color color;
  _SkylinePainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final p = Paint()..color = color;
    final pFront = Paint()..color = color.withOpacity((color.opacity * 1.6).clamp(0, 1));

    // Immeubles du Plateau (arrière-plan, à droite)
    final rnd = math.Random(7);
    double x = w * 0.42;
    while (x < w) {
      final bw = w * (0.035 + rnd.nextDouble() * 0.04);
      final bh = h * (0.25 + rnd.nextDouble() * 0.45);
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(x, h * 0.86 - bh, bw, bh),
            topLeft: const Radius.circular(2), topRight: const Radius.circular(2)),
        p,
      );
      x += bw + w * 0.008;
    }
    // Phare des Mamelles (petit)
    canvas.drawRect(Rect.fromLTWH(w * 0.08, h * 0.5, w * 0.018, h * 0.2), p);
    canvas.drawCircle(Offset(w * 0.089, h * 0.49), w * 0.012, p);

    // Colline des Mamelles
    final hill = Path()
      ..moveTo(0, h * 0.86)
      ..quadraticBezierTo(w * 0.12, h * 0.68, w * 0.26, h * 0.62)
      ..quadraticBezierTo(w * 0.36, h * 0.66, w * 0.46, h * 0.86)
      ..close();
    canvas.drawPath(hill, pFront);

    // Monument de la Renaissance africaine (silhouette stylisée)
    final cx = w * 0.26, base = h * 0.63;
    final m = Path()
      // socle
      ..moveTo(cx - w * 0.035, base)
      ..lineTo(cx + w * 0.035, base)
      // homme (droite) jusqu'au bras levé tenant l'enfant
      ..lineTo(cx + w * 0.022, base - h * 0.22)
      ..lineTo(cx + w * 0.03, base - h * 0.34)
      ..lineTo(cx + w * 0.045, base - h * 0.46) // bras
      ..lineTo(cx + w * 0.058, base - h * 0.52) // enfant
      ..lineTo(cx + w * 0.05, base - h * 0.56)
      ..lineTo(cx + w * 0.036, base - h * 0.5)
      ..lineTo(cx + w * 0.02, base - h * 0.42) // tête homme
      ..lineTo(cx + w * 0.008, base - h * 0.44)
      ..lineTo(cx + w * 0.004, base - h * 0.37)
      // femme (gauche), bras tendu vers l'arrière
      ..lineTo(cx - w * 0.01, base - h * 0.33)
      ..lineTo(cx - w * 0.04, base - h * 0.3)
      ..lineTo(cx - w * 0.042, base - h * 0.27)
      ..lineTo(cx - w * 0.014, base - h * 0.27)
      ..lineTo(cx - w * 0.02, base - h * 0.12)
      ..close();
    canvas.drawPath(m, pFront);

    // Sol / bord de mer
    canvas.drawRect(Rect.fromLTWH(0, h * 0.86, w, h * 0.14), pFront);
    final wave = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 3; i++) {
      final y = h * (0.9 + i * 0.035);
      final path = Path()..moveTo(0, y);
      for (double xx = 0; xx <= w; xx += 24) {
        path.quadraticBezierTo(xx + 6, y - 2, xx + 12, y);
        path.quadraticBezierTo(xx + 18, y + 2, xx + 24, y);
      }
      canvas.drawPath(path, wave);
    }
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Avatar robot vectoriel (assistant IA)
// ---------------------------------------------------------------------------
class SaRobotAvatar extends StatefulWidget {
  final double size;
  final bool animate;
  const SaRobotAvatar({super.key, this.size = 40, this.animate = false});

  @override
  State<SaRobotAvatar> createState() => _SaRobotAvatarState();
}

class _SaRobotAvatarState extends State<SaRobotAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, widget.animate ? -3 * Curves.easeInOut.transform(_c.value) : 0),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(painter: _RobotPainter(glow: widget.animate ? _c.value : 0.5)),
        ),
      ),
    );
  }
}

class _RobotPainter extends CustomPainter {
  final double glow;
  _RobotPainter({required this.glow});

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final c = Offset(w / 2, h / 2);

    // Halo
    canvas.drawCircle(
      c,
      w * 0.5,
      Paint()
        ..shader = RadialGradient(colors: [
          AppColors.blue500.withOpacity(0.25 + 0.2 * glow),
          AppColors.blue500.withOpacity(0),
        ]).createShader(Rect.fromCircle(center: c, radius: w * 0.5)),
    );

    // Antenne
    final ant = Paint()
      ..color = const Color(0xFFCBD5F5)
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.5, h * 0.2), Offset(w * 0.5, h * 0.11), ant);
    canvas.drawCircle(Offset(w * 0.5, h * 0.09), w * 0.045,
        Paint()..color = Color.lerp(AppColors.orange, const Color(0xFFFDBA74), glow)!);

    // Oreilles
    final ear = Paint()..color = const Color(0xFF93A6D8);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.4, w * 0.08, h * 0.2), Radius.circular(w * 0.04)), ear);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.8, h * 0.4, w * 0.08, h * 0.2), Radius.circular(w * 0.04)), ear);

    // Tête
    final head = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.18, h * 0.2, w * 0.64, h * 0.6), Radius.circular(w * 0.22));
    canvas.drawRRect(
      head,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFD7E0F7)],
        ).createShader(head.outerRect),
    );

    // Visière
    final visor = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.25, h * 0.32, w * 0.5, h * 0.3), Radius.circular(w * 0.15));
    canvas.drawRRect(
      visor,
      Paint()
        ..shader = const LinearGradient(colors: [AppColors.navy900, AppColors.navy700]).createShader(visor.outerRect),
    );

    // Yeux lumineux
    final eye = Paint()
      ..color = Color.lerp(const Color(0xFF60A5FA), const Color(0xFF93C5FD), glow)!
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, w * 0.02);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.39, h * 0.46), width: w * 0.09, height: h * 0.11),
            Radius.circular(w * 0.05)),
        eye);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.61, h * 0.46), width: w * 0.09, height: h * 0.11),
            Radius.circular(w * 0.05)),
        eye);

    // Sourire
    final smile = Paint()
      ..color = const Color(0xFF93A6D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.03
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, h * 0.66), width: w * 0.18, height: h * 0.08), 0.2,
        math.pi - 0.4, false, smile);
  }

  @override
  bool shouldRepaint(covariant _RobotPainter old) => old.glow != glow;
}

// ---------------------------------------------------------------------------
// Halo pulsant (bouton SOS)
// ---------------------------------------------------------------------------
class SaPulse extends StatefulWidget {
  final Widget child;
  final Color color;
  final double size;
  final bool active;
  const SaPulse({super.key, required this.child, required this.size, this.color = AppColors.crimson, this.active = true});

  @override
  State<SaPulse> createState() => _SaPulseState();
}

class _SaPulseState extends State<SaPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Stack(alignment: Alignment.center, children: [
          if (widget.active)
            for (final phase in [0.0, 0.5])
              Builder(builder: (_) {
                final t = (_c.value + phase) % 1.0;
                return Container(
                  width: widget.size * (0.62 + 0.38 * t),
                  height: widget.size * (0.62 + 0.38 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(0.28 * (1 - t)),
                  ),
                );
              }),
          child!,
        ]),
        child: widget.child,
      ),
    );
  }
}
