import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchIncidents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _incidents.isEmpty
              ? const Center(child: Text('Aucun incident pour le moment'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _incidents.length,
                  itemBuilder: (context, index) {
                    final incident = _incidents[index];
                    final type = incident['type_incident'] ?? 'autre';
                    final statut = incident['statut'] ?? 'nouveau';
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.warning, color: Colors.red),
                        title: Text(_typeLabels[type] ?? type),
                        subtitle: Text(
                          '${incident['description'] ?? ''}\n📍 ${incident['region'] ?? ''}',
                        ),
                        isThreeLine: true,
                        trailing: Text(_statutLabels[statut] ?? statut),
                        onTap: () {
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
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
