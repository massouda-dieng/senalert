import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  List<dynamic> _incidents = [];
  bool _isLoading = true;

  final Map<String, String> _typeLabels = {
    'accident': 'Accident',
    'incendie': 'Incendie',
    'inondation': 'Inondation',
    'electricite': 'Coupure électricité',
    'insecurite': 'Insécurité',
    'autre': 'Autre',
  };

  final Map<String, String> _statutLabels = {
    'nouveau': 'Nouveau',
    'en_cours': 'En cours',
    'resolu': 'Résolu',
  };

  final Map<String, Color> _typeColors = {
    'accident': Colors.red,
    'incendie': Colors.deepOrange,
    'inondation': Colors.blue,
    'electricite': Colors.amber,
    'insecurite': Colors.purple,
    'autre': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _fetchIncidents();
  }

  Future<void> _fetchIncidents() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/incidents/'),
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode == 200) {
        setState(() {
          _incidents = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Marker> _buildMarkers() {
    return _incidents
        .where((inc) => inc['latitude'] != null && inc['longitude'] != null)
        .map((incident) {
      final type = incident['type_incident'] ?? 'autre';
      final color = _typeColors[type] ?? Colors.grey;
      return Marker(
        point: LatLng(
          double.parse(incident['latitude'].toString()),
          double.parse(incident['longitude'].toString()),
        ),
        width: 40,
        height: 40,
        child: GestureDetector(
          onTap: () => _showDetail(incident),
          child: Icon(Icons.location_on, color: color, size: 36),
        ),
      );
    }).toList();
  }

  void _showDetail(dynamic incident) {
    final type = incident['type_incident'] ?? 'autre';
    final statut = incident['statut'] ?? 'nouveau';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_typeLabels[type] ?? type),
        content: Text(
          '${incident['description'] ?? ''}\n\n'
          'Région : ${incident['region'] ?? ''}\n'
          'Statut : ${_statutLabels[statut] ?? statut}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Carte des incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchIncidents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: FlutterMap(
                    options: const MapOptions(
                      initialCenter: LatLng(14.6937, -17.4441),
                      initialZoom: 7,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.senalert.app',
                      ),
                      MarkerLayer(markers: _buildMarkers()),
                    ],
                  ),
                ),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(8.0),
                  child: _incidents.isEmpty
                      ? const Center(child: Text('Aucun incident'))
                      : ListView.builder(
                          itemCount: _incidents.length,
                          itemBuilder: (context, index) {
                            final incident = _incidents[index];
                            final type = incident['type_incident'] ?? 'autre';
                            final statut = incident['statut'] ?? 'nouveau';
                            return Card(
                              child: ListTile(
                                leading: Icon(Icons.warning,
                                    color: _typeColors[type] ?? Colors.grey),
                                title: Text(_typeLabels[type] ?? type),
                                subtitle: Text(incident['description'] ?? ''),
                                trailing: Text(_statutLabels[statut] ?? statut),
                                onTap: () => _showDetail(incident),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
