import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';
import 'package:senalert_mobile/features/incidents/models/incident_model.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  bool _isAvailable = true;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<IncidentProvider>().fetchIncidents();
    });
  }

  void _showEtaDialog(BuildContext context, Incident inc) {
    final auth = context.read<AuthProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.timer, color: AppColors.emerald),
            SizedBox(width: 8),
            Text('Temps d\'arrivée estimé', style: TextStyle(color: AppColors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sélectionnez le délai d\'intervention prévu pour informer le citoyen :',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            for (var eta in [
              '5 min (Unité Rapide ⚡)',
              '10 min (Patrouille standard 🚒)',
              '15 min (Intervention renforcée 🚑)',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ElevatedButton(
                  onPressed: () {
                    final time = '${eta.split(' ')[0]} min';
                    context.read<IncidentProvider>().updateIncidentStatus(
                          inc.id,
                          'en_cours',
                          eta: time,
                          responderInfo: '${auth.userName} (${auth.userRole})',
                        );
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Alerte #${inc.id} ACCEPTÉE ! Temps estimé d\'arrivée : $time'),
                          backgroundColor: AppColors.emerald,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.crimson,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: Text(eta, style: const TextStyle(color: AppColors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final incidents = incidentProvider.incidents;

    return Scaffold(
      backgroundColor: AppColors.darkSlate,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go('/home'),
        ),
        title: const Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.crimson),
            SizedBox(width: 8),
            Text(
              'Portail Commandement Police & Secours',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            onPressed: () => incidentProvider.fetchIncidents(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Officer Profile & Status Switch Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isAvailable ? AppColors.emerald : AppColors.crimson,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.crimson,
                    child: Icon(Icons.badge, color: AppColors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Consumer<AuthProvider>(
                      builder: (_, auth, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.userName,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${auth.userRole} • ${auth.userEmail}',
                            style: const TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Switch(
                    value: _isAvailable,
                    activeColor: AppColors.emerald,
                    onChanged: (v) {
                      setState(() {
                        _isAvailable = v;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isAvailable
                                ? 'Statut : EN PATROUILLE / DISPONIBLE'
                                : 'Statut : HORS SERVICE',
                          ),
                          backgroundColor:
                              _isAvailable ? AppColors.emerald : AppColors.crimson,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Tab Filters
            Row(
              children: [
                _TabButton(
                  title: 'Avis d\'Urgence Citoyens (${incidents.length})',
                  isActive: _activeTab == 0,
                  onTap: () => setState(() => _activeTab = 0),
                ),
                const SizedBox(width: 10),
                _TabButton(
                  title: 'Carte GPS Live',
                  isActive: _activeTab == 1,
                  onTap: () => setState(() => _activeTab = 1),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tab Content
            if (_activeTab == 0) ...[
              if (incidents.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'Aucune alerte citoyenne en attente',
                      style: TextStyle(color: AppColors.textGrey),
                    ),
                  ),
                )
              else
                ...incidents.map((inc) {
                  return _AgentInterventionCard(
                    incident: inc,
                    onAccept: () => _showEtaDialog(context, inc),
                    onReject: () {
                      incidentProvider.updateIncidentStatus(inc.id, 'refuse');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Urgence #${inc.id} REFUSÉE / Classée.'),
                          backgroundColor: AppColors.crimson,
                        ),
                      );
                    },
                    onComplete: () {
                      incidentProvider.updateIncidentStatus(inc.id, 'traite');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Urgence #${inc.id} MARQUÉE TRAITÉE ✓'),
                          backgroundColor: AppColors.emerald,
                        ),
                      );
                    },
                  );
                }),
            ] else ...[
              Container(
                height: 420,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(14.6928, -17.4467), // Dakar
                      initialZoom: 12.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.senalert.app',
                      ),
                      MarkerLayer(
                        markers: incidents.map((inc) {
                          final lat = inc.latitude != 0 ? inc.latitude : 14.6928;
                          final lng = inc.longitude != 0 ? inc.longitude : -17.4467;

                          return Marker(
                            point: LatLng(lat, lng),
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.crimson,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(inc.typeIcon, style: const TextStyle(fontSize: 18)),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.crimson : AppColors.navy,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: AppColors.white,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AgentInterventionCard extends StatelessWidget {
  final Incident incident;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onComplete;

  const _AgentInterventionCard({
    required this.incident,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final status = incident.status.toLowerCase();
    final isPending = status == 'en_attente' || status == 'nouveau';
    final isInProgress = status == 'en_cours';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending
              ? Colors.orange.withOpacity(0.6)
              : isInProgress
                  ? AppColors.emerald
                  : Colors.grey.shade700,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(incident.typeIcon, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.type,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      incident.location,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPending
                      ? Colors.orange.withOpacity(0.2)
                      : isInProgress
                          ? AppColors.emerald.withOpacity(0.2)
                          : AppColors.crimson.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  incident.statusLabel,
                  style: TextStyle(
                    color: isPending
                        ? Colors.orange
                        : isInProgress
                            ? AppColors.emerald
                            : AppColors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (incident.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              incident.description,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const Divider(color: Colors.white12, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alerte #${incident.id} • ${incident.date}',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 11),
              ),
              if (isPending) ...[
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.crimson,
                        side: const BorderSide(color: AppColors.crimson),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('REFUSER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: onAccept,
                      icon: const Icon(Icons.check_circle, size: 14, color: AppColors.white),
                      label: const Text('ACCEPTER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                )
              ] else if (isInProgress) ...[
                ElevatedButton.icon(
                  onPressed: onComplete,
                  icon: const Icon(Icons.task_alt, size: 14, color: AppColors.white),
                  label: const Text('MARQUER TRAITÉE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
              ] else ...[
                const Text(
                  'Clôturée',
                  style: TextStyle(color: AppColors.textGrey, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
