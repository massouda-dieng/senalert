import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/incidents/models/incident_model.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';
import 'package:senalert_mobile/shared/widgets/custom_button.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

class IncidentDetailScreen extends StatelessWidget {
  final String incidentId;
  const IncidentDetailScreen({super.key, required this.incidentId});

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
    final t = SaIncidentType.of(incident.type);
    final closed = incident.status == 'resolu' || incident.status == 'traite' || incident.status == 'refuse';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SaHeader(
            title: 'Détail du signalement',
            subtitle: incident.id != 0 ? 'Signalement #${incident.id}' : null,
            onBack: () => context.go('/incidents'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // Carte principale : type + statut
                SaFadeSlide(
                  child: SaCard(
                    padding: EdgeInsets.zero,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (incident.photo != null && incident.photo!.startsWith('http'))
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            incident.photo!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        )
                      else
                        Container(
                          height: 96,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [t.color.withOpacity(0.18), t.color.withOpacity(0.04)],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(t.icon, size: 46, color: t.color),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(t.label, style: SaText.display(20))),
                            SaStatusBadge(incident.status),
                          ]),
                          const SizedBox(height: 12),
                          if (incident.location.isNotEmpty)
                            _InfoRow(Icons.location_on_outlined, 'Localisation', incident.location),
                          if (incident.date.isNotEmpty)
                            _InfoRow(Icons.calendar_today_outlined, 'Signalé le', incident.date),
                          _InfoRow(Icons.category_outlined, 'Catégorie', t.label),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                // Suivi de l'intervenant & ETA
                if (incident.responderInfo != null || incident.status == 'en_cours') ...[
                  SaFadeSlide(
                    index: 1,
                    child: SaNightBackdrop(
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.support_agent_rounded, color: Color(0xFF34D399)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Équipe de secours en route',
                                  style: SaText.display(15, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text('Intervenant : ${incident.responderInfo ?? "Brigade de Secours"}',
                                  style: SaText.body(13, color: Colors.white.withOpacity(0.8))),
                              if (incident.eta != null)
                                Text('Temps d\'arrivée estimé : ${incident.eta}',
                                    style: SaText.body(13, color: const Color(0xFFFDBA74), weight: FontWeight.w700)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Description
                SaFadeSlide(
                  index: 2,
                  child: SaCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Description', style: SaText.display(15)),
                      const SizedBox(height: 8),
                      Text(incident.description,
                          style: SaText.body(14, color: AppColors.textDark).copyWith(height: 1.55)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                // Frise de suivi
                SaFadeSlide(
                  index: 3,
                  child: SaCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Suivi du traitement', style: SaText.display(15)),
                      const SizedBox(height: 14),
                      _Timeline(status: incident.status, date: incident.date),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: () => context.go('/map'),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Voir sur la carte'),
                ),
                const SizedBox(height: 12),
                if (!closed)
                  CustomButton(
                    text: 'Marquer comme traité',
                    icon: Icons.task_alt_rounded,
                    color: AppColors.emerald,
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
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String k;
  final String v;
  const _InfoRow(this.icon, this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: AppColors.textGrey),
        const SizedBox(width: 8),
        SizedBox(width: 92, child: Text(k, style: SaText.body(13))),
        Expanded(child: Text(v, style: SaText.body(13, color: AppColors.textDark, weight: FontWeight.w600))),
      ]),
    );
  }
}

/// Frise Reçu → En cours → Résolu (ou Refusé), construite à partir du
/// statut et de la date de création existants.
class _Timeline extends StatelessWidget {
  final String status;
  final String date;
  const _Timeline({required this.status, required this.date});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final refused = s == 'refuse';
    final level = switch (s) {
      'en_cours' => 1,
      'resolu' || 'traite' || 'refuse' => 2,
      _ => 0,
    };
    final steps = [
      ('Signalement reçu', date.isNotEmpty ? date : null, AppColors.emerald),
      ('En cours de traitement', null, AppColors.blue600),
      (refused ? 'Refusé' : 'Résolu', null, refused ? const Color(0xFF475569) : AppColors.emerald),
    ];
    return Column(
      children: List.generate(steps.length, (i) {
        final done = i <= level;
        final st = steps[i];
        final color = done ? st.$3 : AppColors.border;
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 300 + i * 150),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? color : Colors.white,
                  border: Border.all(color: color, width: 2),
                  boxShadow: done && i == level
                      ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10)]
                      : null,
                ),
                child: done
                    ? Icon(i == 2 && refused ? Icons.close_rounded : Icons.check_rounded,
                        size: 15, color: Colors.white)
                    : null,
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: i < level ? steps[i + 1].$3 : AppColors.border,
                  ),
                ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18, top: 3),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(st.$1,
                      style: SaText.body(14,
                          color: done ? AppColors.textDark : AppColors.textMuted,
                          weight: done ? FontWeight.w700 : FontWeight.w500)),
                  if (st.$2 != null) Text(st.$2!, style: SaText.body(12)),
                ]),
              ),
            ),
          ]),
        );
      }),
    );
  }
}
