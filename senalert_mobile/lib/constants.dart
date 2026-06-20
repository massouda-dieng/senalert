import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFCC1414);
  static const Color primaryDark = Color(0xFF9E0000);
  static const Color dark = Color(0xFF1A1A2E);
  static const Color navy = Color(0xFF16213E);
  static const Color grey = Color(0xFF6B7280);
  static const Color lightGrey = Color(0xFFF3F4F6);
  static const Color border = Color(0xFFE5E7EB);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);
  static const Color white = Colors.white;
  static const Color background = Color(0xFFF8F9FA);
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.dark,
    height: 1.2,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.dark,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.dark,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.grey,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.grey,
  );

  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.dark,
  );
}

class AppRoutes {
  static const String splash = '/';
  static const String home = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String report = '/report';
  static const String map = '/map';
  static const String alertDetail = '/alert-detail';
  static const String admin = '/admin';
  static const String profile = '/profile';
}

// Incident types
class IncidentType {
  final String id;
  final String label;
  final String icon;
  final Color color;

  const IncidentType({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

final List<IncidentType> incidentTypes = [
  IncidentType(id: 'accident', label: 'Accident', icon: '🚗', color: const Color(0xFFEF4444)),
  IncidentType(id: 'incendie', label: 'Incendie', icon: '🔥', color: const Color(0xFFF97316)),
  IncidentType(id: 'inondation', label: 'Inondation', icon: '🌊', color: const Color(0xFF3B82F6)),
  IncidentType(id: 'urgence_medicale', label: 'Urgence médicale', icon: '🏥', color: const Color(0xFF10B981)),
  IncidentType(id: 'criminalite', label: 'Criminalité', icon: '⚠️', color: const Color(0xFF8B5CF6)),
  IncidentType(id: 'autre', label: 'Autre', icon: '📋', color: const Color(0xFF6B7280)),
];
