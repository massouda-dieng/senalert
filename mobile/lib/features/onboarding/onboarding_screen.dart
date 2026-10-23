import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _page = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.campaign_rounded,
      'color': AppColors.orange,
      'title': 'Signalez une urgence',
      'sub': 'Alertez rapidement les secours\net votre communauté en cas de danger.',
    },
    {
      'icon': Icons.my_location_rounded,
      'color': const Color(0xFF60A5FA),
      'title': 'Localisation en temps réel',
      'sub': 'Votre position GPS est automatiquement\ndétectée pour des secours rapides.',
    },
    {
      'icon': Icons.shield_rounded,
      'color': const Color(0xFF34D399),
      'title': 'Ensemble, plus en sécurité',
      'sub': 'Rejoignez la communauté SenAlert\net protégez votre quartier.',
    },
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SaNightBackdrop(
        child: Stack(
          children: [
            const Align(
              alignment: Alignment.bottomCenter,
              child: SaDakarSkyline(height: 150, color: Color(0x1F9DB7FF)),
            ),
            SafeArea(
              child: Column(
                children: [
                  // En-tête : logo + Passer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                    child: Row(
                      children: [
                        const SaLogo(size: 30),
                        const SizedBox(width: 8),
                        Text('SenAlert', style: SaText.display(17, color: Colors.white)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.go('/login'),
                          style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                          child: Text('Passer',
                              style: SaText.body(15, color: Colors.white.withOpacity(0.8), weight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  // Pages
                  Expanded(
                    child: PageView.builder(
                      controller: _ctrl,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemCount: _slides.length,
                      itemBuilder: (_, i) {
                        final s = _slides[i];
                        final color = s['color'] as Color;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                key: ValueKey(i),
                                tween: Tween(begin: 0.85, end: 1),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutBack,
                                builder: (_, v, c) => Transform.scale(scale: v, child: c),
                                child: Container(
                                  width: 176,
                                  height: 176,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [color.withOpacity(0.35), color.withOpacity(0.02)],
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: SaGlass(
                                    radius: 40,
                                    padding: const EdgeInsets.all(28),
                                    child: Icon(s['icon'] as IconData, size: 60, color: color),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 44),
                              Text(
                                s['title'] as String,
                                textAlign: TextAlign.center,
                                style: SaText.display(27, color: Colors.white),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                s['sub'] as String,
                                textAlign: TextAlign.center,
                                style: SaText.body(15, color: Colors.white.withOpacity(0.75)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Indicateurs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _page == i ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _page == i ? AppColors.orange : Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),
                  // Boutons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.navy900,
                            ),
                            onPressed: () {
                              if (_page < _slides.length - 1) {
                                _ctrl.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              } else {
                                context.go('/login');
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(last ? 'Commencer' : 'Suivant'),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: last ? 1 : 0,
                          child: TextButton(
                            onPressed: last ? () => context.go('/register') : null,
                            style: TextButton.styleFrom(minimumSize: const Size(160, 48)),
                            child: Text(
                              'Créer un compte',
                              style: SaText.body(15, color: const Color(0xFFFDBA74), weight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
