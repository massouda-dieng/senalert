import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/core/utils/validators.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';
import 'package:senalert_mobile/shared/widgets/custom_button.dart';
import 'package:senalert_mobile/shared/widgets/custom_text_field.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isAgent = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    final pass = _passCtrl.text;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(name, pass);
    if (!ok || !mounted) return;
    // Le rôle vient du compte (backend), pas de l'onglet choisi.
    if (_isAgent != auth.isAgent) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ce compte est un compte ${auth.roleLabel}.'),
      ));
    }
    context.go(auth.isAgent ? '/agent-dashboard' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SaNightBackdrop(
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Column(
                  children: [
                    // ----- Hero bleu nuit -----
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Row(children: [
                        SaIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: 'Retour',
                          onTap: () => context.go('/onboarding'),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    const SaFadeSlide(child: SaLogo(size: 64)),
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(text: 'Sen', style: SaText.display(32, color: Colors.white)),
                        TextSpan(text: 'Alert', style: SaText.display(32, color: AppColors.orange)),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ensemble pour un Sénégal plus sûr',
                      style: SaText.body(13.5, color: Colors.white.withOpacity(0.75)),
                    ),
                    const SaDakarSkyline(height: 92, color: Color(0x299DB7FF)),

                    // ----- Carte formulaire -----
                    SaFadeSlide(
                      index: 1,
                      offsetY: 40,
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(minHeight: c.maxHeight * 0.55),
                        padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Connexion', style: SaText.display(24)),
                              const SizedBox(height: 4),
                              Text('Accédez à votre espace SenAlert',
                                  style: SaText.body(13.5)),
                              const SizedBox(height: 20),

                              // Profil attendu (le rôle réel vient du compte)
                              SaSegmentedTabs<bool>(
                                options: const [(false, 'Citoyen'), (true, 'Agent de secours')],
                                value: _isAgent,
                                onChanged: (v) => setState(() => _isAgent = v),
                              ),
                              const SizedBox(height: 18),

                              CustomTextField(
                                hint: 'Adresse email',
                                prefixIcon: Icons.mail_outline_rounded,
                                controller: _nameCtrl,
                                keyboardType: TextInputType.emailAddress,
                                validator: Validators.email,
                              ),
                              const SizedBox(height: 14),
                              CustomTextField(
                                hint: 'Mot de passe',
                                prefixIcon: Icons.lock_outline_rounded,
                                controller: _passCtrl,
                                isPassword: true,
                                validator: Validators.password,
                              ),
                              const SizedBox(height: 16),

                              Consumer<AuthProvider>(builder: (_, auth, __) {
                                if (auth.error == null) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: SaInfoBanner(
                                    auth.error!,
                                    icon: Icons.error_outline_rounded,
                                    color: AppColors.crimson,
                                  ),
                                );
                              }),

                              Consumer<AuthProvider>(
                                builder: (_, auth, __) => CustomButton(
                                  text: 'Se connecter',
                                  icon: Icons.login_rounded,
                                  onPressed: _login,
                                  isLoading: auth.isLoading,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Center(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text('Nouveau sur SenAlert ? ', style: SaText.body(14)),
                                    TextButton(
                                      onPressed: () => context.go('/register'),
                                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                                      child: Text('S\'inscrire',
                                          style: SaText.body(14,
                                              color: AppColors.orangeDeep, weight: FontWeight.w800)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const _SenegalFlag(),
                                  const SizedBox(width: 8),
                                  Text('Sénégal', style: SaText.body(12.5, weight: FontWeight.w600)),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Petit drapeau du Sénégal dessiné (vert / jaune / rouge + étoile verte).
class _SenegalFlag extends StatelessWidget {
  const _SenegalFlag();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: 24,
        height: 16,
        child: Row(children: [
          Expanded(child: Container(color: const Color(0xFF00853F))),
          Expanded(
            child: Container(
              color: const Color(0xFFFDEF42),
              alignment: Alignment.center,
              child: const Icon(Icons.star_rounded, size: 8, color: Color(0xFF00853F)),
            ),
          ),
          Expanded(child: Container(color: const Color(0xFFE31B23))),
        ]),
      ),
    );
  }
}
