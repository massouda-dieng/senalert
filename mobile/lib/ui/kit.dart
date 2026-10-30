import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/constants/app_colors.dart';
import '../core/format.dart';
import '../core/models.dart';

/// Système de design SenAlert (mêmes jetons que le web : bleu nuit, rouge réservé au SOS,
/// orange avertissement, vert résolution).
class AppTheme {
  /// Thème courant (clair ou sombre selon AppColors.sombre).
  static ThemeData clair() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        brightness: AppColors.sombre ? Brightness.dark : Brightness.light,
        seedColor: AppColors.vert800,
        primary: AppColors.sombre ? AppColors.vert600 : AppColors.vert800,
        secondary: AppColors.jaune,
        error: AppColors.crimson,
        surface: AppColors.white,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );
    final texte = GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: AppColors.textDark, displayColor: AppColors.textDark);
    final rond = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return base.copyWith(
      textTheme: texte,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(color: AppColors.textDark, fontSize: 19, fontWeight: FontWeight.w800),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: AppColors.vert800, minimumSize: const Size(64, 52), shape: rond,
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.vert800, minimumSize: const Size(64, 52), shape: rond,
        side: BorderSide(color: AppColors.border, width: 1.4),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.vert600, width: 1.6)),
      ),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.vert900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.vert50,
        labelTextStyle: WidgetStatePropertyAll(GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600)),
      ),
      cardTheme: CardTheme(color: AppColors.white, elevation: 0, shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.border))),
    );
  }
}

TextStyle titre(double taille, {Color? couleur}) =>
    GoogleFonts.plusJakartaSans(fontSize: taille, fontWeight: FontWeight.w800, color: couleur ?? AppColors.textDark, height: 1.2);

void afficherMessage(BuildContext context, String message, {bool erreur = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: erreur ? const Color(0xFFB91C1C) : const Color(0xFF047857),
      duration: Duration(seconds: erreur ? 6 : 3),
    ));
}

class BadgeStatut extends StatelessWidget {
  final String code;
  const BadgeStatut(this.code, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = statut(code);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: s.fond, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.icone, size: 13, color: s.couleur),
        const SizedBox(width: 4),
        Text(s.libelle, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: s.couleur)),
      ]),
    );
  }
}

class Carte extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? couleur;
  const Carte({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.couleur});
  @override
  Widget build(BuildContext context) => Material(
        color: couleur ?? AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class Bandeau extends StatelessWidget {
  final String texte;
  final String? titre;
  final IconData icone;
  final Color couleur;
  final Color fond;
  final Widget? action;
  const Bandeau(this.texte, {super.key, this.titre, this.icone = Icons.info_outline_rounded,
      this.couleur = AppColors.vert700, this.fond = AppColors.vert50, this.action});
  const Bandeau.alerte(this.texte, {super.key, this.titre, this.action})
      : icone = Icons.warning_amber_rounded, couleur = const Color(0xFF92400E), fond = const Color(0xFFFEF3C7);
  const Bandeau.erreur(this.texte, {super.key, this.titre, this.action})
      : icone = Icons.error_outline_rounded, couleur = const Color(0xFF991B1B), fond = const Color(0xFFFEE2E2);
  const Bandeau.succes(this.texte, {super.key, this.titre, this.action})
      : icone = Icons.check_circle_outline_rounded, couleur = const Color(0xFF065F46), fond = const Color(0xFFD1FAE5);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, color: couleur, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (titre != null) Text(titre!, style: TextStyle(fontWeight: FontWeight.w700, color: couleur)),
            Text(texte, style: TextStyle(color: couleur, height: 1.35)),
            if (action != null) Padding(padding: const EdgeInsets.only(top: 8), child: action!),
          ])),
        ]),
      );
}

class EtatVide extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String? texte;
  final Widget? action;
  const EtatVide({super.key, required this.icone, required this.titre, this.texte, this.action});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(20)),
                child: Icon(icone, size: 32, color: AppColors.textMuted)),
            const SizedBox(height: 14),
            Text(titre, style: titre_(16), textAlign: TextAlign.center),
            if (texte != null) Padding(padding: const EdgeInsets.only(top: 6),
                child: Text(texte!, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey))),
            if (action != null) Padding(padding: const EdgeInsets.only(top: 16), child: action!),
          ]),
        ),
      );
}

TextStyle titre_(double t) => titre(t);

class EtatErreur extends StatelessWidget {
  final ApiException erreur;
  final VoidCallback onReessayer;
  const EtatErreur(this.erreur, {super.key, required this.onReessayer});
  @override
  Widget build(BuildContext context) => EtatVide(
        icone: erreur.estReseau ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
        titre: erreur.estReseau ? 'Hors connexion' : 'Chargement impossible',
        texte: erreur.message,
        action: OutlinedButton.icon(onPressed: onReessayer, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
      );
}

class Chargement extends StatelessWidget {
  final String? texte;
  const Chargement({super.key, this.texte});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(strokeWidth: 2.6),
            if (texte != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(texte!, style: TextStyle(color: AppColors.textGrey))),
          ]),
        ),
      );
}

/// Boutons d'appel des seuls numéros d'urgence vérifiés (fournis par le serveur).
class NumerosUrgence extends StatelessWidget {
  final List<NumeroUrgence> numeros;
  final bool sombre;
  const NumerosUrgence(this.numeros, {super.key, this.sombre = false});
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final n in numeros)
          Material(
            color: sombre ? Colors.white.withOpacity(0.12) : AppColors.white,
            shape: StadiumBorder(side: BorderSide(color: sombre ? Colors.white24 : AppColors.border)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => appeler(n.numero),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.call_rounded, size: 16, color: sombre ? Colors.white : AppColors.crimson),
                  const SizedBox(width: 6),
                  Text('${n.service} ${n.numero}', style: TextStyle(fontWeight: FontWeight.w700, color: sombre ? Colors.white : AppColors.textDark)),
                ]),
              ),
            ),
          ),
      ]);
}

Future<void> appeler(String numero) => launchUrl(Uri(scheme: 'tel', path: numero));

Future<void> itineraire(double lat, double lng) => launchUrl(
    Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'), mode: LaunchMode.externalApplication);

/// Dialogue de confirmation, avec saisie d'un motif si demandé. Retourne le motif (ou '' sans motif), null si annulé.
Future<String?> confirmer(BuildContext context, {required String titre, required String message,
    String action = 'Confirmer', String? motif, bool danger = false}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setState) => AlertDialog(
      title: Text(titre),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message),
        if (motif != null) Padding(padding: const EdgeInsets.only(top: 14), child: TextField(
          controller: ctrl, maxLength: 255, maxLines: 2, autofocus: true, onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: motif),
        )),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.crimson) : null,
          onPressed: motif != null && ctrl.text.trim().length < 3 ? null : () => Navigator.pop(c, ctrl.text.trim()),
          child: Text(action),
        ),
      ],
    )),
  );
}

class LigneInfo extends StatelessWidget {
  final String libelle;
  final String valeur;
  const LigneInfo(this.libelle, this.valeur, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 128, child: Text(libelle, style: TextStyle(color: AppColors.textGrey, fontSize: 13))),
          Expanded(child: Text(valeur, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class TuileDossier extends StatelessWidget {
  final Dossier d;
  final VoidCallback onTap;
  const TuileDossier(this.d, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => Carte(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: (d.estSos ? AppColors.crimson : AppColors.vert700).withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(d.estSos ? Icons.sos_rounded : (iconesCategories[d.typeIncident] ?? Icons.report_rounded),
                color: d.estSos ? AppColors.crimson : AppColors.vert700),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(d.reference, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: AppColors.vert700, fontSize: 13))),
              if (d.enRetard) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.schedule_rounded, size: 15, color: AppColors.warning)),
            ]),
            const SizedBox(height: 2),
            Text('${d.titre} · ${d.regionLibelle.isEmpty ? 'région inconnue' : d.regionLibelle}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(ilYa(d.creation), style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ])),
          const SizedBox(width: 8),
          BadgeStatut(d.statut),
        ]),
      );
}
