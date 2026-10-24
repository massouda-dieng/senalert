import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final initials = auth.userName.isEmpty ? '?' : auth.userName.substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // En-tête profil
          SaNightBackdrop(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                child: Column(children: [
                  Row(children: [
                    SaIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Retour',
                      onTap: () => context.go('/home'),
                    ),
                    const SizedBox(width: 12),
                    Text('Mon profil', style: SaText.display(19, color: Colors.white)),
                  ]),
                  const SizedBox(height: 18),
                  SaFadeSlide(
                    child: Container(
                      width: 92,
                      height: 92,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.orangeGradient),
                      child: Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.navy800),
                        alignment: Alignment.center,
                        child: Text(initials, style: SaText.display(36, color: Colors.white)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(auth.userName,
                      textAlign: TextAlign.center, style: SaText.display(20, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(auth.userEmail, style: SaText.body(13, color: Colors.white.withOpacity(0.75))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(auth.isAgent ? Icons.shield_rounded : Icons.person_rounded,
                          size: 15, color: AppColors.orange),
                      const SizedBox(width: 6),
                      Text(auth.roleLabel, style: SaText.body(12.5, color: Colors.white, weight: FontWeight.w700)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SaCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(children: [
                _MenuItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Mes alertes',
                  onTap: () => context.go('/incidents'),
                ),
                _MenuItem(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 42,
                                  height: 4,
                                  decoration: BoxDecoration(
                                      color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('Notifications & alertes push', style: SaText.display(18)),
                              const SizedBox(height: 8),
                              SwitchListTile(
                                title: const Text('Alertes d\'urgence prioritaires (SOS)'),
                                value: true,
                                onChanged: (v) {},
                              ),
                              SwitchListTile(
                                title: const Text('Alertes météo & inondations'),
                                value: true,
                                onChanged: (v) {},
                              ),
                              SwitchListTile(
                                title: const Text('Retours d\'intervention des secours'),
                                value: true,
                                onChanged: (v) {},
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.settings_outlined,
                  label: 'Paramètres',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          children: [
                            const Icon(Icons.settings_outlined, color: AppColors.navy800),
                            const SizedBox(width: 10),
                            Text('Paramètres SenAlert', style: SaText.display(17)),
                          ],
                        ),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• Langue : Français (Wolof disponible)'),
                            SizedBox(height: 8),
                            Text('• Géolocalisation : Haute précision (Actif)'),
                            SizedBox(height: 8),
                            Text('• Mode d\'urgence : SOS 1-Tap (3s)'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Fermer'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _MenuItem(
                  icon: Icons.shield_outlined,
                  label: 'Espace Police & Forces de Secours',
                  onTap: () => context.go('/agent-dashboard'),
                ),
                _MenuItem(
                  icon: Icons.info_outline_rounded,
                  label: 'À propos',
                  last: true,
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'SenAlert',
                      applicationVersion: 'v1.0.0',
                      applicationIcon: const SaLogo(size: 40),
                      children: const [
                        Text(
                          'Plateforme citoyenne de gestion des urgences et d\'alerte précoce au Sénégal.\n'
                          'Permet de signaler les accidents, incendies et inondations avec géolocalisation directe.',
                        ),
                      ],
                    );
                  },
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SaCard(
              padding: EdgeInsets.zero,
              onTap: () async {
                await context.read<AuthProvider>().logout();
                if (context.mounted) context.go('/login');
              },
              child: SizedBox(
                height: 56,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.logout_rounded, color: AppColors.crimson),
                  const SizedBox(width: 8),
                  Text('Se déconnecter', style: SaText.body(15, color: AppColors.crimson, weight: FontWeight.w800)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: auth.isAgent ? null : const SaBottomNav(currentIndex: 3),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool last;

  const _MenuItem({required this.icon, required this.label, required this.onTap, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        minVerticalPadding: 14,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.blue50, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.navy800, size: 21),
        ),
        title: Text(label, style: SaText.body(14.5, color: AppColors.textDark, weight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: onTap,
      ),
      if (!last) const Divider(height: 1, indent: 72, endIndent: 16, color: AppColors.border),
    ]);
  }
}
