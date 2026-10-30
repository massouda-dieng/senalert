import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../state/configuration.dart';
import '../../ui/kit.dart';
import '../../ui/photo.dart';

/// Présentation avant connexion : trois écrans illustrés puis inscription / connexion.
class BienvenueScreen extends StatefulWidget {
  const BienvenueScreen({super.key});
  @override
  State<BienvenueScreen> createState() => _BienvenueScreenState();
}

class _BienvenueScreenState extends State<BienvenueScreen> {
  final _pages = PageController();
  int _index = 0;
  static const _diapos = [
    ('dakar-coucher-soleil', 'Ensemble, protégeons nos quartiers', 'Signalez une urgence en quelques secondes, partout au Sénégal.'),
    ('pompiers-bnsp', 'Les secours au bon endroit', 'Votre signalement arrive au service compétent de votre zone, avec votre position.'),
    ('croix-rouge-agent', 'Restez informé', 'Suivez chaque étape de l’intervention et recevez les alertes de votre région.'),
  ];

  @override
  Widget build(BuildContext context) {
    final numeros = context.watch<Configuration>().numeros;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        PageView.builder(
          controller: _pages,
          itemCount: _diapos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => PhotoIllustration(_diapos[i].$1, superposition: const DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x1A000000), Color(0xB3000000), Color(0xF2000000)], stops: [0, 0.55, 1])),
          )),
        ),
        // Bande tricolore
        const Positioned(top: 0, left: 0, right: 0, child: SafeArea(bottom: false, child: SizedBox(height: 4, child: Row(children: [
          Expanded(child: ColoredBox(color: AppColors.vert600)), Expanded(child: ColoredBox(color: AppColors.jaune)), Expanded(child: ColoredBox(color: AppColors.crimson)),
        ])))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Image.asset('assets/images/senalert_logo.png', width: 36, height: 36, errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: Colors.white)),
                const SizedBox(width: 8),
                Text('SenAlert', style: titre(22, couleur: Colors.white)),
              ]),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(key: ValueKey(_index), crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_diapos[_index].$2, style: titre(32, couleur: Colors.white)),
                  const SizedBox(height: 10),
                  Text(_diapos[_index].$3, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.4)),
                ]),
              ),
              const SizedBox(height: 20),
              Row(children: [
                for (var i = 0; i < _diapos.length; i++)
                  AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.only(right: 6), height: 6, width: i == _index ? 26 : 8,
                      decoration: BoxDecoration(color: i == _index ? AppColors.jaune : Colors.white38, borderRadius: BorderRadius.circular(4))),
              ]),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.vert600, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56)),
                onPressed: () => context.push('/inscription'), child: const Text('Créer mon compte'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), minimumSize: const Size.fromHeight(56)),
                onPressed: () => context.push('/connexion'), child: const Text('J’ai déjà un compte'),
              ),
              const SizedBox(height: 10),
              Center(child: TextButton.icon(onPressed: () => context.push('/secours'), icon: const Icon(Icons.healing, color: Colors.white70),
                  label: const Text('Premiers secours (sans compte)', style: TextStyle(color: Colors.white70)))),
              if (numeros.isNotEmpty) NumerosUrgence(numeros, sombre: true),
            ]),
          ),
        ),
      ]),
    );
  }
}
