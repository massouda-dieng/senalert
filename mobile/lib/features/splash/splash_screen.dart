import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _scale = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
    _route();
  }

  Future<void> _route() async {
    final auth = context.read<AuthProvider>();
    await Future.wait([
      auth.checkAuth(),
      Future.delayed(const Duration(seconds: 3)),
    ]);
    if (!mounted) return;
    if (!auth.isAuthenticated) {
      context.go('/onboarding');
    } else {
      context.go(auth.isAgent ? '/agent-dashboard' : '/home');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SaNightBackdrop(
        child: Stack(
          children: [
            const Align(
              alignment: Alignment.bottomCenter,
              child: SaDakarSkyline(height: 190, color: Color(0x2E9DB7FF)),
            ),
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 128,
                          height: 128,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(color: Colors.white.withOpacity(0.14)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.blue500.withOpacity(0.45),
                                blurRadius: 48,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const SaLogo(size: 76),
                        ),
                        const SizedBox(height: 26),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(text: 'Sen', style: SaText.display(40, color: Colors.white)),
                              TextSpan(text: 'Alert', style: SaText.display(40, color: AppColors.orange)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Ensemble pour un Sénégal\nplus sûr et plus solidaire',
                          textAlign: TextAlign.center,
                          style: SaText.body(14.5, color: Colors.white.withOpacity(0.78)),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              backgroundColor: Colors.white.withOpacity(0.12),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chargement…',
                          style: SaText.body(12, color: Colors.white.withOpacity(0.6)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
