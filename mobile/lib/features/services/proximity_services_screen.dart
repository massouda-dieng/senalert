import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';

class ProximityServicesScreen extends StatefulWidget {
  const ProximityServicesScreen({super.key});

  @override
  State<ProximityServicesScreen> createState() => _ProximityServicesScreenState();
}

class _ProximityServicesScreenState extends State<ProximityServicesScreen> {
  String _selectedCategory = 'Tous';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _services = [
    {
      'name': 'Hôpital Principal de Dakar',
      'type': 'Hôpital',
      'location': 'Plateau, Dakar',
      'distance': '0.8 km',
      'phone': '33 839 50 50',
      'status': 'Ouvert 24/7',
      'icon': Icons.local_hospital,
      'color': AppColors.crimson,
    },
    {
      'name': 'Pharmacie de Garde de la Nation',
      'type': 'Pharmacie',
      'location': 'Place de l\'Indépendance',
      'distance': '0.5 km',
      'phone': '33 821 24 00',
      'status': 'Pharmacie de Garde 24h/24',
      'icon': Icons.local_pharmacy,
      'color': Colors.purple,
    },
    {
      'name': 'Caserne Sapeurs-Pompiers Malick Sy',
      'type': 'Pompiers',
      'location': 'Avenue Malick Sy, Dakar',
      'distance': '1.4 km',
      'phone': '18',
      'status': 'Garde d\'urgence 24/7',
      'icon': Icons.local_fire_department,
      'color': Colors.orange,
    },
    {
      'name': 'Commissariat Central de Dakar',
      'type': 'Police',
      'location': 'Place de l\'Indépendance',
      'distance': '1.1 km',
      'phone': '17',
      'status': 'Patrouille active',
      'icon': Icons.local_police,
      'color': AppColors.navy,
    },
    {
      'name': 'Croix-Rouge Sénégalaise',
      'type': 'Secours',
      'location': 'Boulevard Martin Luther King',
      'distance': '2.1 km',
      'phone': '33 823 39 80',
      'status': 'Poste de Secours Secouristes',
      'icon': Icons.healing,
      'color': AppColors.emerald,
    },
    {
      'name': 'Pharmacie de Garde Fann',
      'type': 'Pharmacie',
      'location': 'Avenue Cheikh Anta Diop',
      'distance': '2.8 km',
      'phone': '33 825 15 15',
      'status': 'Ouvert Nuit & Jour',
      'icon': Icons.local_pharmacy,
      'color': Colors.purple,
    },
    {
      'name': 'Hôpital Fann (Urgences)',
      'type': 'Hôpital',
      'location': 'Fann Résidence, Dakar',
      'distance': '3.2 km',
      'phone': '33 869 18 18',
      'status': 'Ouvert 24/7',
      'icon': Icons.local_hospital,
      'color': AppColors.crimson,
    },
    {
      'name': 'Centre SAMU National 15',
      'type': 'SAMU',
      'location': 'Fann, Dakar',
      'distance': '2.9 km',
      'phone': '15',
      'status': 'Ambulances prêtes',
      'icon': Icons.medical_services,
      'color': AppColors.emerald,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _services.where((s) {
      final matchesCategory = _selectedCategory == 'Tous' || s['type'] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          (s['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (s['location'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.darkSlate,
        title: const Text('Services de Secours Proches', style: TextStyle(color: AppColors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          // Live Search Bar
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Rechercher hôpital, pharmacie, lieu...',
                prefixIcon: const Icon(Icons.search, color: AppColors.crimson),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Category Filter Horizontal Pills
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Tous', 'Hôpital', 'Pharmacie', 'Pompiers', 'Police', 'SAMU', 'Secours'].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: AppColors.crimson.withOpacity(0.15),
                      checkmarkColor: AppColors.crimson,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.crimson : AppColors.textDark,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) => setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Service List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final item = filtered[i];
                final color = item['color'] as Color;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item['icon'] as IconData, color: color, size: 28),
                    ),
                    title: Text(
                      item['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textDark,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: AppColors.textGrey),
                              const SizedBox(width: 4),
                              Text('${item['location']} • ${item['distance']}'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item['status'] as String,
                              style: const TextStyle(
                                color: AppColors.emerald,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Appel d\'urgence vers ${item['name']} (${item['phone']})'),
                            backgroundColor: AppColors.emerald,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.phone, size: 16, color: AppColors.white),
                      label: Text(
                        item['phone'] as String,
                        style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
