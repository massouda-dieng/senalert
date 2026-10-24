import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

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

    const cats = ['Tous', 'Hôpital', 'Pharmacie', 'Pompiers', 'Police', 'SAMU', 'Secours'];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SaHeader(
            title: 'Services de secours',
            subtitle: 'Hôpitaux, pharmacies, police, pompiers',
            onBack: () => context.go('/home'),
            bottom: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: SaText.body(14.5, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher hôpital, pharmacie, lieu…',
                hintStyle: SaText.body(14, color: Colors.white60),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                fillColor: Colors.white.withOpacity(0.1),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.16)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: AppColors.orange, width: 1.4),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              children: cats.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    showCheckmark: false,
                    selectedColor: AppColors.navy800,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    labelStyle: SaText.body(13,
                        color: isSelected ? Colors.white : AppColors.textDark, weight: FontWeight.w700),
                    onSelected: (val) => setState(() => _selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const SaEmptyState(icon: Icons.search_off_rounded, title: 'Aucun service trouvé')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      final color = item['color'] as Color;
                      return SaFadeSlide(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SaCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(item['icon'] as IconData, color: color, size: 26),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(item['name'] as String,
                                      style: SaText.body(14.5, color: AppColors.textDark, weight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textGrey),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(item['location'] as String,
                                          maxLines: 1, overflow: TextOverflow.ellipsis, style: SaText.body(12)),
                                    ),
                                  ]),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.emerald.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(item['status'] as String,
                                        style: SaText.body(11, color: AppColors.emerald, weight: FontWeight.w700)),
                                  ),
                                ]),
                              ),
                              const SizedBox(width: 8),
                              Material(
                                color: AppColors.navy800,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Appel d\'urgence vers ${item['name']} (${item['phone']})'),
                                        backgroundColor: AppColors.emerald,
                                      ),
                                    );
                                  },
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                                        const Icon(Icons.phone_rounded, size: 18, color: Colors.white),
                                        const SizedBox(height: 2),
                                        Text(item['phone'] as String,
                                            style: SaText.body(11, color: Colors.white, weight: FontWeight.w800)),
                                      ]),
                                    ),
                                  ),
                                ),
                              ),
                            ]),
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
