import 'package:flutter/material.dart';
import '../constants.dart';
import 'home_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ProfileItem(icon: Icons.notifications_outlined, label: 'Mes alertes', onTap: () {}),
      _ProfileItem(icon: Icons.notifications_active_outlined, label: 'Notifications', onTap: () {}),
      _ProfileItem(icon: Icons.settings_outlined, label: 'Paramètres', onTap: () {}),
      _ProfileItem(icon: Icons.info_outline, label: 'À propos', onTap: () {}),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              color: Colors.white,
              child: Column(
                children: [
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.lightGrey,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border, width: 2),
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: AppColors.grey,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cheikh Ahmed',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'cheikh.ahmed@email.com',
                    style: TextStyle(fontSize: 13, color: AppColors.grey),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.info.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Citoyen',
                      style: TextStyle(
                        color: AppColors.info,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Menu items
            Container(
              color: Colors.white,
              child: Column(
                children: items
                    .map((item) => Column(
                          children: [
                            ListTile(
                              leading: Icon(item.icon, color: AppColors.dark, size: 22),
                              title: Text(
                                item.label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.dark,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppColors.grey,
                              ),
                              onTap: item.onTap,
                            ),
                            if (item != items.last)
                              const Divider(height: 1, indent: 56),
                          ],
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            // Logout button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (_) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text('DÉCONNEXION'),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _ProfileItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ProfileItem({required this.icon, required this.label, required this.onTap});
}
