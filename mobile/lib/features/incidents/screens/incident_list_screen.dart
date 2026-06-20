import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/incidents/models/incident_model.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';

class IncidentListScreen extends StatefulWidget {
  const IncidentListScreen({super.key});

  @override
  State<IncidentListScreen> createState() => _IncidentListScreenState();
}

class _IncidentListScreenState extends State<IncidentListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<IncidentProvider>().fetchIncidents());
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'en_attente': return AppColors.warning;
      case 'en_cours':   return AppColors.info;
      case 'traite':     return AppColors.success;
      default:           return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Carte des incidents'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {},
        ),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: Consumer<IncidentProvider>(builder: (_, p, __) {
        if (p.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.danger));
        }
        return Column(
          children: [
            // Légende
            Container(
              color: AppColors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _Legend(color: AppColors.danger,  label: 'Accident'),
                  _Legend(color: AppColors.info,    label: 'Inondation'),
                  _Legend(color: AppColors.warning, label: 'Incendie'),
                  _Legend(color: AppColors.success, label: 'Urgence méd.'),
                ],
              ),
            ),
            // Liste
            Expanded(
              child: p.incidents.isEmpty
                  ? const Center(child: Text('Aucun incident'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: p.incidents.length,
                      itemBuilder: (_, i) {
                        final inc = p.incidents[i];
                        return _IncidentCard(
                          incident: inc,
                          statusColor: _statusColor(inc.status),
                          onTap: () =>
                              context.go('/incidents/${inc.id}'),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.danger,
        onPressed: () => context.go('/report'),
        child: const Icon(Icons.add, color: AppColors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: AppColors.danger,
        unselectedItemColor: AppColors.textGrey,
        onTap: (i) {
          if (i == 0) context.go('/home');
          if (i == 2) context.go('/report');
          if (i == 3) context.go('/profile');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Incidents'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline), label: 'Signaler'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final Incident incident;
  final Color statusColor;
  final VoidCallback onTap;

  const _IncidentCard({
    required this.incident,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(incident.typeIcon, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        incident.type,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          incident.statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    incident.location,
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    incident.date,
                    style: const TextStyle(
                        color: AppColors.textGrey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
