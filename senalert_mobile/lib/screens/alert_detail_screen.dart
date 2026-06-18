import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/alert_model.dart';

class AlertDetailScreen extends StatelessWidget {
  final AlertModel alert;
  const AlertDetailScreen({super.key, required this.alert});

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Détails de l\'alerte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type and status
            Row(
              children: [
                Icon(_typeIcon, color: AppColors.primary, size: 26),
                const SizedBox(width: 10),
                Text(
                  alert.type,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.dark,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    alert.statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Description
            _DetailSection(
              title: 'Description',
              child: Text(
                alert.description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.grey,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Location
            _DetailSection(
              title: 'Localisation',
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    alert.location,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.dark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Voir sur la carte',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Mini map placeholder
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4E8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(double.infinity, 160),
                      painter: _MiniMapPainter(),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date
            _DetailSection(
              title: 'Date',
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.grey, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    alert.date,
                    style: const TextStyle(fontSize: 14, color: AppColors.dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Photo section
            _DetailSection(
              title: 'Photo',
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Simulated accident photo-like visual
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF334155), Color(0xFF64748B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      const Icon(Icons.image, color: Colors.white54, size: 50),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Photo de l\'incident',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Action button (for admins)
            if (alert.status != 'resolved')
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Alerte marquée comme traitée'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('MARQUER COMME TRAITÉ'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _DetailSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.grey,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD4E8D4)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += size.height / 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (double x = 0; x < size.width; x += size.width / 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 10;
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), roadPaint);
    canvas.drawLine(Offset(size.width * 0.5, 0), Offset(size.width * 0.5, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}
