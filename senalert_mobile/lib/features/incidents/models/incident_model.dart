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
  });

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
        id: json['id'],
        type: json['type'] ?? '',
        description: json['description'] ?? '',
        location: json['location'] ?? '',
        latitude: double.tryParse(json['latitude'].toString()) ?? 0.0,
        longitude: double.tryParse(json['longitude'].toString()) ?? 0.0,
        status: json['status'] ?? 'en_attente',
        date: json['created_at'] ?? '',
        photo: json['photo'],
      );

  String get statusLabel {
    switch (status) {
      case 'en_attente': return 'En attente';
      case 'en_cours':   return 'En cours';
      case 'traite':     return 'Traitée';
      default:           return status;
    }
  }

  String get typeIcon {
    switch (type.toLowerCase()) {
      case 'accident':         return '🚗';
      case 'incendie':         return '🔥';
      case 'inondation':       return '🌊';
      case 'urgence médicale': return '🏥';
      default:                 return '⚠️';
    }
  }
}
