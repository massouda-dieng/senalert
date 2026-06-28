import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _incidentType = 'accident';
  String _region = 'dakar';
  Position? _currentPosition;
  bool _gpsLoading = false;
  final MapController _mapController = MapController();

  final LatLng _defaultPosition = const LatLng(14.6937, -17.4441); // Dakar

  final Map<String, String> _incidentTypes = {
    'accident': 'Accident',
    'incendie': 'Incendie',
    'inondation': 'Inondation',
    'electricite': 'Coupure électricité',
    'insecurite': 'Insécurité',
    'autre': 'Autre',
  };

  final List<String> _regions = [
    'dakar', 'thies', 'saint_louis', 'kaolack', 'ziguinchor',
    'tambacounda', 'louga', 'fatick', 'kolda', 'matam',
    'diourbel', 'kaffrine', 'sedhiou', 'kedougou',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _gpsLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Fluttertoast.showToast(msg: 'Veuillez activer la localisation');
        setState(() => _gpsLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _gpsLoading = false;
      });
      _mapController.move(LatLng(position.latitude, position.longitude), 14);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Impossible de récupérer la position');
      setState(() => _gpsLoading = false);
    }
  }

  Future<void> _sendAlert() async {
    if (_currentPosition == null) {
      Fluttertoast.showToast(msg: 'Localisation non disponible');
      return;
    }

    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        Fluttertoast.showToast(msg: 'Vous devez être connecté');
        return;
      }

      try {
        final response = await http.post(
          Uri.parse('http://127.0.0.1:8000/api/incidents/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'type_incident': _incidentType,
            'description': _descriptionController.text,
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
            'region': _region,
            'statut': 'nouveau',
          }),
        );

        if (response.statusCode == 201) {
          Fluttertoast.showToast(msg: 'Alerte envoyée avec succès !');
          _descriptionController.clear();
        } else {
          Fluttertoast.showToast(msg: 'Erreur: ${response.statusCode}');
        }
      } catch (e) {
        Fluttertoast.showToast(msg: 'Erreur de connexion');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : _defaultPosition;

    return Scaffold(
      appBar: AppBar(title: const Text('Signaler une urgence')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 250,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: position,
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.senalert.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: position,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on,
                                  color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.gps_fixed,
                        color: _currentPosition != null ? Colors.green : Colors.grey,
                        size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _gpsLoading
                            ? 'Localisation en cours...'
                            : _currentPosition != null
                                ? '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}'
                                : 'Position non disponible',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    TextButton(
                      onPressed: _getCurrentLocation,
                      child: const Text('Actualiser'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _incidentType,
                  decoration: const InputDecoration(
                    labelText: 'Type d\'incident',
                    border: OutlineInputBorder(),
                  ),
                  items: _incidentTypes.entries.map((e) {
                    return DropdownMenuItem(value: e.key, child: Text(e.value));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _incidentType = value!);
                  },
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _region,
                  decoration: const InputDecoration(
                    labelText: 'Région',
                    border: OutlineInputBorder(),
                  ),
                  items: _regions.map((r) {
                    return DropdownMenuItem(value: r, child: Text(r));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _region = value!);
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Décrivez ce qui s\'est passé...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value!.isEmpty ? 'Veuillez décrire l\'incident' : null,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _sendAlert,
                    child: const Text('ENVOYER L\'ALERTE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
