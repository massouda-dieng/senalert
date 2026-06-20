import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/alert_model.dart';
import 'alert_detail_screen.dart';

class IncidentsMapScreen extends StatefulWidget {
  const IncidentsMapScreen({super.key});

  @override
  State<IncidentsMapScreen> createState() => _IncidentsMapScreenState();
}

class _IncidentsMapScreenState extends State<IncidentsMapScreen> {
  String? _filterType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {},
        ),
        title: const Text('Carte des incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Map placeholder
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                // Map background
                Container(
                  width: double.infinity,
                  color: const Color(0xFFE8F4E8),
                  child: CustomPaint(
                    painter: _MapPainter(),
                    child: Stack(
                      children: [
                        // Map markers
                        ...sampleAlerts.map((alert) => _MapMarker(alert: alert)),
                      ],
                    ),
                  ),
                ),
                // Legend
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: _MapLegend(),
                ),
                // My location button
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.white,
                    onPressed: () {},
                    child: const Icon(Icons.my_location, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          // Alert list
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sampleAlerts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final alert = sampleAlerts[index];
                        return _AlertListTile(
                          alert: alert,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AlertDetailScreen(alert: alert),
                              ),
                            );
                          },
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
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtrer par type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Accident', 'Incendie', 'Inondation', 'Urgence médicale']
                  .map((type) => FilterChip(
                        label: Text(type),
                        selected: _filterType == type,
                        selectedColor: AppColors.primary.withOpacity(0.15),
                        checkmarkColor: AppColors.primary,
                        onSelected: (selected) {
                          setState(() => _filterType = selected ? type : null);
                          Navigator.pop(context);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Draw a basic map-like grid
    final paint = Paint()
      ..color = const Color(0xFFD4E8D4)
      ..strokeWidth = 1;

    // Horizontal roads
    for (double y = 0; y < size.height; y += size.height / 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical roads
    for (double x = 0; x < size.width; x += size.width / 6) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Main roads (thicker, lighter)
    final mainRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8;
    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.4),
      mainRoadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.35, 0),
      Offset(size.width * 0.35, size.height),
      mainRoadPaint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MapMarker extends StatelessWidget {
  final AlertModel alert;
  const _MapMarker({required this.alert});

  Color get _color {
    switch (alert.type) {
      case 'Accident': return AppColors.primary;
      case 'Incendie': return Colors.orange;
      case 'Inondation': return AppColors.info;
      case 'Urgence médicale': return AppColors.success;
      default: return AppColors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final positions = [
      const Offset(0.3, 0.35),
      const Offset(0.6, 0.25),
      const Offset(0.7, 0.6),
      const Offset(0.2, 0.65),
    ];
    final idx = sampleAlerts.indexOf(alert);
    final pos = idx < positions.length ? positions[idx] : const Offset(0.5, 0.5);

    return Positioned(
      left: MediaQuery.of(context).size.width * pos.dx - 15,
      top: (MediaQuery.of(context).size.height * 0.55) * pos.dy - 15,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: _color.withOpacity(0.4),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.warning, color: Colors.white, size: 14),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [
      ('Accident', AppColors.primary),
      ('Inondation', AppColors.info),
      ('Incendie', Colors.orange),
      ('Urgence médicale', AppColors.success),
    ];

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.$2,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.$1,
                        style: const TextStyle(fontSize: 10, color: AppColors.dark),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _AlertListTile extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onTap;
  const _AlertListTile({required this.alert, required this.onTap});

  Color get _statusColor {
    switch (alert.status) {
      case 'pending': return AppColors.warning;
      case 'in_progress': return AppColors.info;
      case 'resolved': return AppColors.success;
      default: return AppColors.grey;
    }
  }

  IconData get _typeIcon {
    switch (alert.type) {
      case 'Accident': return Icons.car_crash;
      case 'Incendie': return Icons.local_fire_department;
      case 'Inondation': return Icons.water;
      case 'Urgence médicale': return Icons.medical_services;
      default: return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(_typeIcon, color: AppColors.primary),
      title: Text(
        alert.type,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.dark,
        ),
      ),
      subtitle: Text(
        alert.location,
        style: const TextStyle(fontSize: 12, color: AppColors.grey),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              alert.statusLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _statusColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            alert.date.split(' à').first,
            style: const TextStyle(fontSize: 10, color: AppColors.grey),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
