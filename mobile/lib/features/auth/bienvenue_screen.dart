import 'dart:async';

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
  Timer? _defilement;
  static const _diapos = [
    ('pompiers-bnsp', 'Un SOS, et les secours sont prévenus', 'Votre position part en un geste vers les agents de votre zone.'),
    ('ambulance-pompiers', 'Voyez les secours arriver', 'Le bon service reçoit votre alerte et vous suivez son approche sur la carte.'),
    ('croix-rouge-agent', 'Suivi jusqu’à la fin', 'Chaque étape est notifiée, puis vous notez l’intervention.'),
  ];

  @override
  void initState() {
    super.initState();
    // Défilement automatique, arrêté dès que l'utilisateur fait glisser une diapo.
    _defilement = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pages.hasClients) return;
      if (MediaQuery.of(context).disableAnimations) { _defilement?.cancel(); return; }
      _pages.animateToPage((_index + 1) % _diapos.length, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _defilement?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final numeros = context.watch<Configuration>().numeros;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Listener(onPointerDown: (_) => _defilement?.cancel(), child: PageView.builder(
          controller: _pages,
          itemCount: _diapos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => PhotoIllustration(_diapos[i].$1, superposition: const DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x4D000000), Color(0xE6000000), Color(0xFA000000)], stops: [0, 0.3, 0.62, 1])),
          )),
        )),
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
                  // L'aperçu de la fonction est masqué sur les petits écrans, où la place manque.
                  if (MediaQuery.of(context).size.height >= 720) Padding(padding: const EdgeInsets.only(bottom: 20), child: switch (_index) {
                    0 => const _ApercuSos(),
                    1 => const _ApercuEnRoute(),
                    _ => const _ApercuSuivi(),
                  }),
                  Text(_diapos[_index].$2, style: titre(30, couleur: Colors.white)),
                  const SizedBox(height: 8),
                  Text(_diapos[_index].$3, style: const TextStyle(color: Colors.white70, fontSize: 15.5, height: 1.4)),
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

/// Fond commun des aperçus : ce sont des illustrations de l'application, pas des données réelles.
class _Vignette extends StatelessWidget {
  final Widget child;
  const _Vignette({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white24)),
        child: child,
      );
}

class _ApercuSos extends StatefulWidget {
  const _ApercuSos();
  @override
  State<_ApercuSos> createState() => _ApercuSosState();
}

class _ApercuSosState extends State<_ApercuSos> with SingleTickerProviderStateMixin {
  late final _pulsation = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) { _pulsation.stop(); } else if (!_pulsation.isAnimating) { _pulsation.repeat(); }
  }

  @override
  void dispose() {
    _pulsation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Vignette(child: Row(children: [
        SizedBox(width: 88, height: 88, child: AnimatedBuilder(
          animation: _pulsation,
          builder: (_, __) => Stack(alignment: Alignment.center, children: [
            Container(width: 64 + 24 * _pulsation.value, height: 64 + 24 * _pulsation.value,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.crimson.withOpacity(.45 * (1 - _pulsation.value)))),
            Container(width: 64, height: 64, alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppColors.sosGradient, border: Border.all(color: Colors.white54, width: 3)),
                child: Text('SOS', style: titre(17, couleur: Colors.white))),
          ]),
        )),
        const SizedBox(width: 12),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('5 secondes pour annuler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Position GPS jointe si vous l’autorisez', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ])),
      ]));
}

class _ApercuEnRoute extends StatelessWidget {
  const _ApercuEnRoute();
  @override
  Widget build(BuildContext context) => const _Vignette(child: Row(children: [
        CircleAvatar(radius: 22, backgroundColor: Color(0xFF1E3A8A), child: Icon(Icons.local_shipping, color: Colors.white)),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Les secours sont en route', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          SizedBox(height: 2),
          Text('Exemple : à environ 1,2 km du lieu', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ])),
      ]));
}

class _ApercuSuivi extends StatelessWidget {
  const _ApercuSuivi();
  @override
  Widget build(BuildContext context) => _Vignette(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (final (i, e) in const ['Reçu', 'En cours', 'Résolu'].indexed) ...[
            if (i > 0) const Expanded(child: Divider(color: Colors.white38, thickness: 1.5, indent: 4, endIndent: 4)),
            Tooltip(message: e, child: const Icon(Icons.check_circle, color: AppColors.jaune, size: 20)),
          ],
        ]),
        const SizedBox(height: 6),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Reçu', style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text('En cours', style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text('Résolu', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
        const SizedBox(height: 10),
        const Row(children: [
          Icon(Icons.star_rounded, color: AppColors.jaune, size: 20), Icon(Icons.star_rounded, color: AppColors.jaune, size: 20), Icon(Icons.star_rounded, color: AppColors.jaune, size: 20),
          Icon(Icons.star_rounded, color: AppColors.jaune, size: 20), Icon(Icons.star_rounded, color: AppColors.jaune, size: 20),
          SizedBox(width: 8), Text('Votre avis compte', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ]));
}
