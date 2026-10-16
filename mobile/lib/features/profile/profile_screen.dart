import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // En-tête profil
            Container(
              width: double.infinity,
              color: AppColors.danger,
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.white.withOpacity(0.2),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Consumer<AuthProvider>(
                    builder: (_, auth, __) => Column(
                      children: [
                        Text(
                          auth.userName,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          auth.userEmail,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Citoyen',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Menu
            _MenuItem(
              icon: Icons.warning_amber_rounded,
              label: 'Mes alertes',
              onTap: () => context.go('/incidents'),
            ),
            _MenuItem(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notifications & Alertes Push',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Divider(height: 24),
                        SwitchListTile(
                          title: const Text('Alertes d\'urgence prioritaires (SOS)'),
                          value: true,
                          activeColor: AppColors.crimson,
                          onChanged: (v) {},
                        ),
                        SwitchListTile(
                          title: const Text('Alertes météo & inondations'),
                          value: true,
                          activeColor: AppColors.crimson,
                          onChanged: (v) {},
                        ),
                        SwitchListTile(
                          title: const Text('Retours d\'intervention des secours'),
                          value: true,
                          activeColor: AppColors.crimson,
                          onChanged: (v) {},
                        ),
                      ],
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Row(
                      children: [
                        Icon(Icons.settings, color: AppColors.crimson),
                        SizedBox(width: 10),
                        Text('Paramètres SenAlert'),
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
                        child: const Text('Fermer', style: TextStyle(color: AppColors.crimson)),
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
              icon: Icons.info_outline,
              label: 'À propos',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'SenAlert',
                  applicationVersion: 'v1.0.0',
                  applicationIcon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.crimson,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset(
                      'assets/images/senalert_logo.png',
                      height: 28,
                      width: 28,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.shield, color: AppColors.white),
                    ),
                  ),
                  children: const [
                    Text(
                      'Plateforme citoyenne de gestion des urgences et d\'alerte précoce au Sénégal.\n'
                      'Permet de signaler les accidents, incendies et inondations avec géolocalisation directe.',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Déconnexion
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) context.go('/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: const Text('DÉCONNEXION'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 4,
        selectedItemColor: AppColors.crimson,
        unselectedItemColor: AppColors.textGrey,
        onTap: (i) {
          if (i == 0) context.go('/home');
          if (i == 1) context.go('/incidents');
          if (i == 2) context.go('/report');
          if (i == 3) context.go('/first-aid');
          if (i == 4) context.go('/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Incidents'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Signaler'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services_outlined), label: 'Secours'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.danger),
        title: Text(label, style: const TextStyle(fontSize: 15)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textGrey),
        onTap: onTap,
      ),
    );
  }
}
