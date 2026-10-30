import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/format.dart';
import '../../core/location.dart';
import '../../state/configuration.dart';
import '../../ui/kit.dart';

const _fonds = {
  'plan': ('Plan', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', '© contributeurs OpenStreetMap'),
  'clair': ('Clair', 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}', 'Fond © Esri · © OpenStreetMap'),
  'satellite': ('Satellite', 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', 'Imagerie © Esri, Maxar'),
};

const _couleursNiveau = {'critique': AppColors.crimson, 'eleve': Color(0xFFEA580C), 'moyen': Color(0xFFD97706)};
const _couleursAlerte = {'danger': AppColors.crimson, 'vigilance': Color(0xFFF5D90A), 'info': AppColors.vert700};
const _couleursServices = {'hopital': AppColors.crimson, 'clinique': Color(0xFFEA580C), 'pharmacie': AppColors.success, 'police': AppColors.info, 'pompiers': Color(0xFFB45309)};

/// Carte à couches. Citoyen : vue publique ; agent : dossiers ouverts et SOS en plus.
class CarteScreen extends StatefulWidget {
  final bool agent;
  const CarteScreen({super.key, this.agent = false});
  @override
  State<CarteScreen> createState() => _CarteScreenState();
}

class _CarteScreenState extends State<CarteScreen> {
  final _carte = MapController();
  String _fond = 'clair';
  final Map<String, bool> _couches = {'incidents': true, 'risque': false, 'alertes': true, 'services': false, 'dossiers': true, 'sos': true};
  List<Map<String, dynamic>> _incidents = [], _dossiers = [], _sos = [], _niveaux = [], _alertes = [], _services = [];
  LatLng? _moi;
  ApiException? _erreur;
  bool _chargement = true;
  DateTime? _synchro;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<List<Map<String, dynamic>>> _liste(String chemin, Map<String, dynamic> p, String cle) async =>
      List<Map<String, dynamic>>.from((await Api.instance.get<Map<String, dynamic>>(chemin, params: p))[cle]);

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final r = await Future.wait([
        _liste('/incidents/carte/', {'jours': 30}, 'resultats'),
        _liste('/alertes/zones/', {'en_cours': 1}, 'results'),
        _liste('/analyse/niveaux-regions/', {}, 'zones'),
        if (widget.agent) _liste('/incidents/', {'actifs': true, 'taille': 100}, 'results'),
        if (widget.agent) _liste('/alertes/sos/', {'actifs': true, 'taille': 100}, 'results'),
      ]);
      _incidents = r[0]; _alertes = r[1]; _niveaux = r[2];
      if (widget.agent) { _dossiers = r[3]; _sos = r[4]; }
      _erreur = null;
      _synchro = DateTime.now();
    } on ApiException catch (e) {
      _erreur = e;
    }
    if (mounted) setState(() => _chargement = false);
  }

  Future<void> _localiser() async {
    final p = await Localisation.lire();
    if (!mounted) return;
    if (!p.ok) { afficherMessage(context, p.erreur ?? 'Position indisponible.', erreur: true); return; }
    setState(() => _moi = LatLng(p.lat!, p.lng!));
    _carte.move(_moi!, 14);
  }

  Future<void> _chargerServices() async {
    final c = _carte.camera.center;
    try {
      final r = await Api.instance.get<Map<String, dynamic>>('/services-proximite/', params: {'lat': c.latitude, 'lng': c.longitude, 'rayon': 5000});
      setState(() { _services = List<Map<String, dynamic>>.from(r['resultats']); _couches['services'] = true; });
      if (mounted) afficherMessage(context, '${_services.length} établissement(s) trouvé(s) autour du centre de la carte.');
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  Future<void> _rechercher() async {
    final ctrl = TextEditingController();
    final q = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Rechercher un lieu'),
      content: TextField(controller: ctrl, autofocus: true, textInputAction: TextInputAction.search,
          onSubmitted: (v) => Navigator.pop(c, v), decoration: const InputDecoration(hintText: 'Quartier, adresse, établissement…')),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Rechercher'))],
    ));
    if (q == null || q.trim().length < 3 || !mounted) return;
    try {
      final r = await Api.instance.get<Map<String, dynamic>>('/geocodage/', params: {'q': q.trim()});
      final res = List<Map<String, dynamic>>.from(r['resultats']);
      if (!mounted) return;
      if (res.isEmpty) { afficherMessage(context, 'Aucun lieu trouvé.', erreur: true); return; }
      final choix = res.length == 1 ? res.first : await showModalBottomSheet<Map<String, dynamic>>(context: context, builder: (c) => ListView(shrinkWrap: true, children: [
        for (final x in res) ListTile(leading: const Icon(Icons.place_outlined), title: Text(x['nom'], maxLines: 2, overflow: TextOverflow.ellipsis), onTap: () => Navigator.pop(c, x)),
      ]));
      if (choix != null) _carte.move(LatLng(choix['latitude'], choix['longitude']), 15);
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  void _panneau() => showModalBottomSheet(
        context: context,
        builder: (c) => StatefulBuilder(builder: (c, maj) {
          void bascule(String k, bool v) { setState(() => _couches[k] = v); maj(() {}); }
          return ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
            Text('Fond de carte', style: titre(16)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [for (final e in _fonds.entries) ButtonSegment(value: e.key, label: Text(e.value.$1))],
              selected: {_fond},
              onSelectionChanged: (s) { setState(() => _fond = s.first); maj(() {}); },
            ),
            const SizedBox(height: 12),
            Text('Couches', style: titre(16)),
            SwitchListTile(value: _couches['incidents']!, onChanged: (v) => bascule('incidents', v), title: Text('Incidents récents (${_incidents.length})')),
            SwitchListTile(value: _couches['risque']!, onChanged: (v) => bascule('risque', v), title: const Text('Zones à risque')),
            SwitchListTile(value: _couches['alertes']!, onChanged: (v) => bascule('alertes', v), title: Text('Alertes de zone (${_alertes.length})')),
            if (widget.agent) SwitchListTile(value: _couches['dossiers']!, onChanged: (v) => bascule('dossiers', v), title: Text('Dossiers ouverts (${_dossiers.length})')),
            if (widget.agent) SwitchListTile(value: _couches['sos']!, onChanged: (v) => bascule('sos', v), title: Text('SOS actifs (${_sos.length})')),
            SwitchListTile(value: _couches['services']!, onChanged: _services.isEmpty ? null : (v) => bascule('services', v), title: Text('Services proches (${_services.length})')),
            OutlinedButton.icon(onPressed: () { Navigator.pop(c); _chargerServices(); }, icon: const Icon(Icons.local_hospital_outlined), label: const Text('Charger les services autour du centre')),
            const SizedBox(height: 8),
            Text('L’absence d’incident ne signifie pas qu’une zone est sans danger. Positions publiques arrondies à ~100 m.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ]);
        }),
      );

  Marker _point(LatLng p, Color couleur, {double taille = 22, VoidCallback? onTap, String? label}) => Marker(
        point: p, width: taille + 8, height: taille + 8,
        child: Semantics(
          label: label,
          child: GestureDetector(onTap: onTap, child: Container(decoration: BoxDecoration(
            shape: BoxShape.circle, color: couleur, border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ))),
        ),
      );

  LatLng _ll(Map<String, dynamic> j) => LatLng((j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble());

  @override
  Widget build(BuildContext context) {
    final config = context.watch<Configuration>();
    final fond = _fonds[_fond]!;
    final marqueurs = <Marker>[
      if (_couches['incidents']!)
        for (final p in _incidents)
          _point(_ll(p), couleurHex(config.categorie(p['type_incident'])?.couleur), label: config.categorie(p['type_incident'])?.libelle, onTap: () => showModalBottomSheet(
            context: context, builder: (_) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(config.categorie(p['type_incident'])?.libelle ?? p['type_incident'], style: titre(18)),
              const SizedBox(height: 8),
              Row(children: [BadgeStatut(p['statut']), const SizedBox(width: 8), Text(dateHeure(lireDate(p['date_creation'])))]),
              const SizedBox(height: 8),
              Text('Position arrondie à ~100 m.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ])))),
      if (widget.agent && _couches['dossiers']!)
        for (final d in _dossiers.where((d) => d['latitude'] != null))
          _point(_ll(d), statut(d['statut']).couleur, taille: 26, label: d['reference'], onTap: () => context.push('/dossier/incident/${d['id']}')),
      if (widget.agent && _couches['sos']!)
        for (final d in _sos.where((d) => d['latitude'] != null))
          _point(_ll(d), AppColors.crimson, taille: 30, label: 'SOS ${d['reference']}', onTap: () => context.push('/dossier/sos/${d['id']}')),
      if (_couches['services']!)
        for (final s in _services)
          _point(_ll(s), _couleursServices[s['type']] ?? AppColors.textGrey, taille: 18, label: s['nom'], onTap: () => showModalBottomSheet(
            context: context, builder: (_) => ListTile(
              title: Text(s['nom'] ?? 'Nom non renseigné'), subtitle: Text('${s['type']} · ${distance(s['distance_m'])}'),
              trailing: IconButton(tooltip: 'Itinéraire', icon: const Icon(Icons.directions), onPressed: () => itineraire(s['latitude'], s['longitude'])),
            ))),
      if (_moi != null) Marker(point: _moi!, width: 24, height: 24, child: Container(decoration: BoxDecoration(
          shape: BoxShape.circle, color: AppColors.info, border: Border.all(color: Colors.white, width: 3)))),
    ];
    final cercles = <CircleMarker>[
      if (_couches['risque']!)
        for (final z in _niveaux.where((z) => _couleursNiveau.containsKey(z['niveau'])))
          CircleMarker(point: _ll(z), radius: z['niveau'] == 'critique' ? 32000 : z['niveau'] == 'eleve' ? 24000 : 16000, useRadiusInMeter: true,
              color: _couleursNiveau[z['niveau']]!.withOpacity(0.18), borderColor: _couleursNiveau[z['niveau']]!, borderStrokeWidth: 1.5),
      if (_couches['alertes']!)
        for (final a in _alertes)
          for (final code in (a['regions'] as List).isEmpty ? config.regions.map((r) => r.code) : List<String>.from(a['regions']))
            if (config.region(code) != null)
              CircleMarker(point: LatLng(config.region(code)!.lat, config.region(code)!.lng), radius: 40000, useRadiusInMeter: true,
                  color: (_couleursAlerte[a['niveau']] ?? AppColors.vert700).withOpacity(0.08), borderColor: _couleursAlerte[a['niveau']] ?? AppColors.vert700, borderStrokeWidth: 3),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.agent ? 'Carte opérationnelle' : 'Carte interactive'), actions: [
        IconButton(tooltip: 'Rechercher un lieu', onPressed: _rechercher, icon: const Icon(Icons.search)),
        IconButton(tooltip: 'Couches', onPressed: _panneau, icon: const Icon(Icons.layers_outlined)),
        IconButton(tooltip: 'Actualiser', onPressed: _charger, icon: const Icon(Icons.refresh)),
      ]),
      body: Stack(children: [
        FlutterMap(
          mapController: _carte,
          options: const MapOptions(initialCenter: LatLng(14.45, -14.9), initialZoom: 6.3),
          children: [
            TileLayer(key: ValueKey(_fond), urlTemplate: fond.$2, userAgentPackageName: 'com.senalert.senalert_mobile'),
            CircleLayer(circles: cercles),
            MarkerLayer(markers: marqueurs),
            RichAttributionWidget(attributions: [TextSourceAttribution(fond.$3)]),
          ],
        ),
        if (_chargement) const LinearProgressIndicator(),
        if (_erreur != null) Positioned(left: 12, right: 12, top: 12, child: Bandeau.erreur(_erreur!.message)),
        if (_alertes.isNotEmpty && _couches['alertes']!) Positioned(left: 12, right: 12, top: _erreur != null ? 90 : 12, child: Material(
          color: AppColors.jaune, borderRadius: BorderRadius.circular(14),
          child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
            const Icon(Icons.campaign_rounded),
            const SizedBox(width: 8),
            Expanded(child: Text('${_alertes.first['titre']}${_alertes.length > 1 ? ' (+${_alertes.length - 1})' : ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
          ])),
        )),
        Positioned(left: 12, bottom: 28, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.92), borderRadius: BorderRadius.circular(12)),
          child: Text(_synchro == null ? 'Non synchronisé' : 'Actualisé ${ilYa(_synchro)}', style: const TextStyle(fontSize: 12)),
        )),
      ]),
      floatingActionButton: FloatingActionButton(
        heroTag: 'localiser', tooltip: 'Me localiser', backgroundColor: AppColors.white, foregroundColor: AppColors.vert700,
        onPressed: _localiser, child: const Icon(Icons.my_location),
      ),
    );
  }
}
