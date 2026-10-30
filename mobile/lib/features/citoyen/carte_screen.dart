import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/format.dart';
import '../../state/configuration.dart';
import '../../ui/kit.dart';

/// Carte : vue publique minimale (citoyen) ou dossiers ouverts accessibles (agent).
class CarteScreen extends StatefulWidget {
  final bool agent;
  const CarteScreen({super.key, this.agent = false});
  @override
  State<CarteScreen> createState() => _CarteScreenState();
}

class _CarteScreenState extends State<CarteScreen> {
  List<Map<String, dynamic>> _points = [];
  ApiException? _erreur;
  bool _chargement = true;
  String _jours = '30';
  DateTime? _synchro;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      if (widget.agent) {
        final inc = await Api.instance.get<Map<String, dynamic>>('/incidents/', params: {'actifs': true, 'taille': 100});
        final sos = await Api.instance.get<Map<String, dynamic>>('/alertes/sos/', params: {'actifs': true, 'taille': 100});
        _points = [
          for (final j in inc['results']) {...Map<String, dynamic>.from(j), '_sos': false},
          for (final j in sos['results']) {...Map<String, dynamic>.from(j), '_sos': true},
        ].where((p) => p['latitude'] != null).toList();
      } else {
        final r = await Api.instance.get<Map<String, dynamic>>('/incidents/carte/', params: {'jours': _jours});
        _points = List<Map<String, dynamic>>.from(r['resultats']);
      }
      _erreur = null;
      _synchro = DateTime.now();
    } on ApiException catch (e) {
      _erreur = e;
    }
    if (mounted) setState(() => _chargement = false);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<Configuration>();
    return Scaffold(
      appBar: AppBar(title: Text(widget.agent ? 'Carte opérationnelle' : 'Carte des incidents'), actions: [
        if (!widget.agent) PopupMenuButton<String>(
          tooltip: 'Période', icon: const Icon(Icons.date_range), initialValue: _jours,
          onSelected: (v) { _jours = v; _charger(); },
          itemBuilder: (_) => [for (final j in ['7', '30', '90']) PopupMenuItem(value: j, child: Text('$j derniers jours'))],
        ),
        IconButton(tooltip: 'Actualiser', onPressed: _charger, icon: const Icon(Icons.refresh)),
      ]),
      body: Stack(children: [
        FlutterMap(
          options: const MapOptions(initialCenter: LatLng(14.45, -14.9), initialZoom: 6.3),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'sn.senalert.mobile'),
            MarkerLayer(markers: [
              for (final p in _points)
                Marker(
                  point: LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()),
                  width: 30, height: 30,
                  child: GestureDetector(
                    onTap: () => widget.agent
                        ? context.push('/dossier/${p['_sos'] == true ? 'sos' : 'incident'}/${p['id']}')
                        : showModalBottomSheet(context: context, builder: (_) => Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(config.categorie(p['type_incident'])?.libelle ?? p['type_incident'], style: titre(18)),
                              const SizedBox(height: 8),
                              Row(children: [BadgeStatut(p['statut']), const SizedBox(width: 8), Text(dateHeure(lireDate(p['date_creation'])))]),
                              const SizedBox(height: 8),
                              const Text('Position arrondie à ~100 m pour protéger la vie privée.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            ]))),
                    child: Semantics(
                      label: p['_sos'] == true ? 'Alerte SOS' : (config.categorie(p['type_incident'])?.libelle ?? 'Incident'),
                      child: Container(decoration: BoxDecoration(
                        shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2.5),
                        color: p['_sos'] == true ? AppColors.crimson
                            : widget.agent ? statut(p['statut']).couleur : couleurHex(config.categorie(p['type_incident'])?.couleur),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      )),
                    ),
                  ),
                ),
            ]),
            const RichAttributionWidget(attributions: [TextSourceAttribution('© contributeurs OpenStreetMap')]),
          ],
        ),
        if (_chargement) const LinearProgressIndicator(),
        if (_erreur != null) Positioned(left: 12, right: 12, top: 12, child: Bandeau.erreur(_erreur!.message)),
        Positioned(left: 12, bottom: 28, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(12)),
          child: Text('${_points.length} point(s) · ${_synchro == null ? 'non synchronisé' : 'actualisé ${ilYa(_synchro)}'}', style: const TextStyle(fontSize: 12)),
        )),
      ]),
    );
  }
}
