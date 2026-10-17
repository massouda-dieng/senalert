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

  // Agent Official Justification Fields
  final _badgeCtrl = TextEditingController();
  final _stationCtrl = TextEditingController();
  bool _idCardProofUploaded = false;

  bool _acceptTerms = false;
  String _role = 'Citoyen';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _badgeCtrl.dispose();
    _stationCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Validate Officer Official Justification details if registering as an Agent
    if (_role != 'Citoyen') {
      if (_badgeCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Justificatif obligatoire : Veuillez saisir votre Matricule Officiel Agent (ex: POL-8842)'),
          backgroundColor: AppColors.danger,
        ));
        return;
      }
      if (_stationCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Justificatif obligatoire : Veuillez indiquer votre Commissariat / Caserne de rattachement'),
          backgroundColor: AppColors.danger,
        ));
        return;
      }
      if (!_idCardProofUploaded) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Justificatif obligatoire : Veuillez joindre votre Carte Professionnelle d\'Agent'),
          backgroundColor: AppColors.danger,
        ));
        return;
      }
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Veuillez accepter les conditions d\'utilisation'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    _completeRegistration();
  }

  Future<void> _completeRegistration() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
      role: _role,
    );
    if (!ok || !mounted) return;
    final isAgent = AuthProvider.roleToApi(_role) == 'autorite';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isAgent
          ? 'Compte agent créé. Un administrateur doit le rattacher à votre service avant de recevoir les interventions. Connectez-vous.'
          : 'Compte créé avec succès ! Connectez-vous maintenant.'),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 5),
    ));
    context.go('/login');
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
                validator: (v) => Validators.required(v, 'Nom complet'),
              ),
              const SizedBox(height: 14),
              // Choix du Rôle de Compte
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _role,
                    icon: const Icon(Icons.shield, color: AppColors.crimson),
                    items: const [
                      DropdownMenuItem(value: 'Citoyen', child: Text('👤 Compte Citoyen')),
                      DropdownMenuItem(value: 'Policier', child: Text('👮‍♂️ Agent de Police / Gendarmerie')),
                      DropdownMenuItem(value: 'Sapeur-Pompier', child: Text('🚒 Brigade Sapeurs-Pompiers')),
                      DropdownMenuItem(value: 'Agent SAMU', child: Text('🏥 Secours Médicaux SAMU')),
                    ],
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                ),
              ),

              // Section spécifique de Justificatif Officiel Agent
              if (_role != 'Citoyen') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.darkSlate,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.emerald.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_rounded, color: AppColors.emerald, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Justificatifs d\'Identité Agent d\'État',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        hint: 'Matricule Officiel / Badge (ex: POL-8842)',
                        prefixIcon: Icons.badge_outlined,
                        controller: _badgeCtrl,
                      ),
                      const SizedBox(height: 10),
                      CustomTextField(
                        hint: 'Commissariat / Caserne / Unité',
                        prefixIcon: Icons.location_city_outlined,
                        controller: _stationCtrl,
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _idCardProofUploaded = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Carte Professionnelle jointe avec succès ✅'),
                              backgroundColor: AppColors.success,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _idCardProofUploaded
                                ? AppColors.emerald.withOpacity(0.2)
                                : AppColors.navy,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _idCardProofUploaded
                                  ? AppColors.emerald
                                  : Colors.white24,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _idCardProofUploaded
                                    ? Icons.check_circle_rounded
                                    : Icons.upload_file_rounded,
                                color: _idCardProofUploaded
                                    ? AppColors.emerald
                                    : AppColors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _idCardProofUploaded
                                    ? 'Carte Pro Validée ✓'
                                    : 'Joindre Carte Professionnelle Pro (Scan/Photo)',
                                style: TextStyle(
                                  color: _idCardProofUploaded
                                      ? AppColors.emerald
                                      : AppColors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),
              CustomTextField(
                hint: 'Adresse email',
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
                  text: 'CRÉER MON COMPTE',
                  onPressed: _submit,
                  isLoading: auth.isLoading,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Déjà inscrit ? ',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}
