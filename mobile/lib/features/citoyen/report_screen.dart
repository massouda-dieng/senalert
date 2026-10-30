import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/format.dart';
import '../../core/location.dart';
import '../../state/configuration.dart';
import '../../ui/kit.dart';

const _cleBrouillon = 'brouillon_signalement';
const _tailleMax = 5 * 1024 * 1024;

class SignalerScreen extends StatefulWidget {
  const SignalerScreen({super.key});
  @override
  State<SignalerScreen> createState() => _SignalerScreenState();
}

class _SignalerScreenState extends State<SignalerScreen> {
  int _etape = 0;
  String _cle = nouvelleCle();
  String? _type;
  double? _lat, _lng, _precision;
  String? _region;
  final _adresse = TextEditingController();
  final _description = TextEditingController();
  final _infos = TextEditingController();
  final List<XFile> _photos = [];
  bool _gpsEnCours = false;
  String? _gpsErreur;
  bool _envoi = false;
  ApiException? _erreur;
  final _carte = MapController();

  @override
  void initState() {
    super.initState();
    _restaurer();
    for (final c in [_adresse, _description, _infos]) {
      c.addListener(_sauver);
    }
  }

  Future<void> _restaurer() async {
    final brut = (await SharedPreferences.getInstance()).getString(_cleBrouillon);
    if (brut == null) return;
    final b = jsonDecode(brut);
    setState(() {
      _cle = b['cle'] ?? _cle;
      _type = b['type'];
      _lat = b['lat'];
      _lng = b['lng'];
      _precision = b['precision'];
      _region = b['region'];
      _adresse.text = b['adresse'] ?? '';
      _description.text = b['description'] ?? '';
      _infos.text = b['infos'] ?? '';
    });
  }

  Future<void> _sauver() async {
    (await SharedPreferences.getInstance()).setString(_cleBrouillon, jsonEncode({
      'cle': _cle, 'type': _type, 'lat': _lat, 'lng': _lng, 'precision': _precision, 'region': _region,
      'adresse': _adresse.text, 'description': _description.text, 'infos': _infos.text,
    }));
  }

  Future<void> _effacer() async {
    (await SharedPreferences.getInstance()).remove(_cleBrouillon);
  }

  Future<void> _localiser() async {
    setState(() { _gpsEnCours = true; _gpsErreur = null; });
    final p = await Localisation.lire(delai: const Duration(seconds: 15));
    if (!mounted) return;
    setState(() {
      _gpsEnCours = false;
      if (p.ok) {
        _lat = p.lat; _lng = p.lng; _precision = p.precision;
        _carte.move(LatLng(_lat!, _lng!), 16);
      } else {
        _gpsErreur = p.erreur;
      }
    });
    _sauver();
  }

  Future<void> _ajouterPhoto(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 2048, imageQuality: 82);
      if (x == null) return;
      if (await x.length() > _tailleMax) {
        if (mounted) afficherMessage(context, 'Photo trop lourde (5 Mo maximum).', erreur: true);
        return;
      }
      setState(() => _photos.add(x));
    } catch (_) {
      if (mounted) afficherMessage(context, 'Accès à l’appareil photo ou à la galerie refusé.', erreur: true);
    }
  }

  bool get _etapeValide => switch (_etape) {
        0 => _type != null,
        1 => _lat != null,
        2 => _type != 'autre' || _description.text.trim().length >= 10,
        _ => true,
      };

  Future<void> _envoyer() async {
    setState(() { _envoi = true; _erreur = null; });
    try {
      final form = FormData.fromMap({
        'type_incident': _type,
        'latitude': _lat,
        'longitude': _lng,
        if (_precision != null) 'precision_gps': _precision!.round(),
        if (_region != null) 'region': _region,
        'adresse': _adresse.text.trim(),
        'description': _description.text.trim(),
        'infos_complementaires': _infos.text.trim(),
        'client_request_id': _cle,
      });
      for (final p in _photos) {
        form.files.add(MapEntry('photos', MultipartFile.fromBytes(await p.readAsBytes(), filename: 'photo.jpg')));
      }
      final r = await Api.instance.post<Map<String, dynamic>>('/incidents/', data: form);
      await _effacer();
      if (!mounted) return;
      await showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
        title: const Text('Signalement enregistré'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SelectableText(r['reference'], style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Transmis au service ${r['service_nom'] ?? 'compétent'}. Vous serez notifié à chaque changement de statut.', textAlign: TextAlign.center),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Suivre le dossier'))],
      ));
      if (mounted) context.pushReplacement('/dossier/incident/${r['id']}');
    } on ApiException catch (e) {
      setState(() => _erreur = e); // la clé est conservée : un nouvel essai ne crée pas de doublon
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<Configuration>();
    const etapes = ['Catégorie', 'Lieu', 'Détails', 'Vérification'];
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un incident')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              for (var i = 0; i < etapes.length; i++)
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(children: [
                    AnimatedContainer(duration: const Duration(milliseconds: 250), height: 5,
                        decoration: BoxDecoration(color: i <= _etape ? AppColors.navy800 : AppColors.border, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 4),
                    Text(etapes[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: i == _etape ? AppColors.textDark : AppColors.textMuted)),
                  ]),
                )),
            ]),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            if (_etape == 0) ...[
              Text('Quel type d’incident ?', style: titre(18)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.3,
                children: [
                  for (final c in config.categories)
                    Carte(
                      couleur: _type == c.code ? AppColors.blue50 : null,
                      onTap: () { setState(() { _type = c.code; _etape = 1; }); _sauver(); },
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(children: [
                        Icon(iconesCategories[c.code] ?? Icons.report, color: couleurHex(c.couleur)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.libelle, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2)),
                      ]),
                    ),
                ],
              ),
              if (config.categories.isEmpty) const Bandeau.alerte('Catégories indisponibles : vérifiez votre connexion.'),
            ],
            if (_etape == 1) ...[
              FilledButton.icon(onPressed: _gpsEnCours ? null : _localiser,
                  icon: _gpsEnCours ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.my_location),
                  label: const Text('Utiliser ma position')),
              const SizedBox(height: 6),
              const Text('ou touchez la carte pour placer l’incident.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey)),
              if (_gpsErreur != null) Padding(padding: const EdgeInsets.only(top: 8), child: Bandeau.alerte(_gpsErreur!,
                  action: const TextButton(onPressed: Localisation.ouvrirReglages, child: Text('Ouvrir les réglages')))),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(height: 300, child: FlutterMap(
                  mapController: _carte,
                  options: MapOptions(
                    initialCenter: _lat != null ? LatLng(_lat!, _lng!) : const LatLng(14.45, -14.9),
                    initialZoom: _lat != null ? 15 : 6.5,
                    onTap: (_, p) { setState(() { _lat = p.latitude; _lng = p.longitude; _precision = null; }); _sauver(); },
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'sn.senalert.mobile'),
                    if (_lat != null) MarkerLayer(markers: [Marker(point: LatLng(_lat!, _lng!), width: 40, height: 40,
                        child: const Icon(Icons.location_on, color: AppColors.crimson, size: 40))]),
                    const RichAttributionWidget(attributions: [TextSourceAttribution('© contributeurs OpenStreetMap')]),
                  ],
                )),
              ),
              if (_lat != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(
                  'Position : ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}${_precision != null ? ' · ± ${_precision!.round()} m' : ' · placée sur la carte'}',
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600))),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                value: _region, isExpanded: true,
                decoration: const InputDecoration(labelText: 'Région', helperText: 'Déduite de la position si non précisée.'),
                items: [const DropdownMenuItem(value: null, child: Text('Automatique')), for (final r in config.regions) DropdownMenuItem(value: r.code, child: Text(r.libelle))],
                onChanged: (v) { setState(() => _region = v); _sauver(); },
              ),
              const SizedBox(height: 12),
              TextField(controller: _adresse, maxLength: 255, decoration: const InputDecoration(labelText: 'Adresse ou repère', hintText: 'Ex. : près du marché, rond-point…')),
            ],
            if (_etape == 2) ...[
              TextField(controller: _description, maxLines: 4, maxLength: 2000,
                  decoration: InputDecoration(labelText: _type == 'autre' ? 'Description (obligatoire)' : 'Description', hintText: 'Ce que vous voyez : victimes, danger, accès…')),
              const SizedBox(height: 8),
              TextField(controller: _infos, maxLength: 1000, decoration: const InputDecoration(labelText: 'Informations complémentaires')),
              const SizedBox(height: 8),
              Text('Photos (${_photos.length}/5)', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < _photos.length; i++)
                  Chip(label: Text('Photo ${i + 1}'), onDeleted: () => setState(() => _photos.removeAt(i))),
                if (_photos.length < 5) ...[
                  if (!kIsWeb) ActionChip(avatar: const Icon(Icons.photo_camera, size: 18), label: const Text('Appareil photo'), onPressed: () => _ajouterPhoto(ImageSource.camera)),
                  ActionChip(avatar: const Icon(Icons.photo_library, size: 18), label: const Text('Galerie'), onPressed: () => _ajouterPhoto(ImageSource.gallery)),
                ],
              ]),
              const SizedBox(height: 6),
              const Text('Les métadonnées des photos (dont la position) sont supprimées par le serveur.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
            if (_etape == 3) ...[
              Text('Vérifiez avant l’envoi', style: titre(18)),
              const SizedBox(height: 10),
              Carte(child: Column(children: [
                LigneInfo('Catégorie', config.categorie(_type)?.libelle ?? '—'),
                LigneInfo('Service', config.categorie(_type)?.service ?? 'À déterminer par le superviseur'),
                LigneInfo('Position', _lat == null ? '—' : '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'),
                LigneInfo('Région', config.region(_region)?.libelle ?? 'Automatique'),
                LigneInfo('Repère', _adresse.text.isEmpty ? '—' : _adresse.text),
                LigneInfo('Description', _description.text.isEmpty ? '—' : _description.text),
                LigneInfo('Photos', _photos.isEmpty ? 'Aucune' : '${_photos.length}'),
              ])),
              const SizedBox(height: 12),
              const Bandeau('Pour un danger vital en cours, utilisez plutôt le bouton SOS et appelez les secours.'),
            ],
            if (_erreur != null) Padding(padding: const EdgeInsets.only(top: 12),
                child: Bandeau.erreur('${_erreur!.message} Vos informations sont conservées : vous pouvez réessayer.', titre: 'Signalement non enregistré')),
          ])),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              if (_etape > 0) Expanded(child: OutlinedButton(onPressed: () => setState(() => _etape--), child: const Text('Retour'))),
              if (_etape > 0) const SizedBox(width: 10),
              Expanded(flex: 2, child: FilledButton(
                onPressed: !_etapeValide || _envoi ? null : (_etape < 3 ? () => setState(() => _etape++) : _envoyer),
                child: _envoi ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(_etape < 3 ? 'Continuer' : 'Envoyer le signalement'),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}
