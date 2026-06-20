import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/core/utils/validators.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';
import 'package:senalert_mobile/shared/widgets/custom_button.dart';
import 'package:senalert_mobile/shared/widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _acceptTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez accepter les conditions d\'utilisation'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    final ok = await context.read<AuthProvider>().register(
          _nameCtrl.text.trim(),
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );
    if (ok && mounted) context.go('/home');
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
          onPressed: () => context.go('/login'),
        ),
        title: const Text(
          'Inscription',
          style: TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 8),
              CustomTextField(
                hint: 'Nom complet',
                prefixIcon: Icons.person_outline,
                controller: _nameCtrl,
                validator: (v) => Validators.required(v, 'Nom'),
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Email',
                prefixIcon: Icons.email_outlined,
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Mot de passe',
                prefixIcon: Icons.lock_outline,
                controller: _passCtrl,
                isPassword: true,
                validator: Validators.password,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Confirmer mot de passe',
                prefixIcon: Icons.lock_outline,
                controller: _confirmCtrl,
                isPassword: true,
                validator: (v) =>
                    Validators.confirmPassword(v, _passCtrl.text),
              ),
              const SizedBox(height: 12),
              // Conditions
              Row(
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    activeColor: AppColors.danger,
                    onChanged: (v) =>
                        setState(() => _acceptTerms = v ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'J\'accepte les conditions d\'utilisation',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Erreur
              Consumer<AuthProvider>(builder: (_, auth, __) {
                if (auth.error == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(auth.error!,
                      style: const TextStyle(color: AppColors.danger)),
                );
              }),
              // Bouton
              Consumer<AuthProvider>(
                builder: (_, auth, __) => CustomButton(
                  text: 'S\'INSCRIRE',
                  onPressed: _register,
                  isLoading: auth.isLoading,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Déjà un compte ? ',
                      style: TextStyle(color: AppColors.textGrey)),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text(
                      'Se connecter',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
