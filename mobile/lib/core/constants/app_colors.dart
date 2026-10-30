import 'package:flutter/material.dart';

/// Palette SenAlert « Sénégal vibrant » — mêmes jetons que le web (tailwind.config.js).
/// Vert du drapeau : identité ; jaune : accents ; rouge : réservé au SOS et à l'urgence.
class AppColors {
  // Vert (identité, navigation, actions principales)
  static const Color vert950 = Color(0xFF00210F);
  static const Color vert900 = Color(0xFF003A1B);
  static const Color vert800 = Color(0xFF005527);
  static const Color vert700 = Color(0xFF006E33);
  static const Color vert600 = Color(0xFF00853F);
  static const Color vert100 = Color(0xFFD3F0DF);
  static const Color vert50 = Color(0xFFECF8F1);

  // Jaune
  static const Color jaune = Color(0xFFFDEF42);
  static const Color jauneFonce = Color(0xFF8A6D00);
  static const Color jauneClair = Color(0xFFFFF9D1);

  // Rouge (SOS uniquement)
  static const Color crimson = Color(0xFFE31B23);
  static const Color crimsonDeep = Color(0xFFB5121A);

  // Surfaces
  static const Color background = Color(0xFFF8F7F1);
  static const Color white = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1EFE6);
  static const Color border = Color(0xFFE7E4D8);

  // Texte
  static const Color textDark = Color(0xFF10231A);
  static const Color textGrey = Color(0xFF53645B);
  static const Color textMuted = Color(0xFF8A978F);

  // États
  static const Color success = Color(0xFF047857);
  static const Color warning = Color(0xFFC2410C);
  static const Color info = Color(0xFF1D4ED8);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [vert950, vert800, vert700]);
  static const LinearGradient sosGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF2434A), crimson, crimsonDeep]);
}
