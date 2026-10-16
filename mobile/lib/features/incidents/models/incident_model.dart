class Incident {
  final int id;
  final String type;
  final String description;
  final String location;
  final double latitude;
  final double longitude;
  final String status;
  final String date;
  final String? photo;
  final String? eta;
  final String? responderInfo;

  Incident({
    required this.id,
    required this.type,
    required this.description,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.date,
    this.photo,
    this.eta,
    this.responderInfo,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    final rawType = json['type_incident'] ?? json['type'] ?? 'Accident';
    final rawStatus = json['statut'] ?? json['status'] ?? 'en_attente';
    final rawLocation = json['location'] ?? json['region'] ?? json['lieu'] ?? 'Dakar';
    final rawDate = json['date_creation'] ?? json['created_at'] ?? json['date'] ?? '';

    String formattedDate = rawDate.toString();
    if (formattedDate.contains('T')) {
      formattedDate = formattedDate.split('T')[0];
    }

    return Incident(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      type: rawType.toString(),
      description: json['description']?.toString() ?? '',
      location: rawLocation.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      status: rawStatus.toString(),
      date: formattedDate,
      photo: json['photo']?.toString(),
      eta: json['eta']?.toString(),
      responderInfo: json['responder_info']?.toString(),
    );
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'nouveau':
      case 'en_attente': return '⏳ En attente de confirmation';
      case 'en_cours':   return eta != null ? '🚒 Urgence Acceptée (Arrivée : $eta)' : '🚒 Urgence Acceptée / En route';
      case 'refuse':     return '❌ Alerte Classée / Refusée';
      case 'resolu':
      case 'traite':     return '✓ Traitée par les secours';
      default:           return status;
    }
  }

  String get typeIcon {
    final t = type.toLowerCase();
    if (t.contains('accident')) return '🚗';
    if (t.contains('incendie')) return '🔥';
    if (t.contains('inondation')) return '🌊';
    if (t.contains('urgence') || t.contains('medical')) return '🏥';
    if (t.contains('electricite')) return '⚡';
    if (t.contains('insecu') || t.contains('vol') || t.contains('crime')) return '⚠️';
    return '📋';
  }
}
