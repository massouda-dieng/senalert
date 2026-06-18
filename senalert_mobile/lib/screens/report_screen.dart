import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  String _incidentType = 'Accident';
  Position? _currentPosition;
  GoogleMapController? _mapController;
  final LatLng _initialPosition = const LatLng(14.6937, -17.4441); // Dakar approx
  Marker? _currentMarker;

  final List<String> _incidentTypes = ['Accident', 'Incendie', 'Inondation', 'Urgence médicale'];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Fluttertoast.showToast(msg: 'Veuillez activer la localisation');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
      _currentMarker = Marker(
        markerId: const MarkerId('current'),
        position: LatLng(position.latitude, position.longitude),
      );
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
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
            'Authorization': 'Token $token',
          },
          body: jsonEncode({
            'type': _incidentType,
            'description': _descriptionController.text,
            'latitude': _currentPosition!.latitude,
            'longitude': _currentPosition!.longitude,
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
                SizedBox(
                  height: 300,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _initialPosition,
                      zoom: 12,
                    ),
                    markers: _currentMarker != null ? {_currentMarker!} : {},
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _incidentType,
                  decoration: const InputDecoration(
                    labelText: 'Type d\'incident',
                    border: OutlineInputBorder(),
                  ),
                  items: _incidentTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _incidentType = value!);
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
                const SizedBox(height: 20),
                // Photo upload placeholder
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                        Text('Ajouter une photo'),
                      ],
                    ),
                  ),
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
