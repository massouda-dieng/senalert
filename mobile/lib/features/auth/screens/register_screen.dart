import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/core/utils/validators.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';
import 'package:senalert_mobile/shared/widgets/custom_button.dart';
import 'package:senalert_mobile/shared/widgets/custom_text_field.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

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

  static const _roles = [
    ('Citoyen', 'Citoyen', Icons.person_rounded),
    ('Policier', 'Police / Gendarmerie', Icons.local_police_rounded),
    ('Sapeur-Pompier', 'Sapeurs-Pompiers', Icons.fire_truck_rounded),
    ('Agent SAMU', 'Secours médicaux SAMU', Icons.medical_services_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // Ambiance Dakar en bas de page (comme la maquette)
          const Align(
            alignment: Alignment.bottomCenter,
            child: IgnorePointer(child: SaDakarSkyline(height: 110, color: Color(0x1A12307A))),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SaIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Retour',
                      light: true,
                      onTap: () => context.go('/login'),
                    ),
                    const SizedBox(height: 18),
                    SaFadeSlide(child: Text('Créer un compte', style: SaText.display(28))),
                    const SizedBox(height: 6),
                    SaFadeSlide(
                      index: 1,
                      child: Text.rich(TextSpan(
                        style: SaText.body(14),
                        children: [
                          const TextSpan(text: 'Rejoignez '),
                          TextSpan(
                              text: 'SenAlert',
                              style: SaText.body(14, color: AppColors.navy800, weight: FontWeight.w800)),
                          const TextSpan(text: ' et contribuez à un Sénégal plus sûr.'),
                        ],
                      )),
                    ),
                    const SizedBox(height: 22),

                    // Type de compte
                    Text('Type de compte', style: SaText.body(13, color: AppColors.textDark, weight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.6,
                      children: _roles.map((r) {
                        final sel = _role == r.$1;
                        return Semantics(
                          selected: sel,
                          button: true,
                          child: GestureDetector(
                            onTap: () => setState(() => _role = r.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.blue50 : AppColors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: sel ? AppColors.blue600 : AppColors.border, width: sel ? 1.6 : 1),
                              ),
                              child: Row(children: [
                                Icon(r.$3, size: 20, color: sel ? AppColors.blue600 : AppColors.textGrey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(r.$2,
                                      maxLines: 2,
                                      style: SaText.body(12,
                                          color: sel ? AppColors.navy800 : AppColors.textDark,
                                          weight: sel ? FontWeight.w700 : FontWeight.w600)),
                                ),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    CustomTextField(
                      hint: 'Nom complet',
                      prefixIcon: Icons.person_outline_rounded,
                      controller: _nameCtrl,
                      validator: (v) => Validators.required(v, 'Nom complet'),
                    ),

                    // Justificatifs agent
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: _role == 'Citoyen'
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: SaNightBackdrop(
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        const Icon(Icons.verified_user_rounded, color: Color(0xFF34D399), size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text('Justificatifs d\'identité agent',
                                              style: SaText.display(14, color: Colors.white)),
                                        ),
                                      ]),
                                      const SizedBox(height: 12),
                                      CustomTextField(
                                        hint: 'Matricule officiel / Badge (ex: POL-8842)',
                                        prefixIcon: Icons.badge_outlined,
                                        controller: _badgeCtrl,
                                        onDark: true,
                                      ),
                                      const SizedBox(height: 10),
                                      CustomTextField(
                                        hint: 'Commissariat / Caserne / Unité',
                                        prefixIcon: Icons.location_city_outlined,
                                        controller: _stationCtrl,
                                        onDark: true,
                                      ),
                                      const SizedBox(height: 12),
                                      SaGlass(
                                        radius: 16,
                                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _idCardProofUploaded
                                                  ? Icons.check_circle_rounded
                                                  : Icons.upload_file_rounded,
                                              color: _idCardProofUploaded ? const Color(0xFF34D399) : Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                _idCardProofUploaded
                                                    ? 'Carte professionnelle jointe'
                                                    : 'Joindre la carte professionnelle',
                                                style: SaText.body(13,
                                                    color: _idCardProofUploaded
                                                        ? const Color(0xFF34D399)
                                                        : Colors.white,
                                                    weight: FontWeight.w700),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 14),
                    CustomTextField(
                      hint: 'Adresse email',
                      prefixIcon: Icons.mail_outline_rounded,
                      controller: _emailCtrl,
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
                    const SizedBox(height: 14),
                    CustomTextField(
                      hint: 'Confirmer le mot de passe',
                      prefixIcon: Icons.lock_outline_rounded,
                      controller: _confirmCtrl,
                      isPassword: true,
                      validator: (v) => Validators.confirmPassword(v, _passCtrl.text),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                      child: SizedBox(
                        height: 48,
                        child: Row(children: [
                          Checkbox(
                            value: _acceptTerms,
                            onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                          ),
                          Expanded(
                            child: Text('J\'accepte les conditions d\'utilisation',
                                style: SaText.body(13.5, color: AppColors.textDark)),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Consumer<AuthProvider>(builder: (_, auth, __) {
                      if (auth.error == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SaInfoBanner(auth.error!,
                            icon: Icons.error_outline_rounded, color: AppColors.crimson),
                      );
                    }),
                    Consumer<AuthProvider>(
                      builder: (_, auth, __) => CustomButton(
                        text: 'S\'inscrire',
                        icon: Icons.person_add_alt_1_rounded,
                        onPressed: _submit,
                        isLoading: auth.isLoading,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Vous avez déjà un compte ? ', style: SaText.body(14)),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                            child: Text('Se connecter',
                                style: SaText.body(14, color: AppColors.navy800, weight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
