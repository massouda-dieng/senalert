import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../state/configuration.dart';
import '../../ui/kit.dart';
import '../../ui/photo.dart';

/// Accueil avant connexion : la promesse de l'application, puis inscription ou connexion.
class BienvenueScreen extends StatelessWidget {
  const BienvenueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final numeros = context.watch<Configuration>().numeros;
    final contenu = Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text.rich(TextSpan(children: [
          const TextSpan(text: 'De l’alerte à l’intervention, suivez '),
          TextSpan(text: 'chaque étape', style: titre(31, couleur: AppColors.vert600)),
          const TextSpan(text: '.'),
        ]), style: titre(31)),
        const SizedBox(height: 10),
        Text('Un SOS ou un signalement part vers le service de votre zone.', style: TextStyle(color: AppColors.textGrey, fontSize: 15.5, height: 1.4)),
        const SizedBox(height: 22),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.vert800, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56)),
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
          Expanded(child: ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            child: Stack(fit: StackFit.expand, children: [
              const PhotoIllustration('ambulance-pompiers', alignement: Alignment(0.3, -0.7)),
              Align(alignment: Alignment.topLeft, child: SafeArea(child: Padding(padding: const EdgeInsets.all(14), child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Padding(padding: const EdgeInsets.fromLTRB(6, 6, 14, 6), child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset('assets/images/senalert_icone.png', width: 30, height: 30, errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: AppColors.vert600)),
                  const SizedBox(width: 8),
                  Text('SenAlert', style: titre(18, couleur: AppColors.vert800)),
                ])),
              )))),
            ]),
          )),
          SafeArea(top: false, child: contenu),
        ]);
      }),
    );
  }
}
