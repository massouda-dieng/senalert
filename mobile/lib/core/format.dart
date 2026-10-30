import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants/app_colors.dart';

class StatutInfo {
  final String libelle;
  final Color couleur;
  final Color fond;
  final IconData icone;
  const StatutInfo(this.libelle, this.couleur, this.fond, this.icone);
}

const statuts = <String, StatutInfo>{
  'nouveau': StatutInfo('Nouveau', Color(0xFF1D4ED8), Color(0xFFEEF3FF), Icons.fiber_new_rounded),
  'affecte': StatutInfo('Affecté', Color(0xFF6D28D9), Color(0xFFF3E8FF), Icons.assignment_ind_rounded),
  'accepte': StatutInfo('Pris en charge', Color(0xFF0369A1), Color(0xFFE0F2FE), Icons.how_to_reg_rounded),
  'en_cours': StatutInfo('En cours', Color(0xFFB45309), Color(0xFFFEF3C7), Icons.directions_run_rounded),
  'resolu': StatutInfo('Résolu', Color(0xFF047857), Color(0xFFD1FAE5), Icons.check_circle_rounded),
  'refuse': StatutInfo('Rejeté', Color(0xFF475569), Color(0xFFE2E8F0), Icons.block_rounded),
  'annule': StatutInfo('Annulé', Color(0xFF64748B), Color(0xFFF1F5F9), Icons.cancel_rounded),
};

StatutInfo statut(String code) =>
    statuts[code] ?? StatutInfo(code, AppColors.textGrey, AppColors.surfaceSubtle, Icons.info_outline);

const gravites = {'faible': 'Faible', 'moyenne': 'Moyenne', 'elevee': 'Élevée', 'critique': 'Critique'};

const iconesCategories = <String, IconData>{
  'accident': Icons.car_crash_rounded,
  'incendie': Icons.local_fire_department_rounded,
  'inondation': Icons.water_drop_rounded,
  'insecurite': Icons.gpp_maybe_rounded,
  'agression': Icons.front_hand_rounded,
  'electricite': Icons.bolt_rounded,
  'urgence_medicale': Icons.medical_services_rounded,
  'autre': Icons.more_horiz_rounded,
};

Color couleurHex(String? hex, [Color defaut = const Color(0xFF475569)]) {
  if (hex == null || !hex.startsWith('#') || hex.length != 7) return defaut;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

final _dateHeure = DateFormat('d MMM yyyy à HH:mm', 'fr_FR');
final _date = DateFormat('d MMM yyyy', 'fr_FR');

String dateHeure(DateTime? d) => d == null ? '—' : _dateHeure.format(d.toLocal());
String dateCourte(DateTime? d) => d == null ? '—' : _date.format(d.toLocal());

String ilYa(DateTime? d) {
  if (d == null) return '—';
  final s = DateTime.now().difference(d).inSeconds;
  if (s < 60) return 'à l’instant';
  if (s < 3600) return 'il y a ${s ~/ 60} min';
  if (s < 86400) return 'il y a ${s ~/ 3600} h';
  if (s < 172800) return 'hier';
  return 'il y a ${s ~/ 86400} j';
}

String distance(num? m) =>
    m == null ? '—' : m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

DateTime? lireDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
