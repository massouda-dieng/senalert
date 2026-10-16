import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/core/utils/validators.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';
import 'package:senalert_mobile/shared/widgets/custom_button.dart';
import 'package:senalert_mobile/shared/widgets/custom_text_field.dart';

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
    final ok = await context.read<AuthProvider>().login(name, pass);
    if (ok && mounted) {
      if (_isAgent) {
        context.go('/agent-dashboard');
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => context.go('/onboarding'),
        ),
        title: const Text(
          'Connexion',
          style: TextStyle(
            color: AppColors.crimson,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Official Logo
              Container(
                width: 90,
                height: 90,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkSlate,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.crimson.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: Image.asset(
                  'assets/images/senalert_logo.png',
                  errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: AppColors.white, size: 45),
                ),
              ),

              const SizedBox(height: 20),

              // Role Selector
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isAgent = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isAgent ? AppColors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !_isAgent
                                ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                                : [],
                          ),
                          child: Text(
                            '👤 Citoyen',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: !_isAgent ? FontWeight.bold : FontWeight.normal,
                              color: !_isAgent ? AppColors.crimson : AppColors.textGrey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isAgent = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isAgent ? AppColors.darkSlate : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _isAgent
                                ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]
                                : [],
                          ),
                          child: Text(
                            '👮‍♂️ Agent / Secours',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: _isAgent ? FontWeight.bold : FontWeight.normal,
                              color: _isAgent ? AppColors.white : AppColors.textGrey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Full Name input
              CustomTextField(
                hint: _isAgent ? 'Nom complet ou Identifiant Agent' : 'Nom complet',
                prefixIcon: Icons.person_outline_rounded,
                controller: _nameCtrl,
                validator: (v) => Validators.required(v, 'Nom complet'),
              ),

              const SizedBox(height: 14),

              // Password input
              CustomTextField(
                hint: 'Mot de passe',
                prefixIcon: Icons.lock_outline_rounded,
                controller: _passCtrl,
                isPassword: true,
                validator: Validators.password,
              ),

              const SizedBox(height: 16),

              // Error notification
              Consumer<AuthProvider>(builder: (_, auth, __) {
                if (auth.error == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    auth.error!,
                    style: const TextStyle(color: AppColors.crimson, fontSize: 13),
                  ),
                );
              }),

              // Submit Button
              Consumer<AuthProvider>(
                builder: (_, auth, __) => CustomButton(
                  text: 'SE CONNECTER',
                  onPressed: _login,
                  isLoading: auth.isLoading,
                ),
              ),

              const SizedBox(height: 24),

              // Register Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Nouveau sur SenAlert ? ',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/register'),
                    child: const Text(
                      'S\'inscrire',
                      style: TextStyle(
                        color: AppColors.crimson,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
