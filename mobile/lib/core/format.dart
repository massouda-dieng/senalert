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
  'nouveau': StatutInfo('Nouveau', Jetons.statutNouveau, Jetons.statutNouveauFond, Icons.fiber_new_rounded),
  'affecte': StatutInfo('Affecté', Jetons.statutAffecte, Jetons.statutAffecteFond, Icons.assignment_ind_rounded),
  'accepte': StatutInfo('Pris en charge', Jetons.statutAccepte, Jetons.statutAccepteFond, Icons.how_to_reg_rounded),
  'en_cours': StatutInfo('En cours', Jetons.statutEnCours, Jetons.statutEnCoursFond, Icons.directions_run_rounded),
  'resolu': StatutInfo('Résolu', Jetons.statutResolu, Jetons.statutResoluFond, Icons.check_circle_rounded),
  'refuse': StatutInfo('Rejeté', Jetons.statutRefuse, Jetons.statutRefuseFond, Icons.block_rounded),
  'annule': StatutInfo('Annulé', Jetons.statutAnnule, Jetons.statutAnnuleFond, Icons.cancel_rounded),
};

StatutInfo statut(String code) =>
    statuts[code] ?? StatutInfo(code, AppColors.textGrey, AppColors.surfaceSubtle, Icons.info_outline);

const gravites = {'faible': 'Faible', 'moyenne': 'Moyenne', 'elevee': 'Élevée', 'critique': 'Critique'};

/// Du plus urgent au moins urgent : ordre d'affichage des missions.
const ordreGravite = ['critique', 'elevee', 'moyenne', 'faible'];
int rangGravite(String? g) { final i = ordreGravite.indexOf(g ?? ''); return i < 0 ? ordreGravite.length : i; }

const couleursGravite = <String, Color>{
  'critique': Jetons.graviteCritique, 'elevee': Jetons.graviteElevee, 'moyenne': Jetons.graviteMoyenne, 'faible': Jetons.graviteFaible,
};

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

Color couleurHex(String? hex, [Color defaut = Jetons.gris]) {
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
