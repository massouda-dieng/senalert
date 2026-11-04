import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/format.dart';
import '../../state/configuration.dart';
import '../../ui/kit.dart';
import '../../ui/selecteur_position.dart';

const _cleBrouillon = 'brouillon_signalement';
const _tailleMax = 5 * 1024 * 1024;
const _photosMax = 5;

/// Photo choisie, gardée en mémoire pour l'aperçu avant l'envoi.
class _Photo {
  final Uint8List octets;
  const _Photo(this.octets);
}

/// Formats acceptés par le serveur, reconnus à leur signature (et non à l'extension du fichier).
bool formatImageAccepte(Uint8List o) =>
    (o.length > 3 && o[0] == 0xFF && o[1] == 0xD8) || // JPEG
    (o.length > 8 && o[0] == 0x89 && o[1] == 0x50 && o[2] == 0x4E && o[3] == 0x47) || // PNG
    (o.length > 12 && String.fromCharCodes(o.sublist(0, 4)) == 'RIFF' && String.fromCharCodes(o.sublist(8, 12)) == 'WEBP');

/// Signalement en 5 étapes : type → description et photo → lieu → structure → confirmation.
/// La date, l'heure et la région sont enregistrées par le serveur : elles ne sont jamais demandées.
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
  final _adresse = TextEditingController();
  final _description = TextEditingController();
  final List<_Photo> _photos = [];
  bool _envoi = false;
  ApiException? _erreur;
  // Étape « Structure » : service (choisi seulement pour « Autre incident »), structures proches, agent facultatif.
  int? _service;
  List<Map<String, dynamic>>? _structures;
  String? _erreurStructures;
  Map<String, dynamic>? _structure;
  List<Map<String, dynamic>>? _agents;
  Map<String, dynamic>? _agent;

  static const _etapes = ['Type', 'Détails', 'Lieu', 'Structure', 'Envoi'];

  @override
  void initState() {
    super.initState();
    _restaurer();
    for (final c in [_adresse, _description]) {
      c.addListener(_sauver);
    }
  }

  @override
  void dispose() {
    _adresse.dispose();
    _description.dispose();
    super.dispose();
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
      _adresse.text = b['adresse'] ?? '';
      _description.text = b['description'] ?? '';
    });
  }

  Future<void> _sauver() async {
    (await SharedPreferences.getInstance()).setString(_cleBrouillon, jsonEncode({
      'cle': _cle, 'type': _type, 'lat': _lat, 'lng': _lng, 'precision': _precision,
      'adresse': _adresse.text, 'description': _description.text,
    }));
  }

  Future<void> _effacer() async => (await SharedPreferences.getInstance()).remove(_cleBrouillon);

  bool get _sansService => context.read<Configuration>().categorie(_type)?.service == null;

  // ------------------------------------------------------------------ Photos

  Future<void> _choisirPhoto(ImageSource source, {int? remplacer}) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 2048, imageQuality: 82);
      if (x == null) return;
      final octets = await x.readAsBytes();
      if (!mounted) return;
      if (octets.length > _tailleMax) return afficherMessage(context, 'Photo trop lourde : 5 Mo maximum.', erreur: true);
      if (!formatImageAccepte(octets)) return afficherMessage(context, 'Format non accepté : choisissez une photo JPEG, PNG ou WEBP.', erreur: true);
      setState(() => remplacer == null ? _photos.add(_Photo(octets)) : _photos[remplacer] = _Photo(octets));
    } catch (_) {
      if (mounted) afficherMessage(context, 'Impossible d’ouvrir l’appareil photo ou la galerie : vérifiez l’autorisation.', erreur: true);
    }
  }

  Future<void> _sourcePhoto({int? remplacer}) async {
    final source = await showModalBottomSheet<ImageSource>(context: context, builder: (c) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (!kIsWeb) ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Prendre une photo'), onTap: () => Navigator.pop(c, ImageSource.camera)),
      ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choisir dans la galerie'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
      if (remplacer != null) ListTile(leading: const Icon(Icons.delete_outline, color: AppColors.rouge), title: const Text('Supprimer cette photo'),
          onTap: () { Navigator.pop(c); setState(() => _photos.removeAt(remplacer)); }),
    ])));
    if (source != null) await _choisirPhoto(source, remplacer: remplacer);
  }

  Widget _apercuPhotos({bool modifiable = true}) => Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < _photos.length; i++)
          Stack(clipBehavior: Clip.none, children: [
            GestureDetector(
              onTap: modifiable ? () => _sourcePhoto(remplacer: i) : null,
              child: ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_photos[i].octets, width: 92, height: 92, fit: BoxFit.cover, semanticLabel: 'Photo ${i + 1}')),
            ),
            if (modifiable) Positioned(top: -8, right: -8, child: Material(
              color: AppColors.white, shape: const CircleBorder(), elevation: 2,
              child: InkWell(customBorder: const CircleBorder(), onTap: () => setState(() => _photos.removeAt(i)),
                  child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, size: 16, semanticLabel: 'Supprimer'))),
            )),
          ]),
        if (modifiable && _photos.length < _photosMax)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _sourcePhoto,
            child: Container(width: 92, height: 92,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border, width: 1.5), color: AppColors.surfaceSubtle),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_a_photo_outlined, color: AppColors.marine700),
                  SizedBox(height: 4),
                  Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ])),
          ),
      ]);

  // --------------------------------------------------------------- Structures

  Future<void> _chargerStructures() async {
    setState(() { _structures = null; _erreurStructures = null; _structure = null; _agents = null; _agent = null; });
    if (_sansService && _service == null) return setState(() => _structures = []);
    try {
      final r = await Api.instance.get<List<dynamic>>('/structures/', params: {
        'lat': _lat, 'lng': _lng, 'categorie': _type, if (_service != null) 'service': _service, 'limite': 5,
      });
      if (mounted) setState(() => _structures = r.cast<Map<String, dynamic>>());
    } on ApiException catch (e) {
      // Sans liste, le serveur oriente vers la structure compétente la plus proche.
      if (mounted) setState(() { _structures = []; _erreurStructures = e.message; });
    }
  }

  Future<void> _choisirStructure(Map<String, dynamic> s) async {
    setState(() { _structure = s; _agents = null; _agent = null; });
    try {
      final r = await Api.instance.get<List<dynamic>>('/structures/${s['id']}/agents/');
      if (mounted && _structure == s) setState(() => _agents = r.cast<Map<String, dynamic>>());
    } on ApiException {
      if (mounted) setState(() => _agents = []);
    }
  }

  List<Widget> _etapeStructure() {
    final config = context.watch<Configuration>();
    final choixService = _sansService ? [
      Text('Quel service doit intervenir ?', style: titre(18)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in config.services)
          ChoiceChip(label: Text(s.$2), selected: _service == s.$1, onSelected: (_) { setState(() => _service = s.$1); _chargerStructures(); }),
      ]),
      const SizedBox(height: 16),
    ] : <Widget>[];
    if (_sansService && _service == null) return choixService;
    if (_structures == null) return [...choixService, const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))];
    if (_structures!.isEmpty) {
      return [...choixService, Bandeau(_erreurStructures != null
          ? 'Liste des structures indisponible ($_erreurStructures). Vous pouvez envoyer : le signalement ira à la structure compétente la plus proche.'
          : 'Aucune structure de ce service n’est enregistrée près de ce lieu. Vous pouvez envoyer : la supervision orientera votre signalement.')];
    }
    return [
      ...choixService,
      Text('Structures compétentes les plus proches', style: titre(18)),
      const SizedBox(height: 4),
      Text('Touchez celle qui doit recevoir votre signalement.', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
      const SizedBox(height: 10),
      for (final s in _structures!)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Carte(
          couleur: _structure?['id'] == s['id'] ? AppColors.marine50 : null,
          onTap: () => _choisirStructure(s),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(_structure?['id'] == s['id'] ? Icons.radio_button_checked : Icons.radio_button_off, color: AppColors.marine700),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s['nom']}', style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 2),
              Text([s['service_nom'], if ((s['adresse'] ?? '').toString().isNotEmpty) s['adresse'] else s['region_libelle']].join(' · '),
                  style: TextStyle(fontSize: 12, color: AppColors.textGrey), maxLines: 2),
              if (s['dans_la_zone'] == false) const Text('Hors de la région du lieu', style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
              if (s['position_approximative'] == true) Text('Position de l’agence approximative', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(distance(s['distance_m']), style: const TextStyle(fontWeight: FontWeight.w700)),
              Text((s['nb_agents_disponibles'] ?? 0) > 0 ? '${s['nb_agents_disponibles']} agent(s) dispo.' : 'aucun agent dispo.',
                  style: TextStyle(fontSize: 11, color: (s['nb_agents_disponibles'] ?? 0) > 0 ? AppColors.success : AppColors.textMuted)),
            ]),
          ]),
        )),
      if (_structure != null) ...[
        const SizedBox(height: 8),
        Text('Agent (facultatif)', style: titre(16)),
        if (_agents == null) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
        else ...[
          RadioListTile<int?>(
            value: null, groupValue: _agent?['id'], onChanged: (_) => setState(() => _agent = null),
            title: const Text('Laisser le superviseur choisir'), contentPadding: EdgeInsets.zero,
          ),
          for (final a in _agents!)
            RadioListTile<int?>(
              value: a['id'], groupValue: _agent?['id'], onChanged: (_) => setState(() => _agent = a), contentPadding: EdgeInsets.zero,
              title: Text('${a['prenom']} · ${a['fonction']}'),
              subtitle: Text((a['missions_actives'] ?? 0) == 0 ? 'Libre' : '${a['missions_actives']} mission(s) en cours'),
            ),
          if (_agents!.isEmpty) Text('Aucun agent disponible en ce moment : le superviseur affectera votre dossier.',
              style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ],
      ],
    ];
  }

  // ------------------------------------------------------------------ Navigation

  bool get _etapeValide => switch (_etape) {
        0 => _type != null,
        1 => _type != 'autre' || _description.text.trim().length >= 10,
        2 => _lat != null,
        3 => _structures != null && (_structures!.isEmpty || _structure != null),
        _ => !_envoi,
      };

  String get _libelleSuivant => switch (_etape) {
        2 => 'Confirmer ce lieu',
        3 => _structure == null ? 'Continuer' : 'Choisir cette structure',
        4 => 'Envoyer le signalement',
        _ => 'Continuer',
      };

  void _suivant() {
    FocusScope.of(context).unfocus();
    setState(() => _etape++);
    if (_etape == 3) _chargerStructures();
  }

  Future<void> _envoyer() async {
    if (_envoi) return; // un seul envoi, même en cas de double appui
    setState(() { _envoi = true; _erreur = null; });
    try {
      final form = FormData.fromMap({
        'type_incident': _type,
        'latitude': _lat,
        'longitude': _lng,
        if (_precision != null) 'precision_gps': _precision!.round(),
        'adresse': _adresse.text.trim(),
        'description': _description.text.trim(),
        'client_request_id': _cle,
        if (_structure != null) 'structure': _structure!['id'],
        if (_agent != null) 'agent': _agent!['id'],
      });
      for (var i = 0; i < _photos.length; i++) {
        form.files.add(MapEntry('photos', MultipartFile.fromBytes(_photos[i].octets, filename: 'photo${i + 1}.jpg')));
      }
      final r = await Api.instance.post<Map<String, dynamic>>('/incidents/', data: form);
      await _effacer();
      if (!mounted) return;
      await showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
        title: const Text('Signalement envoyé'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SelectableText(r['reference'], style: const TextStyle(fontFamily: 'monospace', fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          LigneInfo('Destinataire', r['structure_nom'] ?? 'Supervision SenAlert'),
          LigneInfo('Enregistré le', dateHeure(lireDate(r['date_creation']))),
          LigneInfo('Statut', statut(r['statut']).libelle),
          LigneInfo('Photos', '${(r['photos'] as List?)?.length ?? 0}'),
          const SizedBox(height: 6),
          Text(r['statut'] == 'affecte' ? 'L’agent choisi est prévenu.' : 'Le superviseur de la structure va désigner un agent.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Suivre mon signalement'))],
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
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un incident')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              for (var i = 0; i < _etapes.length; i++)
                Expanded(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(children: [
                    Container(height: 5, decoration: BoxDecoration(color: i <= _etape ? AppColors.marine800 : AppColors.border, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 4),
                    Text(_etapes[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: i == _etape ? AppColors.textDark : AppColors.textMuted)),
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
                      couleur: _type == c.code ? AppColors.marine50 : null,
                      onTap: () { setState(() { _type = c.code; _service = null; _etape = 1; }); _sauver(); },
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
              const SizedBox(height: 14),
              const Bandeau('Danger vital en cours ? Utilisez plutôt le bouton SOS et appelez les secours.'),
            ],
            if (_etape == 1) ...[
              Text('Décrivez la situation', style: titre(18)),
              const SizedBox(height: 10),
              TextField(controller: _description, maxLines: 4, maxLength: 2000, onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: _type == 'autre' ? 'Description (obligatoire, 10 caractères min.)' : 'Description (facultative)',
                      hintText: 'Ce que vous voyez : victimes, danger, accès…')),
              const SizedBox(height: 6),
              Text('Photo (facultative) · ${_photos.length}/$_photosMax', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _apercuPhotos(),
              const SizedBox(height: 8),
              Text('Touchez une photo pour la remplacer. JPEG, PNG ou WEBP, 5 Mo max. La position cachée dans la photo est effacée par le serveur.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
            if (_etape == 2) ...[
              Text('Où se passe l’incident ?', style: titre(18)),
              const SizedBox(height: 10),
              SelecteurPosition(lat: _lat, lng: _lng, precision: _precision, onPosition: (lat, lng, precision) {
                setState(() { _lat = lat; _lng = lng; _precision = precision; });
                _sauver();
              }),
              const SizedBox(height: 12),
              TextField(controller: _adresse, maxLength: 255, decoration: const InputDecoration(labelText: 'Repère (facultatif)', hintText: 'Ex. : près du marché, rond-point…')),
            ],
            if (_etape == 3) ..._etapeStructure(),
            if (_etape == 4) ...[
              Text('Vérifiez puis envoyez', style: titre(18)),
              const SizedBox(height: 10),
              Carte(child: Column(children: [
                LigneInfo('Type', config.categorie(_type)?.libelle ?? '—'),
                LigneInfo('Description', _description.text.trim().isEmpty ? '—' : _description.text.trim()),
                LigneInfo('Lieu', '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}${_precision != null ? ' (GPS ± ${_precision!.round()} m)' : ''}'),
                if (_adresse.text.trim().isNotEmpty) LigneInfo('Repère', _adresse.text.trim()),
                LigneInfo('Destinataire', _structure?['nom'] ?? 'Structure compétente la plus proche'),
                LigneInfo('Agent', _agent == null ? 'Désigné par le superviseur' : '${_agent!['prenom']} · ${_agent!['fonction']}'),
                const LigneInfo('Date et heure', 'Enregistrées automatiquement à l’envoi'),
                LigneInfo('Photos', _photos.isEmpty ? 'Aucune' : '${_photos.length}'),
              ])),
              if (_photos.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: _apercuPhotos(modifiable: false)),
            ],
            if (_erreur != null) Padding(padding: const EdgeInsets.only(top: 12),
                child: Bandeau.erreur('${_erreur!.message} Vos informations sont conservées : vous pouvez réessayer.', titre: 'Signalement non envoyé')),
          ])),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(color: AppColors.white, border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              if (_etape > 0) Expanded(child: OutlinedButton(onPressed: _envoi ? null : () => setState(() => _etape--), child: const Text('Retour'))),
              if (_etape > 0) const SizedBox(width: 10),
              Expanded(flex: 2, child: FilledButton(
                onPressed: !_etapeValide || _envoi ? null : (_etape < 4 ? _suivant : _envoyer),
                child: _envoi ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(_libelleSuivant),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}
