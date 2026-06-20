import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/alert_model.dart';
import 'alert_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.dashboard_outlined, label: 'Tableau de bord'),
    _NavItem(icon: Icons.notifications_outlined, label: 'Alertes'),
    _NavItem(icon: Icons.build_outlined, label: 'Interventions'),
    _NavItem(icon: Icons.people_outline, label: 'Utilisateurs'),
    _NavItem(icon: Icons.bar_chart_outlined, label: 'Statistiques'),
    _NavItem(icon: Icons.settings_outlined, label: 'Paramètres'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF16213E),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 200,
            color: const Color(0xFF16213E),
            child: Column(
              children: [
                const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active, color: Colors.white, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'SenAlert',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(color: Colors.white12),
                Expanded(
                  child: ListView.builder(
                    itemCount: _navItems.length,
                    itemBuilder: (_, idx) {
                      final item = _navItems[idx];
                      final isSelected = _selectedIndex == idx;
                      return InkWell(
                        onTap: () => setState(() => _selectedIndex = idx),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(item.icon, color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                item.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.white12),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        Icon(Icons.logout, color: Colors.white54, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Déconnexion',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Container(
              color: AppColors.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: const SafeArea(
                      child: Row(
                        children: [
                          Text(
                            'Tableau de bord',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.dark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Stats cards
                          Row(
                            children: [
                              _StatCard(
                                label: 'Total alertes',
                                value: '120',
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 12),
                              _StatCard(
                                label: 'En attente',
                                value: '40',
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 12),
                              _StatCard(
                                label: 'Traitées',
                                value: '80',
                                color: AppColors.success,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Recent alerts
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Alertes récentes',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.dark,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text(
                                  'Voir tout',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Table header
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightGrey,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(flex: 2, child: Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.grey))),
                                      Expanded(flex: 2, child: Text('Lieu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.grey))),
                                      Expanded(flex: 2, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.grey))),
                                      Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.grey))),
                                    ],
                                  ),
                                ),
                                ...sampleAlerts.map(
                                  (alert) => InkWell(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => AlertDetailScreen(alert: alert)),
                                    ),
                                    child: _AdminAlertRow(alert: alert),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminAlertRow extends StatelessWidget {
  final AlertModel alert;
  const _AdminAlertRow({required this.alert});

  Color get _statusColor {
    switch (alert.status) {
      case 'pending': return AppColors.warning;
      case 'in_progress': return AppColors.info;
      case 'resolved': return AppColors.success;
      default: return AppColors.grey;
    }
  }

  IconData get _typeIcon {
    switch (alert.type) {
      case 'Accident': return Icons.car_crash;
      case 'Incendie': return Icons.local_fire_department;
      case 'Inondation': return Icons.water;
      case 'Urgence médicale': return Icons.medical_services;
      default: return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(_typeIcon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(alert.type, style: const TextStyle(fontSize: 13, color: AppColors.dark)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(alert.location, style: const TextStyle(fontSize: 13, color: AppColors.grey)),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                alert.statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _statusColor,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              alert.date.split(' à').first,
              style: const TextStyle(fontSize: 12, color: AppColors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
