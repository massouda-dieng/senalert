import 'package:flutter/material.dart';
import 'package:senalert_mobile/core/services/api_service.dart';
import 'package:senalert_mobile/core/constants/api_constants.dart';
import 'package:senalert_mobile/features/incidents/models/incident_model.dart';

class IncidentProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Incident> _incidents = [];
  bool _isLoading = false;
  String? _error;

  List<Incident> get incidents => _incidents;
  bool get isLoading           => _isLoading;
  String? get error            => _error;

  Future<void> fetchIncidents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.dio.get(ApiConstants.incidents);
      _incidents = (res.data as List).map((e) => Incident.fromJson(e)).toList();
    } catch (_) {
      _incidents = _demoData();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createIncident({
    required String type,
    required String description,
    required String location,
    required double latitude,
    required double longitude,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _api.dio.post(ApiConstants.incidents, data: {
        'type': type,
        'description': description,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
      });
      await fetchIncidents();
      return true;
    } catch (_) {
      _error = 'Erreur lors du signalement';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  List<Incident> _demoData() => [
        Incident(
          id: 1,
          type: 'Accident',
          description: 'Collision entre deux véhicules sur la route de Pikine',
          location: 'Pikine, Dakar',
          latitude: 14.7645,
          longitude: -17.3660,
          status: 'en_attente',
          date: '12 Mai 2024 à 14:30',
        ),
        Incident(
          id: 2,
          type: 'Incendie',
          description: 'Incendie dans un marché local',
          location: 'Guédiawaye',
          latitude: 14.7833,
          longitude: -17.4000,
          status: 'en_cours',
          date: '12 Mai 2024',
        ),
        Incident(
          id: 3,
          type: 'Inondation',
          description: 'Inondation suite aux fortes pluies',
          location: 'Keur Massar',
          latitude: 14.7500,
          longitude: -17.3333,
          status: 'en_attente',
          date: '12 Mai 2024',
        ),
        Incident(
          id: 4,
          type: 'Urgence médicale',
          description: 'Personne en malaise dans la rue',
          location: 'Dakar Plateau',
          latitude: 14.6928,
          longitude: -17.4467,
          status: 'traite',
          date: '12 Mai 2024',
        ),
      ];
}
