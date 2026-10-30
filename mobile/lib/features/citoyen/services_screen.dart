import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/format.dart';
import '../../core/location.dart';
import '../../ui/kit.dart';

const _types = {
  'hopital': ('Hôpitaux', Icons.local_hospital_rounded, Color(0xFFE11D48)),
  'clinique': ('Cliniques', Icons.medical_services_rounded, Color(0xFFEA580C)),
  'pharmacie': ('Pharmacies', Icons.local_pharmacy_rounded, Color(0xFF059669)),
  'police': ('Police', Icons.local_police_rounded, Color(0xFF1D4ED8)),
  'pompiers': ('Pompiers', Icons.fire_truck_rounded, Color(0xFFB45309)),
};

/// Établissements réels issus d'OpenStreetMap (via le backend). Aucune donnée inventée.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String? _type;
  Position2? _position;
  Map<String, dynamic>? _donnees;
  String? _erreur;
  bool _chargement = false;

  Future<void> _chercher() async {
    setState(() { _chargement = true; _erreur = null; });
    _position = _position?.ok == true ? _position : await Localisation.lire();
    if (_position?.ok != true) {
      setState(() { _erreur = _position?.erreur; _chargement = false; });
      return;
    }
    try {
      _donnees = await Api.instance.get('/services-proximite/', params: {'lat': _position!.lat, 'lng': _position!.lng, 'rayon': 10000, 'type': _type});
    } on ApiException catch (e) {
      _erreur = e.message;
    }
    if (mounted) setState(() => _chargement = false);
  }

  @override
  Widget build(BuildContext context) {
    final resultats = List<Map<String, dynamic>>.from(_donnees?['resultats'] ?? const []);
    return Scaffold(
      appBar: AppBar(title: const Text('Services de proximité')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, children: [
          Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: const Text('Tous'), selected: _type == null, onSelected: (_) { setState(() => _type = null); if (_donnees != null) _chercher(); })),
          for (final e in _types.entries) Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
            avatar: Icon(e.value.$2, size: 16), label: Text(e.value.$1), selected: _type == e.key,
            onSelected: (_) { setState(() => _type = e.key); if (_donnees != null) _chercher(); })),
        ])),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _chargement ? null : _chercher, icon: const Icon(Icons.my_location),
            label: Text(_donnees == null ? 'Rechercher autour de moi' : 'Actualiser')),
        const SizedBox(height: 6),
        Text('Votre position est arrondie (~1 km) avant d’interroger OpenStreetMap.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        if (_chargement) const Chargement(),
        if (_erreur != null) Padding(padding: const EdgeInsets.only(top: 12), child: Bandeau.erreur(_erreur!,
            action: _position?.reglagesRequis == true ? const TextButton(onPressed: Localisation.ouvrirReglages, child: Text('Ouvrir les réglages')) : null)),
        if (_donnees != null && !_chargement) ...[
          const SizedBox(height: 12),
          if (resultats.isEmpty) const Bandeau('Aucun établissement référencé dans un rayon de 10 km.'),
          for (final s in resultats) Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Carte(child: Row(children: [
              Icon(_types[s['type']]!.$2, color: _types[s['type']]!.$3),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s['nom'] ?? 'Nom non renseigné', style: TextStyle(fontWeight: FontWeight.w700, fontStyle: s['nom'] == null ? FontStyle.italic : null)),
                Text('${_types[s['type']]!.$1} · ${distance(s['distance_m'])}${s['horaires'] != null ? ' · ${s['horaires']}' : ''}',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
              ])),
              if (s['telephone'] != null) IconButton(tooltip: 'Appeler', onPressed: () => appeler(s['telephone']), icon: const Icon(Icons.call_rounded, color: AppColors.success)),
              IconButton(tooltip: 'Itinéraire', onPressed: () => itineraire(s['latitude'], s['longitude']), icon: const Icon(Icons.directions_rounded, color: AppColors.vert600)),
            ])),
          ),
          Text('${_donnees!['source']} · données du ${dateHeure(lireDate(_donnees!['donnees_du']))}${_donnees!['donnees_anciennes'] == true ? ' (serveurs OpenStreetMap saturés : derniers résultats connus)' : ''}. ${_donnees!['avertissement']}',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ],
      ]),
    );
  }
}
