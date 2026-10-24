import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/incidents/models/incident_model.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

class IncidentsMapScreen extends StatefulWidget {
  const IncidentsMapScreen({super.key});

  @override
  State<IncidentsMapScreen> createState() => _IncidentsMapScreenState();
}

class _IncidentsMapScreenState extends State<IncidentsMapScreen> {
  final MapController _mapController = MapController();
  String _filter = 'tous';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<IncidentProvider>().fetchIncidents();
    });
  }

  bool _matches(Incident i) {
    final s = i.status.toLowerCase();
    switch (_filter) {
      case 'en_cours':
        return s == 'en_cours';
      case 'nouveau':
        return s == 'nouveau' || s == 'en_attente';
      case 'resolu':
        return s == 'resolu' || s == 'traite';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final incidents = incidentProvider.incidents.where(_matches).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SaHeader(
            title: 'Carte des signalements',
            subtitle: '${incidents.length} signalement(s) affiché(s)',
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
              value: _filter,
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
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
                        final st = SaStatus.of(inc.status);
                        return Marker(
                          point: LatLng(lat, lng),
                          width: 48,
                          height: 56,
                          alignment: Alignment.topCenter,
                          child: GestureDetector(
                            onTap: () => context.go('/incidents/${inc.id}'),
                            child: Column(children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: t.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(color: t.color.withOpacity(0.5), blurRadius: 10, spreadRadius: 1),
                                  ],
                                ),
                                child: Icon(t.icon, color: Colors.white, size: 20),
                              ),
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  color: st.fg,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    heroTag: 'recenter',
                    tooltip: 'Recentrer sur Dakar',
                    backgroundColor: AppColors.navy800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    onPressed: () {
                      _mapController.move(const LatLng(14.6928, -17.4467), 12.0);
                    },
                    child: const Icon(Icons.my_location_rounded, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: AppColors.navy800.withOpacity(0.1), blurRadius: 20)],
              ),
              transform: Matrix4.translationValues(0, -20, 0),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                  Expanded(
                    child: incidents.isEmpty
                        ? const SingleChildScrollView(
                            child: SaEmptyState(icon: Icons.map_outlined, title: 'Aucune alerte enregistrée'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            itemCount: incidents.length,
                            itemBuilder: (context, index) {
                              final alert = incidents[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: SaCard(
                                  padding: const EdgeInsets.all(12),
                                  onTap: () => context.go('/incidents/${alert.id}'),
                                  child: Row(children: [
                                    SaTypeIcon(alert.type, size: 42),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(SaIncidentType.of(alert.type).label,
                                            style: SaText.body(14, color: AppColors.textDark, weight: FontWeight.w700)),
                                        Text(alert.location,
                                            maxLines: 1, overflow: TextOverflow.ellipsis, style: SaText.body(12)),
                                      ]),
                                    ),
                                    SaStatusBadge(alert.status, dense: true),
                                  ]),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const SaBottomNav(currentIndex: 2),
    );
  }
}
