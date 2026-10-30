import 'format.dart';

class Utilisateur {
  final int id;
  final String username;
  final String email;
  final String prenom;
  final String nom;
  final String telephone;
  final String region;
  final String role;
  final String roleLibelle;
  final Map<String, dynamic> preferences;
  final bool doitChangerMotDePasse;
  final bool aMotDePasse;
  final bool googleLie;
  final String? serviceNom;
  final List<String> zones;

  Utilisateur.depuis(Map<String, dynamic> j)
      : id = j['id'],
        username = j['username'] ?? '',
        email = j['email'] ?? '',
        prenom = j['first_name'] ?? '',
        nom = j['last_name'] ?? '',
        telephone = j['telephone'] ?? '',
        region = j['region'] ?? '',
        role = j['role'] ?? 'citoyen',
        roleLibelle = j['role_libelle'] ?? '',
        preferences = Map<String, dynamic>.from(j['preferences'] ?? {}),
        doitChangerMotDePasse = j['doit_changer_mot_de_passe'] == true,
        aMotDePasse = j['a_mot_de_passe'] != false,
        googleLie = j['google_lie'] == true,
        serviceNom = j['profil_agent']?['service_nom'],
        zones = List<String>.from(j['profil_agent']?['zones'] ?? const []);

  bool get estCitoyen => role == 'citoyen';
  bool get estAgent => role == 'agent';
  bool get estSuperadmin => role == 'superadmin';
  String get nomAffiche => prenom.isNotEmpty ? '$prenom $nom'.trim() : username;
}

class Categorie {
  final String code;
  final String libelle;
  final String couleur;
  final String? service;
  Categorie.depuis(Map<String, dynamic> j)
      : code = j['code'],
        libelle = j['libelle'],
        couleur = j['couleur'] ?? '#475569',
        service = j['service_defaut_nom'];
}

class Region {
  final String code;
  final String libelle;
  final double lat;
  final double lng;
  Region.depuis(Map<String, dynamic> j)
      : code = j['code'],
        libelle = j['libelle'],
        lat = (j['lat'] as num).toDouble(),
        lng = (j['lng'] as num).toDouble();
}

class NumeroUrgence {
  final String service;
  final String numero;
  NumeroUrgence.depuis(Map<String, dynamic> j)
      : service = j['service'],
        numero = j['numero'];
}

/// Incident ou alerte SOS (mêmes champs de suivi).
class Dossier {
  final int id;
  final bool estSos;
  final String reference;
  final String statut;
  final String gravite;
  final String? typeIncident;
  final String? categorieLibelle;
  final String description;
  final double? lat;
  final double? lng;
  final double? precision;
  final String region;
  final String regionLibelle;
  final String adresse;
  final String? serviceNom;
  final DateTime? creation;
  final DateTime? priseEnCharge;
  final DateTime? cloture;
  final String motifCloture;
  final bool enRetard;
  final bool estProprietaire;
  final Map<String, dynamic>? intervention;
  final Map<String, dynamic>? contact;
  final List<Map<String, dynamic>> photos;

  Dossier.depuis(Map<String, dynamic> j, {required this.estSos})
      : id = j['id'],
        reference = j['reference'] ?? '',
        statut = j['statut'] ?? 'nouveau',
        gravite = j['gravite'] ?? 'moyenne',
        typeIncident = j['type_incident'],
        categorieLibelle = j['categorie_libelle'],
        description = (j['description'] ?? j['message'] ?? '').toString(),
        lat = (j['latitude'] as num?)?.toDouble(),
        lng = (j['longitude'] as num?)?.toDouble(),
        precision = (j['precision_gps'] as num?)?.toDouble(),
        region = j['region'] ?? '',
        regionLibelle = j['region_libelle'] ?? '',
        adresse = j['adresse'] ?? '',
        serviceNom = j['service_nom'],
        creation = lireDate(j['date_creation']),
        priseEnCharge = lireDate(j['date_prise_en_charge']),
        cloture = lireDate(j['date_cloture']),
        motifCloture = j['motif_cloture'] ?? '',
        enRetard = j['en_retard'] == true,
        estProprietaire = j['est_proprietaire'] == true,
        intervention = j['intervention'] == null ? null : Map<String, dynamic>.from(j['intervention']),
        contact = j['citoyen_contact'] == null ? null : Map<String, dynamic>.from(j['citoyen_contact']),
        photos = List<Map<String, dynamic>>.from((j['photos'] ?? const []).map((p) => Map<String, dynamic>.from(p)));

  String get titre => estSos ? 'Alerte SOS' : (categorieLibelle ?? typeIncident ?? 'Incident');
  String get chemin => estSos ? '/alertes/sos/$id/' : '/incidents/$id/';
  bool get estClos => const {'resolu', 'refuse', 'annule'}.contains(statut);
  int? get agentId => intervention?['agent'];
}

class Evenement {
  final String type;
  final String statutApres;
  final String message;
  final String acteur;
  final bool visibleCitoyen;
  final DateTime? date;
  Evenement.depuis(Map<String, dynamic> j)
      : type = j['type'],
        statutApres = j['statut_apres'] ?? '',
        message = j['message'] ?? '',
        acteur = j['acteur_nom'] ?? '',
        visibleCitoyen = j['visible_citoyen'] != false,
        date = lireDate(j['date']);
}

class Page<T> {
  final int total;
  final List<T> elements;
  final bool suivante;
  Page(this.total, this.elements, this.suivante);
}
