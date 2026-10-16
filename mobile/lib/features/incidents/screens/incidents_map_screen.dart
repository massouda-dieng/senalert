import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';

class IncidentsMapScreen extends StatefulWidget {
  const IncidentsMapScreen({super.key});

  @override
  State<IncidentsMapScreen> createState() => _IncidentsMapScreenState();
}

class _IncidentsMapScreenState extends State<IncidentsMapScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<IncidentProvider>().fetchIncidents();
    });
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'nouveau':
      case 'en_attente': return AppColors.warning;
      case 'en_cours':   return AppColors.info;
      case 'resolu':
      case 'traite':     return AppColors.success;
      default:           return AppColors.textGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final incidentProvider = context.watch<IncidentProvider>();
    final incidents = incidentProvider.incidents;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.darkSlate,
        title: const Text('Carte GPS des Incidents', style: TextStyle(color: AppColors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            onPressed: () => context.read<IncidentProvider>().fetchIncidents(),
          ),
        ],
      ),
      body: Column(
        children: [
          // FlutterMap Interactive GPS View
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
                        final color = _statusColor(inc.status);

                        return Marker(
                          point: LatLng(lat, lng),
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: () => context.go('/incidents/${inc.id}'),
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  inc.typeIcon,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Map Control Overlay - Reset View
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    backgroundColor: AppColors.darkSlate,
                    onPressed: () {
                      _mapController.move(const LatLng(14.6928, -17.4467), 12.0);
                    },
                    child: const Icon(Icons.my_location, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ),

          // Lower Feed List
          Expanded(
            flex: 4,
            child: Container(
              color: AppColors.white,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: incidents.isEmpty
                        ? const Center(child: Text('Aucune alerte enregistrée'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: incidents.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final alert = incidents[index];
                              return ListTile(
                                leading: Text(alert.typeIcon, style: const TextStyle(fontSize: 24)),
                                title: Text(
                                  alert.type,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                subtitle: Text(
                                  alert.location,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(alert.status).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    alert.statusLabel,
                                    style: TextStyle(
                                      color: _statusColor(alert.status),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                onTap: () => context.go('/incidents/${alert.id}'),
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
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Carte GPS'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Signaler'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services_outlined), label: 'Secours'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
