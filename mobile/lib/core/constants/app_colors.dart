import 'package:flutter/material.dart';

/// Palette SenAlert — refonte « bleu nuit + orange ».
/// Les anciens noms sont conservés (compatibilité), leurs valeurs suivent
/// la nouvelle charte. Le rouge #E11D48 est réservé au SOS et à l'urgence.
class AppColors {
  // Marque — bleu nuit profond
  static const Color navy900        = Color(0xFF071330); // fond le plus sombre
  static const Color navy800        = Color(0xFF0B1F4D);
  static const Color navy700        = Color(0xFF12307A);
  static const Color blue600        = Color(0xFF1D4ED8); // bleu action
  static const Color blue500        = Color(0xFF2563EB);
  static const Color blue50         = Color(0xFFEEF3FF);

  // Accent — orange
  static const Color orange         = Color(0xFFF97316);
  static const Color orangeDeep     = Color(0xFFC2410C); // texte orange (AA sur blanc)
  static const Color orange50       = Color(0xFFFFF4EC);

  // Urgence (SOS uniquement)
  static const Color danger         = Color(0xFFE11D48);
  static const Color crimson        = Color(0xFFE11D48);
  static const Color crimsonDeep    = Color(0xFFBE123C);

  // Compatibilité avec l'ancienne charte
  static const Color primary        = navy800;
  static const Color secondary      = orange;
  static const Color darkSlate      = navy900;
  static const Color navy           = navy800;

  // Surfaces
  static const Color background     = Color(0xFFF3F6FC);
  static const Color white          = Color(0xFFFFFFFF);
  static const Color cardBg         = Color(0xFFFFFFFF);
  static const Color surface        = Color(0xFFFFFFFF);
  static const Color surfaceSubtle  = Color(0xFFEFF3FA);
  static const Color border         = Color(0xFFE1E7F2);
  static const Color borderSubtle   = Color(0xFFF0F3F9);

  // Typographie
  static const Color textDark       = Color(0xFF0B1630);
  static const Color textGrey       = Color(0xFF5B6680); // AA sur blanc
  static const Color textMuted      = Color(0xFF8A94AB);

  // Statuts & utilitaires
  static const Color success        = Color(0xFF059669);
  static const Color emerald        = Color(0xFF059669);
  static const Color warning        = Color(0xFFD97706);
  static const Color info           = Color(0xFF2563EB);
  static const Color accentSenegal  = Color(0xFF00853F);

  // Niveaux d'alerte
  static const Color alertInfo      = Color(0xFF0284C7);
  static const Color alertVigilance = Color(0xFFD97706);
  static const Color alertDanger    = Color(0xFFEA580C);
  static const Color alertUrgence   = Color(0xFFE11D48);

  // Dégradés
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy900, navy800, navy700],
  );
  static const LinearGradient actionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blue600, navy700],
  );
  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEA580C), orangeDeep],
  );
  static const LinearGradient sosGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF43F5E), crimson, crimsonDeep],
  );
  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy700, navy900],
  );
}
