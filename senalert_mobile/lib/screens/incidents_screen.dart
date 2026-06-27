import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class IncidentsScreen extends StatefulWidget {
  const IncidentsScreen({super.key});

  @override
  State<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends State<IncidentsScreen> {
  List<dynamic> _incidents = [];
  bool _isLoading = true;

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
        headers: token != null ? {'Authorization': 'Token $token'} : {},
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
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(14.6937, -17.4441),
                      zoom: 10,
                    ),
                    markers: _buildMarkers(),
                  ),
                ),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    itemCount: _incidents.length,
                    itemBuilder: (context, index) {
                      final incident = _incidents[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.warning, color: Colors.red),
                          title: Text(incident['type'] ?? 'Incident'),
                          subtitle: Text(incident['description'] ?? ''),
                          trailing: Text(incident['status'] ?? 'En attente'),
                          onTap: () {
                            // Show details
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(incident['type'] ?? ''),
                                content: Text(incident['description'] ?? ''),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Set<Marker> _buildMarkers() {
    return _incidents
        .where((inc) => inc['latitude'] != null && inc['longitude'] != null)
        .map((incident) {
          return Marker(
            markerId: MarkerId(incident['id'].toString()),
            position: LatLng(incident['latitude'], incident['longitude']),
            infoWindow: InfoWindow(
              title: incident['type'],
              snippet: incident['description'],
            ),
          );
        })
        .toSet();
  }
}
