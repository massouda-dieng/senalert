class AlertModel {
  final String id;
  final String type;
  final String description;
  final String location;
  final String date;
  final String status;
  final double? latitude;
  final double? longitude;

  const AlertModel({
    required this.id,
    required this.type,
    required this.description,
    required this.location,
    required this.date,
    required this.status,
    this.latitude,
    this.longitude,
  });

  String get statusLabel {
    switch (status) {
      case 'pending': return 'En attente';
      case 'in_progress': return 'En cours';
      case 'resolved': return 'Traitée';
      default: return 'En attente';
    }
  }
}

// Sample data
final List<AlertModel> sampleAlerts = [
  AlertModel(
    id: '1',
    type: 'Accident',
    description: 'Collision entre deux véhicules sur la route de Pikine.',
    location: 'Pikine, Dakar',
    date: '12 Mai 2024 à 14:30',
    status: 'pending',
    latitude: 14.7645,
    longitude: -17.3907,
  ),
  AlertModel(
    id: '2',
    type: 'Incendie',
    description: 'Incendie dans un bâtiment résidentiel.',
    location: 'Guédiawaye',
    date: '12 Mai 2024',
    status: 'in_progress',
    latitude: 14.7725,
    longitude: -17.3888,
  ),
  AlertModel(
    id: '3',
    type: 'Inondation',
    description: 'Route inondée après fortes pluies.',
    location: 'Keur Massar',
    date: '12 Mai 2024',
    status: 'pending',
    latitude: 14.7800,
    longitude: -17.3500,
  ),
  AlertModel(
    id: '4',
    type: 'Urgence médicale',
    description: 'Patient nécessitant une intervention rapide.',
    location: 'Dakar Plateau',
    date: '12 Mai 2024',
    status: 'resolved',
    latitude: 14.6928,
    longitude: -17.4467,
  ),
];
