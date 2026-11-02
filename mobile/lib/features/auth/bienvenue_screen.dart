import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../state/configuration.dart';
import '../../ui/kit.dart';

/// Accueil avant connexion : la promesse de l'application, puis inscription ou connexion.
class BienvenueScreen extends StatelessWidget {
  const BienvenueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final numeros = context.watch<Configuration>().numeros;
    final contenu = Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text('Ensemble, protégeons des vies', style: titre(31)),
        const SizedBox(height: 10),
        Text('Un SOS ou un signalement part vers le service de votre zone, et vous suivez chaque étape.', style: TextStyle(color: AppColors.textGrey, fontSize: 15.5, height: 1.4)),
        const SizedBox(height: 22),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.marine800, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56)),
          onPressed: () => context.push('/inscription'), child: const Text('Créer mon compte'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: () => context.push('/connexion'), child: const Text('J’ai déjà un compte'),
        ),
        const SizedBox(height: 14),
        if (numeros.isNotEmpty) Center(child: NumerosUrgence(numeros)),
        Center(child: TextButton(onPressed: () => context.push('/secours'), child: const Text('Premiers secours, sans compte'))),
      ]),
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(builder: (context, c) {
        // Sur un écran bas (paysage), la photo cède la place aux actions.
        if (c.maxHeight < 620) return SafeArea(child: SingleChildScrollView(child: contenu));
        return Column(children: [
          const Expanded(child: _Embleme()),
          SafeArea(top: false, child: contenu),
        ]);
      }),
    );
  }
}

/// Visuel d'accueil : le logo au centre d'anneaux d'alerte, sur le dégradé de la marque.
class _Embleme extends StatelessWidget {
  const _Embleme();

  static Widget _anneau(double taille, double opacite) => Container(
        width: taille, height: taille,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(opacite), width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.marine950, AppColors.marine800, AppColors.marine600])),
        child: SafeArea(bottom: false, child: Stack(alignment: Alignment.center, children: [
          _anneau(330, 0.06),
          _anneau(245, 0.10),
          _anneau(165, 0.16),
          Container(
            width: 108, height: 108, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 30, offset: const Offset(0, 12))]),
            child: Image.asset('assets/images/senalert_icone.png', errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 60, color: AppColors.marine800)),
          ),
          Positioned(top: 18, left: 0, right: 0, child: Column(children: [
            Text('SenAlert', style: titre(22, couleur: Colors.white)),
            const SizedBox(height: 2),
            Text('Urgences au Sénégal', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, letterSpacing: 0.4)),
          ])),
          const Positioned(bottom: 20, left: 16, right: 16, child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            _Atout(Icons.touch_app_rounded, 'SOS en un geste'),
            _Atout(Icons.route_rounded, 'Suivi en direct'),
            _Atout(Icons.verified_user_rounded, 'Services officiels'),
          ])),
        ])),
      ),
    );
  }
}

class _Atout extends StatelessWidget {
  final IconData icone;
  final String texte;
  const _Atout(this.icone, this.texte);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withOpacity(0.18))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(texte, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );
}
