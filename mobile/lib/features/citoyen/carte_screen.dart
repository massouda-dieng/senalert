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
import '../../ui/selecteur_position.dart';

/// Cadre de la carte nationale : le Sénégal et ses frontières.
final _bornes = LatLngBounds(const LatLng(9, -22), const LatLng(20, -7));
const _centreSenegal = LatLng(14.45, -14.9);

/// Carte simple : ma position, la recherche d'un lieu et, au choix, les structures d'un service les plus
/// proches (liste triée par distance). Citoyen : incidents récents publics ; agent : ses dossiers et SOS en plus.
class CarteScreen extends StatefulWidget {
  final bool agent;
  const CarteScreen({super.key, this.agent = false});
  @override
  State<CarteScreen> createState() => _CarteScreenState();
}

class _CarteScreenState extends State<CarteScreen> {
  final _carte = MapController();
  bool _cartePrete = false;
  List<Map<String, dynamic>> _incidents = [], _dossiers = [], _sos = [], _alertes = [];
  List<Map<String, dynamic>>? _structures;
  int? _service;
  LatLng? _moi;
  ApiException? _erreur;
  bool _chargement = true;
  bool _localisation = false;

  @override
  void initState() {
    super.initState();
    _charger();
    _localiser(auto: true);
  }

  Future<List<Map<String, dynamic>>> _liste(String chemin, Map<String, dynamic> p, String cle) async =>
      List<Map<String, dynamic>>.from((await Api.instance.get<Map<String, dynamic>>(chemin, params: p))[cle]);

  Future<void> _charger() async {
    setState(() => _chargement = true);
    try {
      final r = await Future.wait([
        _liste('/incidents/carte/', {'jours': 30}, 'resultats'),
        _liste('/alertes/zones/', {'en_cours': 1}, 'results'),
        if (widget.agent) _liste('/incidents/', {'actifs': true, 'taille': 100}, 'results'),
        if (widget.agent) _liste('/alertes/sos/', {'actifs': true, 'taille': 100}, 'results'),
      ]);
      _incidents = r[0]; _alertes = r[1];
      if (widget.agent) { _dossiers = r[2]; _sos = r[3]; }
      _erreur = null;
    } on ApiException catch (e) {
      _erreur = e;
    }
    if (mounted) setState(() => _chargement = false);
  }

  void _aller(LatLng p, double zoom) { if (_cartePrete) _carte.move(p, zoom); }

  /// `auto` : tentative à l'ouverture, sans message si la position est refusée (la carte reste utilisable).
  Future<void> _localiser({bool auto = false}) async {
    setState(() => _localisation = true);
    final p = await Localisation.lire();
    if (!mounted) return;
    setState(() => _localisation = false);
    if (!p.ok) {
      if (!auto) afficherMessage(context, '${p.erreur ?? 'Position indisponible.'} Recherchez un lieu ou déplacez la carte.', erreur: true);
      return;
    }
    final position = LatLng(p.lat!, p.lng!);
    if (!_bornes.contains(position)) {
      if (!auto) afficherMessage(context, 'Votre position est hors du Sénégal.', erreur: true);
      return;
    }
    setState(() => _moi = position);
    _aller(position, 14);
    if (_service != null) _chargerStructures();
  }

  /// Structures du service choisi autour de ma position, ou du centre de la carte si elle est inconnue.
  Future<void> _chargerStructures() async {
    final centre = _moi ?? (_cartePrete ? _carte.camera.center : _centreSenegal);
    setState(() => _structures = null);
    try {
      final r = await Api.instance.get<List<dynamic>>('/structures/', params: {
        'lat': centre.latitude, 'lng': centre.longitude, 'service': _service, 'limite': 10});
      if (!mounted) return;
      setState(() => _structures = r.cast<Map<String, dynamic>>());
      if (_structures!.isNotEmpty && _cartePrete) {
        _carte.fitCamera(CameraFit.coordinates(padding: const EdgeInsets.fromLTRB(40, 120, 40, 260), maxZoom: 15, coordinates: [
          centre, for (final s in _structures!.take(5)) LatLng((s['latitude'] as num).toDouble(), (s['longitude'] as num).toDouble()),
        ]));
      }
    } on ApiException catch (e) {
      if (mounted) { setState(() => _structures = []); afficherMessage(context, e.message, erreur: true); }
    }
  }

  Future<void> _rechercher() async {
    final ctrl = TextEditingController();
    final q = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('Rechercher un lieu'),
      content: TextField(controller: ctrl, autofocus: true, textInputAction: TextInputAction.search,
          onSubmitted: (v) => Navigator.pop(c, v), decoration: const InputDecoration(hintText: 'Quartier, adresse, ville…')),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Rechercher'))],
    ));
    if (q == null || q.trim().length < 3 || !mounted) return;
    try {
      final r = await Api.instance.get<Map<String, dynamic>>('/geocodage/', params: {'q': q.trim()});
      final res = List<Map<String, dynamic>>.from(r['resultats']);
      if (!mounted) return;
      if (res.isEmpty) return afficherMessage(context, 'Aucun lieu trouvé.', erreur: true);
      final choix = res.length == 1 ? res.first : await showModalBottomSheet<Map<String, dynamic>>(context: context, builder: (c) => ListView(shrinkWrap: true, children: [
        for (final x in res) ListTile(leading: const Icon(Icons.place_outlined), title: Text(x['nom'], maxLines: 2, overflow: TextOverflow.ellipsis), onTap: () => Navigator.pop(c, x)),
      ]));
      if (choix == null) return;
      _aller(LatLng(choix['latitude'], choix['longitude']), 15);
      if (_service != null && _moi == null) _chargerStructures();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, '${e.message} Déplacez la carte jusqu’au lieu.', erreur: true);
    }
  }

  void _ficheStructure(Map<String, dynamic> s) => showModalBottomSheet(context: context, builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${s['nom']}', style: titre(18)),
          const SizedBox(height: 4),
          Text([s['service_nom'], if ((s['adresse'] ?? '').toString().isNotEmpty) s['adresse'], s['region_libelle']].join(' · '),
              style: TextStyle(color: AppColors.textGrey)),
          const SizedBox(height: 4),
          Text('À ${distance(s['distance_m'])}${_moi == null ? ' du centre de la carte' : ' de vous'}', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (s['position_approximative'] == true) Text('Position approximative', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          Row(children: [
            if ((s['telephone'] ?? '').toString().isNotEmpty) ...[
              Expanded(child: FilledButton.icon(onPressed: () => appeler(s['telephone']), icon: const Icon(Icons.call), label: const Text('Appeler'))),
              const SizedBox(width: 10),
            ],
            Expanded(child: OutlinedButton.icon(onPressed: () => itineraire((s['latitude'] as num).toDouble(), (s['longitude'] as num).toDouble()),
                icon: const Icon(Icons.directions), label: const Text('Itinéraire'))),
          ]),
        ]),
      ));

  /// Épingle colorée avec le pictogramme du type ; sa pointe marque le lieu exact.
  Marker _point(LatLng p, Color couleur, {double taille = 22, VoidCallback? onTap, String? label, IconData? icone}) {
    final t = taille * 1.7;
    return Marker(
      point: p, width: t, height: t, alignment: Alignment.topCenter,
      child: Semantics(label: label, button: onTap != null, child: GestureDetector(onTap: onTap, child: Stack(alignment: Alignment.topCenter, children: [
        Icon(Icons.location_on, size: t, color: couleur, shadows: const [Shadow(color: Colors.black38, blurRadius: 5)]),
        Positioned(top: t * .14, child: Container(
          width: t * .44, height: t * .44,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: Icon(icone ?? Icons.circle, size: icone == null ? t * .14 : t * .3, color: couleur),
        )),
      ]))),
    );
  }

  static const _iconesServices = <String, IconData>{
    'pompiers': Icons.fire_truck_rounded, 'police': Icons.local_police_rounded, 'sante': Icons.local_hospital_rounded,
    'senelec': Icons.bolt_rounded, 'onas': Icons.water_drop_rounded,
  };

  LatLng _ll(Map<String, dynamic> j) => LatLng((j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble());

  @override
  Widget build(BuildContext context) {
    final config = context.watch<Configuration>();
    final ouverts = _dossiers.map((d) => d['id']).toSet();
    final marqueurs = <Marker>[
      if (_service == null)
        for (final p in _incidents.where((p) => !ouverts.contains(p['id'])))
          _point(_ll(p), couleurHex(config.categorie(p['type_incident'])?.couleur), taille: p['est_le_mien'] == true ? 26 : 22,
              icone: iconesCategories[p['type_incident']], label: config.categorie(p['type_incident'])?.libelle, onTap: () => showModalBottomSheet(
            context: context, builder: (_) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p['est_le_mien'] == true) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Votre signalement', style: titre(14, couleur: AppColors.info))),
              Text(config.categorie(p['type_incident'])?.libelle ?? p['type_incident'], style: titre(18)),
              const SizedBox(height: 8),
              Row(children: [BadgeStatut(p['statut']), const SizedBox(width: 8), Text(dateHeure(lireDate(p['date_creation'])))]),
              const SizedBox(height: 8),
              Text('Identité du déclarant protégée · position arrondie à ~100 m.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ])))),
      for (final d in _dossiers.where((d) => d['latitude'] != null))
        _point(_ll(d), statut(d['statut']).couleur, taille: 26, icone: iconesCategories[d['type_incident']], label: d['reference'], onTap: () => context.push('/dossier/incident/${d['id']}')),
      for (final d in _sos.where((d) => d['latitude'] != null))
        _point(_ll(d), AppColors.rouge, taille: 28, label: 'SOS ${d['reference']}', icone: Icons.sos, onTap: () => context.push('/dossier/sos/${d['id']}')),
      for (final s in _structures ?? const <Map<String, dynamic>>[])
        _point(_ll(s), AppColors.marine700, taille: 26, label: s['nom'], icone: _iconesServices[s['service_code']] ?? Icons.apartment_rounded, onTap: () => _ficheStructure(s)),
      if (_moi != null)
        Marker(point: _moi!, width: 22, height: 22, child: Container(decoration: BoxDecoration(
            shape: BoxShape.circle, color: AppColors.info, border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)]))),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.agent ? 'Carte de mes missions' : 'Carte'), actions: [
        IconButton(tooltip: 'Utiliser ma position actuelle', onPressed: _localisation ? null : _localiser,
            icon: _localisation ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location)),
        IconButton(tooltip: 'Rechercher un lieu', onPressed: _rechercher, icon: const Icon(Icons.search)),
        IconButton(tooltip: 'Actualiser', onPressed: () { _charger(); if (_service != null) _chargerStructures(); }, icon: const Icon(Icons.refresh)),
      ]),
      body: Stack(children: [
        FlutterMap(
          mapController: _carte,
          options: MapOptions(initialCenter: _centreSenegal, initialZoom: 6.3, minZoom: 5.5,
              cameraConstraint: CameraConstraint.containCenter(bounds: _bornes),
              onMapReady: () { _cartePrete = true; if (_moi != null) _carte.move(_moi!, 14); }),
          children: [
            TileLayer(urlTemplate: fondPlan, userAgentPackageName: 'com.senalert.senalert_mobile'),
            MarkerLayer(markers: marqueurs),
            const RichAttributionWidget(attributions: [TextSourceAttribution('Fond © Esri · © contributeurs OpenStreetMap')]),
          ],
        ),
        if (_chargement) const LinearProgressIndicator(),
        Positioned(left: 0, right: 0, top: 8, child: Column(children: [
          // Un seul réglage : quoi afficher. Incidents récents par défaut, ou les structures d'un service.
          SizedBox(height: 44, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: ChoiceChip(
              label: Text(widget.agent ? 'Mes missions' : 'Incidents récents'), selected: _service == null,
              onSelected: (_) => setState(() { _service = null; _structures = null; }))),
            for (final s in config.services)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: ChoiceChip(
                label: Text(s.$2), selected: _service == s.$1,
                onSelected: (_) { setState(() => _service = s.$1); _chargerStructures(); })),
          ])),
          if (_erreur != null) Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 0), child: Bandeau.erreur(_erreur!.message)),
          if (_alertes.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 0), child: Material(
            color: AppColors.orange, borderRadius: BorderRadius.circular(14),
            child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
              const Icon(Icons.campaign_rounded),
              const SizedBox(width: 8),
              Expanded(child: Text('${_alertes.first['titre']}${_alertes.length > 1 ? ' (+${_alertes.length - 1})' : ''}', style: const TextStyle(fontWeight: FontWeight.w700))),
            ])),
          )),
        ])),
        // Laisse la place du bouton SOS flottant (citoyen) en bas à droite.
        if (_service != null) Positioned(left: 12, right: 12, bottom: widget.agent ? 16 : 84, child: Material(
          color: AppColors.white, borderRadius: BorderRadius.circular(16), elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: _structures == null
                ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
                : _structures!.isEmpty
                    ? const Padding(padding: EdgeInsets.all(16), child: Text('Aucune structure de ce service n’est enregistrée près d’ici.'))
                    : ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 6), children: [
                        Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 2), child: Text(
                            _moi == null ? 'Les plus proches du centre de la carte' : 'Les plus proches de vous',
                            style: TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w600))),
                        for (final s in _structures!)
                          ListTile(
                            dense: true, onTap: () { _aller(_ll(s), 16); _ficheStructure(s); },
                            leading: const Icon(Icons.apartment_rounded, color: AppColors.marine700),
                            title: Text('${s['nom']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text((s['adresse'] ?? '').toString().isNotEmpty ? s['adresse'] : s['region_libelle'], maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: Text(distance(s['distance_m']), style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                      ]),
          ),
        )),
      ]),
    );
  }
}
