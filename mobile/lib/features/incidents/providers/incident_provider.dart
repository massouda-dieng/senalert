import 'package:flutter/material.dart';
import 'package:senalert_mobile/core/services/api_service.dart';
import 'package:senalert_mobile/core/constants/api_constants.dart';
import 'package:senalert_mobile/features/incidents/models/incident_model.dart';

class IncidentProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Incident> _incidents = [];
  final List<Incident> _userCreatedIncidents = [];
  bool _isLoading = false;
  String? _error;

  List<Incident> get incidents => _incidents;
  bool get isLoading          => _isLoading;
  String? get error            => _error;

  IncidentProvider() {
    fetchIncidents();
  }

  Future<void> fetchIncidents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    List<Incident> fetchedList = [];
    try {
      final res = await _api.dio.get(ApiConstants.incidents);
      fetchedList = (res.data as List).map((e) => Incident.fromJson(e)).toList();
    } catch (_) {
      fetchedList = _demoData();
    }

    // Fusionner les alertes créées par l'utilisateur tout en haut de la liste
    final Map<int, Incident> map = {};
    for (var item in _userCreatedIncidents) {
      map[item.id] = item;
    }
    for (var item in fetchedList) {
      if (!map.containsKey(item.id)) {
        map[item.id] = item;
      }
    }

    _incidents = map.values.toList();
    _isLoading = false;
    notifyListeners();
  }

  /// Convertit un libellé affiché (ex. « Urgence médicale ») en code backend
  /// accepté par Incident.TYPE_CHOICES.
  static String typeToApi(String label) {
    final t = _normalize(label);
    if (t.contains('accident')) return 'accident';
    if (t.contains('incendie')) return 'incendie';
    if (t.contains('inondation')) return 'inondation';
    if (t.contains('electricite') || t.contains('panne')) return 'electricite';
    if (t.contains('insecurite') || t.contains('vol')) return 'insecurite';
    if (t.contains('medical')) return 'urgence_medicale';
    return 'autre';
  }

  /// Convertit un nom de région (ex. « Saint-Louis ») en code backend.
  static String regionToApi(String label) =>
      _normalize(label).replaceAll('-', '_').replaceAll(' ', '_');

  static String _normalize(String s) {
    const accents = {'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'à': 'a', 'â': 'a',
      'î': 'i', 'ï': 'i', 'ô': 'o', 'ù': 'u', 'û': 'u', 'ç': 'c'};
    var r = s.toLowerCase().trim();
    accents.forEach((k, v) => r = r.replaceAll(k, v));
    return r;
  }

  String? lastError;

  Future<bool> createIncident({
    required String type,
    required String region,
    required String description,
    required String location,
    required double latitude,
    required double longitude,
  }) async {
    _isLoading = true;
    lastError = null;
    notifyListeners();

    try {
      await _api.dio.post(ApiConstants.incidents, data: {
        'type_incident': typeToApi(type),
        'region': regionToApi(region),
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
      });
    } catch (e) {
      // Échec réel : on ne simule pas un succès
      lastError = 'Envoi impossible. Vérifiez votre connexion et réessayez.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _userCreatedIncidents.insert(0, Incident(
      id: DateTime.now().millisecondsSinceEpoch,
      type: type,
      description: description,
      location: location,
      latitude: latitude,
      longitude: longitude,
      status: 'nouveau',
      date: 'À l\'instant',
    ));

    await fetchIncidents();
    return true;
  }

  Future<bool> updateIncidentStatus(int id, String newStatus, {String? eta, String? responderInfo}) {
    // Mettre à jour dans _userCreatedIncidents si présent
    final uIdx = _userCreatedIncidents.indexWhere((i) => i.id == id);
    if (uIdx != -1) {
      final old = _userCreatedIncidents[uIdx];
      _userCreatedIncidents[uIdx] = Incident(
        id: old.id,
        type: old.type,
        description: old.description,
        location: old.location,
        latitude: old.latitude,
        longitude: old.longitude,
        status: newStatus,
        date: old.date,
        photo: old.photo,
        eta: eta ?? old.eta,
        responderInfo: responderInfo ?? old.responderInfo,
      );
    }

    final idx = _incidents.indexWhere((i) => i.id == id);
    if (idx != -1) {
      final old = _incidents[idx];
      _incidents[idx] = Incident(
        id: old.id,
        type: old.type,
        description: old.description,
        location: old.location,
        latitude: old.latitude,
        longitude: old.longitude,
        status: newStatus,
        date: old.date,
        photo: old.photo,
        eta: eta ?? old.eta,
        responderInfo: responderInfo ?? old.responderInfo,
      );
      notifyListeners();
    }

    return _syncStatusToServer(id, newStatus);
  }

  /// Statuts mobile → statuts backend (Incident.STATUT_CHOICES).
  static String? statusToApi(String s) {
    switch (s) {
      case 'refuse':
        return 'refuse';
      case 'en_attente':
      case 'nouveau':
        return 'nouveau';
      case 'en_cours':
        return 'en_cours';
      case 'traite':
      case 'resolu':
        return 'resolu';
      default:
        return null;
    }
  }

  Future<bool> _syncStatusToServer(int id, String newStatus) async {
    final apiStatus = statusToApi(newStatus);
    if (apiStatus == null) return false;
    try {
      await _api.dio.patch('${ApiConstants.incidents}$id/', data: {'statut': apiStatus});
      return true;
    } catch (_) {
      lastError = 'Statut mis à jour localement, mais pas sur le serveur.';
      notifyListeners();
      return false;
    }
  }

  List<Incident> _demoData() => [
        Incident(
          id: 1,
          type: 'Accident',
          description: 'Collision grave entre un car Ndiaga Ndiaye et un taxi',
          location: 'Dakar - Autoroute à Péage, Sortie Pikine',
          latitude: 14.75,
          longitude: -17.39,
          status: 'en_attente',
          date: 'Il y a 10 min',
        ),
        Incident(
          id: 2,
          type: 'Incendie',
          description: 'Départ de feu dans un magasin au marché Sandaga',
          location: 'Dakar - Marché Sandaga, Centre Ville',
          latitude: 14.67,
          longitude: -17.43,
          status: 'en_cours',
          date: 'Il y a 25 min',
          eta: '7 min',
          responderInfo: 'Capitaine Faye (Sapeurs-Pompiers)',
        ),
        Incident(
          id: 3,
          type: 'Inondation',
          description: 'Montée des eaux importante suite aux pluies à la Cité Lamy',
          location: 'Thiès - Cité Lamy',
          latitude: 14.78,
          longitude: -16.93,
          status: 'en_attente',
          date: 'Il y a 1h',
        ),
      ];
}
