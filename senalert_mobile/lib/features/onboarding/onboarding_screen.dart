import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';

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
      'icon': Icons.warning_amber_rounded,
      'color': AppColors.danger,
      'title': 'Signalez une urgence',
      'sub': 'Alertez rapidement les secours\net votre communauté en cas de danger.',
    },
    {
      'icon': Icons.location_on,
      'color': AppColors.info,
      'title': 'Localisation en temps réel',
      'sub': 'Votre position GPS est automatiquement\ndétectée pour des secours rapides.',
    },
    {
      'icon': Icons.shield,
      'color': AppColors.success,
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
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Bouton passer
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text(
                    'Passer',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 15),
                  ),
                ),
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            color: (s['color'] as Color).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            s['icon'] as IconData,
                            size: 75,
                            color: s['color'] as Color,
                          ),
                        ),
                        const SizedBox(height: 44),
                        Text(
                          s['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s['sub'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.textGrey,
                            height: 1.6,
                          ),
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
                    color: _page == i ? AppColors.danger : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
            // Boutons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  ElevatedButton(
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
                    child: Text(
                      _page < _slides.length - 1 ? 'SUIVANT' : 'COMMENCER',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_page == _slides.length - 1)
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text(
                        'Créer un compte',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
