import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/incidents/models/incident_model.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';

class IncidentDetailScreen extends StatelessWidget {
  final String incidentId;
  const IncidentDetailScreen({super.key, required this.incidentId});

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
    final provider = context.read<IncidentProvider>();
    late Incident incident;
    try {
      incident = provider.incidents
          .firstWhere((i) => i.id.toString() == incidentId);
    } catch (_) {
      incident = Incident(
        id: 0,
        type: 'Incident',
        description: 'Détails non disponibles',
        location: '',
        latitude: 0,
        longitude: 0,
        status: 'en_attente',
        date: '',
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Détails de l\'alerte'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/incidents'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type + statut
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(incident.typeIcon,
                          style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 10),
                      Text(
                        incident.type,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor(incident.status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      incident.statusLabel,
                      style: TextStyle(
                        color: _statusColor(incident.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Suivi de l'Intervenant & ETA
            if (incident.responderInfo != null || incident.status == 'en_cours') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.emerald),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.emerald,
                      child: Icon(Icons.support_agent, color: AppColors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Équipe de Secours en Route 🚒',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.emerald),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Intervenant : ${incident.responderInfo ?? "Brigade de Secours"}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                          ),
                          if (incident.eta != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Temps d\'arrivée estimé : ${incident.eta}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.crimson),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Description
            _Section(
              title: 'Description',
              child: Text(
                incident.description,
                style: const TextStyle(
                    color: AppColors.textDark, height: 1.5, fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Localisation
            _Section(
              title: 'Localisation',
              child: Row(
                children: [
                  const Icon(Icons.location_on,
                      color: AppColors.danger, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      incident.location,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Voir sur la carte',
                    style: TextStyle(
                      color: AppColors.danger,
                      decoration: TextDecoration.underline,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Date
            _Section(
              title: 'Date',
              child: Text(
                incident.date,
                style: const TextStyle(fontSize: 14, color: AppColors.textDark),
              ),
            ),
            const SizedBox(height: 12),

            // Photo
            _Section(
              title: 'Photo',
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.image,
                      size: 64, color: AppColors.textGrey),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bouton
            ElevatedButton(
              onPressed: () {
                if (incident.id != 0) {
                  context.read<IncidentProvider>().updateIncidentStatus(incident.id, 'traite');
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Alerte marquée comme traitée avec succès !'),
                    backgroundColor: AppColors.success,
                  ));
                  context.go('/incidents');
                }
              },
              child: const Text('MARQUER COMME TRAITÉ'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textGrey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
