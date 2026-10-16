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
    Future.microtask(() {
      if (mounted) context.read<IncidentProvider>().fetchIncidents();
    });
  }

  String _selectedFilter = 'tous';

  Color _statusColor(String s) {
    switch (s) {
      case 'nouveau':    return AppColors.warning;
      case 'en_cours':   return AppColors.info;
      case 'resolu':     return AppColors.success;
      case 'refuse':     return AppColors.danger;
      default:           return AppColors.textGrey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'nouveau':    return 'Nouveau';
      case 'en_cours':   return 'En cours';
      case 'resolu':     return 'Résolu';
      case 'refuse':     return 'Refusé';
      default:           return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes signalements'),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () => context.read<IncidentProvider>().fetchIncidents(),
          ),
        ],
      ),
      body: Consumer<IncidentProvider>(builder: (_, p, __) {
        if (p.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.danger));
        }
        final incidents = _selectedFilter == 'tous'
            ? p.incidents
            : p.incidents.where((i) => i.statut == _selectedFilter).toList();

        return Column(
          children: [
            // Filtres rapides
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in [
                      ('tous', 'Tous'),
                      ('nouveau', 'Nouveaux'),
                      ('en_cours', 'En cours'),
                      ('resolu', 'Résolus'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f.$2),
                          selected: _selectedFilter == f.$1,
                          selectedColor: AppColors.danger.withOpacity(0.15),
                          onSelected: (_) => setState(() => _selectedFilter = f.$1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Légende
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
