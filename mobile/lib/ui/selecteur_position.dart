import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/constants/app_colors.dart';
import '../core/location.dart';
import '../state/configuration.dart';
import 'kit.dart';

const fondPlan = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}';
const _centreSenegal = LatLng(14.45, -14.9);

/// Choix d'un lieu, pensé pour un débutant : le repère reste au centre et on déplace la carte dessous
/// (comme les applications de VTC). Trois façons d'y arriver : « Ma position », la recherche d'une adresse
/// ou d'une localité, ou le déplacement à la main. Si la localisation est refusée, la recherche et la carte
/// restent utilisables.
class SelecteurPosition extends StatefulWidget {
  final double? lat, lng, precision;
  /// Appelé à chaque nouvelle position : `precision` n'est connue que pour une position GPS.
  final void Function(double lat, double lng, double? precision) onPosition;
  const SelecteurPosition({super.key, this.lat, this.lng, this.precision, required this.onPosition});
  @override
  State<SelecteurPosition> createState() => _SelecteurPositionState();
}

class _SelecteurPositionState extends State<SelecteurPosition> {
  final _carte = MapController();
  final _recherche = TextEditingController();
  bool _gps = false;
  bool _pret = false;
  LatLng? _enAttente;
  double _zoomEnAttente = 16;
  bool _rechercheEnCours = false;
  Position2? _echecGps;
  List<Map<String, dynamic>> _resultats = [];

  @override
  void initState() {
    super.initState();
    // Première ouverture : on tente directement la position du téléphone.
    if (widget.lat == null) WidgetsBinding.instance.addPostFrameCallback((_) => _maPosition());
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  void _aller(double lat, double lng, {double? precision, double zoom = 16}) {
    // La carte ne se déplace qu'une fois affichée : sinon le déplacement attend qu'elle soit prête.
    if (_pret) {
      _carte.move(LatLng(lat, lng), zoom);
    } else {
      _enAttente = LatLng(lat, lng);
      _zoomEnAttente = zoom;
    }
    widget.onPosition(lat, lng, precision);
  }

  Future<void> _maPosition() async {
    setState(() { _gps = true; _echecGps = null; });
    final p = await Localisation.lire(delai: const Duration(seconds: 15));
    if (!mounted) return;
    setState(() { _gps = false; _echecGps = p.ok ? null : p; });
    if (p.ok) _aller(p.lat!, p.lng!, precision: p.precision, zoom: 17);
  }

  Future<void> _rechercher() async {
    final q = _recherche.text.trim();
    if (q.length < 3) return;
    FocusScope.of(context).unfocus();
    final regions = context.read<Configuration>().regions;
    setState(() { _rechercheEnCours = true; _resultats = []; });
    try {
      final r = await Api.instance.get<Map<String, dynamic>>('/geocodage/', params: {'q': q});
      _resultats = List<Map<String, dynamic>>.from(r['resultats']);
      if (_resultats.isEmpty && mounted) afficherMessage(context, 'Aucun lieu trouvé : essayez un quartier ou une ville.', erreur: true);
    } on ApiException {
      // Recherche en ligne indisponible : on propose au moins les régions (chef-lieu), sans rien inventer.
      _resultats = [
        for (final r in regions)
          if (r.libelle.toLowerCase().contains(q.toLowerCase())) {'nom': 'Région de ${r.libelle} (chef-lieu)', 'latitude': r.lat, 'longitude': r.lng, 'zoom': 12.0},
      ];
      if (mounted) {
        afficherMessage(context, _resultats.isEmpty
            ? 'Recherche d’adresse indisponible : déplacez la carte jusqu’au lieu.'
            : 'Recherche d’adresse indisponible : voici les régions correspondantes.', erreur: true);
      }
    } finally {
      if (mounted) setState(() => _rechercheEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aPosition = widget.lat != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: _recherche, textInputAction: TextInputAction.search, onSubmitted: (_) => _rechercher(),
        decoration: InputDecoration(
          hintText: 'Rechercher une adresse, un quartier, une ville…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _rechercheEnCours
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(tooltip: 'Rechercher', icon: const Icon(Icons.arrow_forward), onPressed: _rechercher),
        ),
      ),
      for (final r in _resultats.take(5))
        ListTile(
          dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.place_outlined),
          title: Text('${r['nom']}', maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () {
            setState(() => _resultats = []);
            _recherche.text = '${r['nom']}'.split(',').first;
            _aller((r['latitude'] as num).toDouble(), (r['longitude'] as num).toDouble(), zoom: (r['zoom'] as double?) ?? 16);
          },
        ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(height: 320, child: Stack(children: [
          FlutterMap(
            mapController: _carte,
            options: MapOptions(
              initialCenter: aPosition ? LatLng(widget.lat!, widget.lng!) : _centreSenegal,
              initialZoom: aPosition ? 16 : 6.5,
              onMapReady: () {
                _pret = true;
                if (_enAttente != null) _carte.move(_enAttente!, _zoomEnAttente);
              },
              // Le lieu est toujours le centre de la carte : on le déplace en faisant glisser la carte.
              onPositionChanged: (camera, geste) {
                if (geste) widget.onPosition(camera.center.latitude, camera.center.longitude, null);
              },
              onTap: (_, p) => _aller(p.latitude, p.longitude, zoom: _carte.camera.zoom),
            ),
            children: [
              TileLayer(urlTemplate: fondPlan, userAgentPackageName: 'sn.senalert.mobile'),
              if (aPosition && (widget.precision ?? 0) > 0)
                CircleLayer(circles: [CircleMarker(point: LatLng(widget.lat!, widget.lng!), radius: widget.precision!.clamp(0, 1000).toDouble(),
                    useRadiusInMeter: true, color: AppColors.info.withOpacity(0.1), borderColor: AppColors.info, borderStrokeWidth: 1)]),
              const RichAttributionWidget(attributions: [TextSourceAttribution('Fond © Esri · © contributeurs OpenStreetMap')]),
            ],
          ),
          // Repère fixe : sa pointe marque exactement le centre de la carte.
          IgnorePointer(child: Center(child: Padding(
            padding: const EdgeInsets.only(bottom: 44),
            child: Icon(Icons.location_on, size: 46, color: aPosition ? AppColors.rouge : AppColors.textMuted,
                shadows: const [Shadow(color: Colors.black38, blurRadius: 6)]),
          ))),
          Positioned(right: 10, bottom: 10, child: Column(children: [
            _BoutonCarte(icone: Icons.add, aide: 'Zoomer', onTap: () => _carte.move(_carte.camera.center, _carte.camera.zoom + 1)),
            const SizedBox(height: 6),
            _BoutonCarte(icone: Icons.remove, aide: 'Dézoomer', onTap: () => _carte.move(_carte.camera.center, _carte.camera.zoom - 1)),
          ])),
        ])),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _gps ? null : _maPosition,
        icon: _gps ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
        label: Text(_gps ? 'Recherche de votre position…' : 'Utiliser ma position actuelle'),
      ),
      if (_echecGps != null) Padding(padding: const EdgeInsets.only(top: 8), child: Bandeau.alerte(
          '${_echecGps!.erreur ?? 'Position indisponible.'} Recherchez l’adresse ou déplacez la carte jusqu’au lieu.',
          action: _echecGps!.reglagesRequis ? const TextButton(onPressed: Localisation.ouvrirReglages, child: Text('Ouvrir les réglages')) : null)),
      const SizedBox(height: 8),
      Text(
        !aPosition ? 'Placez le repère rouge sur le lieu : faites glisser la carte, ou touchez l’endroit.'
            : widget.precision != null ? 'Position GPS · précision ± ${widget.precision!.round()} m. Ajustez la carte si besoin.'
            : 'Lieu placé sur la carte (${widget.lat!.toStringAsFixed(5)}, ${widget.lng!.toStringAsFixed(5)}).',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: aPosition ? AppColors.success : AppColors.textGrey, fontWeight: FontWeight.w600),
      ),
    ]);
  }
}

class _BoutonCarte extends StatelessWidget {
  final IconData icone;
  final String aide;
  final VoidCallback onTap;
  const _BoutonCarte({required this.icone, required this.aide, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.white, shape: const CircleBorder(), elevation: 2,
        child: IconButton(tooltip: aide, icon: Icon(icone, color: AppColors.marine700), onPressed: onTap),
      );
}
