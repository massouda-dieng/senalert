import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/incidents/models/incident_model.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

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

  bool _matches(Incident i) {
    switch (_selectedFilter) {
      case 'nouveau':
        return i.status == 'nouveau' || i.status == 'en_attente';
      case 'en_cours':
        return i.status == 'en_cours';
      case 'resolu':
        return i.status == 'resolu' || i.status == 'traite';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SaHeader(
            title: 'Mes signalements',
            subtitle: 'Suivez l\'avancement de vos alertes',
            onBack: () => context.go('/home'),
            actions: [
              SaIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Actualiser',
                onTap: () => context.read<IncidentProvider>().fetchIncidents(),
              ),
            ],
            bottom: SaSegmentedTabs<String>(
              onDark: true,
              options: const [
                ('tous', 'Tous'),
                ('nouveau', 'Nouveaux'),
                ('en_cours', 'En cours'),
                ('resolu', 'Résolus'),
              ],
              value: _selectedFilter,
              onChanged: (v) => setState(() => _selectedFilter = v),
            ),
          ),
          Expanded(
            child: Consumer<IncidentProvider>(builder: (_, p, __) {
              if (p.isLoading) {
                return const Center(child: CircularProgressIndicator(color: AppColors.navy800));
              }
              final incidents = p.incidents.where(_matches).toList();
              return RefreshIndicator(
                color: AppColors.navy800,
                onRefresh: p.fetchIncidents,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    if (p.error != null) ...[SaInfoBanner(p.error!), const SizedBox(height: 12)],
                    if (incidents.isEmpty)
                      SaEmptyState(
                        icon: Icons.inbox_rounded,
                        title: _selectedFilter == 'tous' ? 'Aucun incident' : 'Aucun incident avec ce statut',
                        message: 'Tirez vers le bas pour actualiser.',
                      )
                    else
                      for (var i = 0; i < incidents.length; i++)
                        SaFadeSlide(
                          key: ValueKey('${_selectedFilter}_${incidents[i].id}'),
                          index: i,
                          child: _IncidentCard(
                            incident: incidents[i],
                            onTap: () => context.go('/incidents/${incidents[i].id}'),
                          ),
                        ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orangeDeep,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () => context.go('/report'),
        icon: const Icon(Icons.add_rounded),
        label: Text('Signaler', style: SaText.body(14, color: Colors.white, weight: FontWeight.w700)),
      ),
      bottomNavigationBar: const SaBottomNav(currentIndex: 1),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final Incident incident;
  final VoidCallback onTap;

  const _IncidentCard({required this.incident, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = SaIncidentType.of(incident.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SaCard(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          children: [
            SaTypeIcon(incident.type, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(t.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SaText.body(15, color: AppColors.textDark, weight: FontWeight.w700)),
                    ),
                    SaStatusBadge(incident.status, dense: true),
                  ]),
                  if (incident.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(incident.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SaText.body(12.5, color: AppColors.textDark)),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textGrey),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(incident.location,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: SaText.body(12)),
                    ),
                    if (incident.date.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textGrey),
                      const SizedBox(width: 3),
                      Text(incident.date, style: SaText.body(11.5)),
                    ],
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
