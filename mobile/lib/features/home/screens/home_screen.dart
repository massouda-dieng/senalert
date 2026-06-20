import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SenAlert'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Carte bannière
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Signalez une urgence\nrapidement',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Votre sécurité, notre priorité',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  // Illustration
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_hospital,
                            size: 56, color: AppColors.danger),
                        const SizedBox(width: 12),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: AppColors.danger.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Icon(Icons.location_on,
                                size: 28, color: AppColors.danger),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.person, size: 56, color: AppColors.info),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Bouton signaler
            ElevatedButton(
              onPressed: () => context.go('/report'),
              child: const Text('SIGNALER UNE URGENCE'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/incidents'),
              child: const Text('VOIR LES INCIDENTS'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('CONNEXION'),
            ),
            const SizedBox(height: 24),
            // Stats
            Row(
              children: [
                _StatCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Total alertes',
                  value: '120',
                  color: AppColors.danger,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  icon: Icons.pending_actions,
                  label: 'En attente',
                  value: '40',
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'Traitées',
                  value: '80',
                  color: AppColors.success,
                ),
              ],
            ),
          ],
        ),
      ),
      // Navigation bas
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppColors.danger,
        unselectedItemColor: AppColors.textGrey,
        onTap: (i) {
          if (i == 1) context.go('/incidents');
          if (i == 2) context.go('/report');
          if (i == 3) context.go('/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Incidents'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Signaler'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.white, size: 26),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
