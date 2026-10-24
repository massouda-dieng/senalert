import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';
import 'package:senalert_mobile/features/incidents/models/incident_model.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

class AgentDashboardScreen extends StatefulWidget {
  const AgentDashboardScreen({super.key});

  @override
  State<AgentDashboardScreen> createState() => _AgentDashboardScreenState();
}

class _AgentDashboardScreenState extends State<AgentDashboardScreen> {
  bool _isAvailable = true;
  int _activeTab = 0;
  String _filter = 'tous';

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
        title: Row(
          children: [
            const Icon(Icons.timer_outlined, color: AppColors.blue600),
            const SizedBox(width: 8),
            Text('Temps d\'arrivée estimé', style: SaText.display(16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sélectionnez le délai d\'intervention prévu pour informer le citoyen :',
              style: SaText.body(13),
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
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: Text(eta),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _matches(Incident i) {
    final s = i.status.toLowerCase();
    switch (_filter) {
      case 'nouveau':
        return s == 'nouveau' || s == 'en_attente';
      case 'en_cours':
        return s == 'en_cours';
      case 'clos':
        return s == 'resolu' || s == 'traite' || s == 'refuse';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final incidents = incidentProvider.incidents;
    final nouveaux = incidents.where((i) => i.status == 'nouveau' || i.status == 'en_attente').length;
    final enCours = incidents.where((i) => i.status == 'en_cours').length;
    final clos = incidents.where((i) => i.status == 'resolu' || i.status == 'traite').length;
    final filtered = incidents.where(_matches).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SaNightBackdrop(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.shield_rounded, color: AppColors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Tableau de bord agent', style: SaText.display(18, color: Colors.white))),
                      SaIconButton(
                        icon: Icons.refresh_rounded,
                        tooltip: 'Actualiser',
                        onTap: () => incidentProvider.fetchIncidents(),
                      ),
                      const SizedBox(width: 8),
                      SaIconButton(
                        icon: Icons.person_rounded,
                        tooltip: 'Profil',
                        onTap: () => context.go('/profile'),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    // Profil agent + disponibilité
                    SaGlass(
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: AppColors.orangeGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.badge_rounded, color: AppColors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Consumer<AuthProvider>(
                              builder: (_, auth, __) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(auth.userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: SaText.body(15, color: Colors.white, weight: FontWeight.w700)),
                                  Text(
                                    _isAvailable ? 'En patrouille · disponible' : 'Hors service',
                                    style: SaText.body(12,
                                        color: _isAvailable ? const Color(0xFF6EE7B7) : const Color(0xFFFDA4AF)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Switch(
                            value: _isAvailable,
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
                                  backgroundColor: _isAvailable ? AppColors.emerald : AppColors.crimson,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      _Kpi(value: nouveaux, label: 'Nouveaux', color: const Color(0xFFFCD34D)),
                      const SizedBox(width: 8),
                      _Kpi(value: enCours, label: 'En cours', color: const Color(0xFF93C5FD)),
                      const SizedBox(width: 8),
                      _Kpi(value: clos, label: 'Résolus', color: const Color(0xFF6EE7B7)),
                    ]),
                    const SizedBox(height: 14),
                    SaSegmentedTabs<int>(
                      onDark: true,
                      options: [(0, 'Interventions (${incidents.length})'), (1, 'Carte GPS')],
                      value: _activeTab,
                      onChanged: (v) => setState(() => _activeTab = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _activeTab == 0
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final f in const [
                              ('tous', 'Tous'),
                              ('nouveau', 'Nouveaux'),
                              ('en_cours', 'En cours'),
                              ('clos', 'Clôturés'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(f.$2),
                                  selected: _filter == f.$1,
                                  showCheckmark: false,
                                  labelStyle: SaText.body(12.5,
                                      color: _filter == f.$1 ? Colors.white : AppColors.textDark,
                                      weight: FontWeight.w700),
                                  selectedColor: AppColors.navy800,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  onSelected: (_) => setState(() => _filter = f.$1),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (incidentProvider.error != null) ...[
                        SaInfoBanner(incidentProvider.error!),
                        const SizedBox(height: 12),
                      ],
                      if (filtered.isEmpty)
                        const SaEmptyState(
                          icon: Icons.task_alt_rounded,
                          title: 'Aucune alerte citoyenne en attente',
                        )
                      else
                        for (var k = 0; k < filtered.length; k++)
                          SaFadeSlide(
                            key: ValueKey('${_filter}_${filtered[k].id}'),
                            index: k,
                            child: _AgentInterventionCard(
                              incident: filtered[k],
                              onAccept: () => _showEtaDialog(context, filtered[k]),
                              onReject: () {
                                final inc = filtered[k];
                                incidentProvider.updateIncidentStatus(inc.id, 'refuse');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Urgence #${inc.id} REFUSÉE / Classée.'),
                                    backgroundColor: AppColors.crimson,
                                  ),
                                );
                              },
                              onComplete: () {
                                final inc = filtered[k];
                                incidentProvider.updateIncidentStatus(inc.id, 'traite');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Urgence #${inc.id} MARQUÉE TRAITÉE ✓'),
                                    backgroundColor: AppColors.emerald,
                                  ),
                                );
                              },
                            ),
                          ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
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
                              final t = SaIncidentType.of(inc.type);
                              return Marker(
                                point: LatLng(lat, lng),
                                width: 42,
                                height: 42,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: t.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [BoxShadow(color: t.color.withOpacity(0.5), blurRadius: 10)],
                                  ),
                                  child: Icon(t.icon, color: Colors.white, size: 20),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _Kpi({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SaGlass(
        radius: 16,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value', style: SaText.display(22, color: color)),
          Text(label, style: SaText.body(11.5, color: Colors.white.withOpacity(0.8))),
        ]),
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
    final t = SaIncidentType.of(incident.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SaCard(
        border: Border.all(
          color: isPending ? AppColors.warning.withOpacity(0.5) : AppColors.border,
          width: isPending ? 1.4 : 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SaTypeIcon(incident.type, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.label, style: SaText.body(15, color: AppColors.textDark, weight: FontWeight.w700)),
                      Text(incident.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: SaText.body(12)),
                    ],
                  ),
                ),
                SaStatusBadge(incident.status, dense: true),
              ],
            ),
            if (incident.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(incident.description, style: SaText.body(13, color: AppColors.textDark)),
            ],
            if (isInProgress && incident.eta != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.timer_outlined, size: 15, color: AppColors.blue600),
                const SizedBox(width: 4),
                Text('Arrivée estimée : ${incident.eta}',
                    style: SaText.body(12, color: AppColors.blue600, weight: FontWeight.w700)),
              ]),
            ],
            const Divider(height: 22, color: AppColors.border),
            Row(
              children: [
                Expanded(
                  child: Text('Alerte #${incident.id} · ${incident.date}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: SaText.body(11.5)),
                ),
                if (isPending) ...[
                  _SmallBtn(label: 'Refuser', color: AppColors.crimson, outlined: true, onTap: onReject),
                  const SizedBox(width: 8),
                  _SmallBtn(label: 'Accepter', icon: Icons.check_rounded, color: AppColors.emerald, onTap: onAccept),
                ] else if (isInProgress)
                  _SmallBtn(label: 'Marquer traitée', icon: Icons.task_alt_rounded, color: AppColors.emerald, onTap: onComplete)
                else
                  Text('Clôturée', style: SaText.body(12, weight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _SmallBtn({required this.label, required this.color, required this.onTap, this.icon, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: outlined ? Colors.white : color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color, width: 1.4),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 16, color: Colors.white), const SizedBox(width: 4)],
              Text(label, style: SaText.body(12.5, color: outlined ? color : Colors.white, weight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }
}
