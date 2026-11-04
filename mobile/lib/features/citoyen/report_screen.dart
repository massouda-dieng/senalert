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
import '../../core/models.dart';
import '../../ui/credits_photos.dart';

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
/// Type d'incident illustré par une photo d'exemple (aussi utilisé sur l'accueil du citoyen).
class TuileCategorie extends StatelessWidget {
  final Categorie c;
  final bool choisie;
  final VoidCallback onTap;
  const TuileCategorie(this.c, {super.key, this.choisie = false, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: choisie ? AppColors.marine800 : AppColors.border, width: choisie ? 2 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: Image.asset('assets/images/photos/${photoCategorie[c.code] ?? 'dakar-vue'}.jpg', fit: BoxFit.cover, excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => ColoredBox(color: AppColors.marine50, child: Icon(iconesCategories[c.code] ?? Icons.report, color: AppColors.marine700)))),
          Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 9), child: Row(children: [
            Icon(iconesCategories[c.code] ?? Icons.report, size: 18, color: couleurHex(c.couleur)),
            const SizedBox(width: 6),
            Expanded(child: Text(c.libelle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
          ])),
        ])),
      );
}

class SignalerScreen extends StatefulWidget {
  /// Type déjà choisi (vignette de l'accueil) : le formulaire commence aux détails.
  final String? type;
  const SignalerScreen({super.key, this.type});
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
  // Pas d'étape « structure » : le serveur oriente vers la structure compétente la plus proche (agent disponible d'abord).
  static const _etapes = ['Type', 'Détails', 'Lieu', 'Envoi'];

  @override
  void initState() {
    super.initState();
    if (widget.type != null) { _type = widget.type; _etape = 1; }
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
      _type = widget.type ?? b['type'];
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

  // ------------------------------------------------------------------ Navigation

  bool get _etapeValide => switch (_etape) {
        0 => _type != null,
        1 => _type != 'autre' || _description.text.trim().length >= 10,
        2 => _lat != null,
        _ => !_envoi,
      };

  String get _libelleSuivant => switch (_etape) {
        2 => 'Confirmer ce lieu',
        3 => 'Envoyer le signalement',
        _ => 'Continuer',
      };

  void _suivant() {
    FocusScope.of(context).unfocus();
    setState(() => _etape++);
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
          Text(r['statut'] == 'affecte' ? 'Orienté automatiquement : un agent disponible de cette structure est prévenu.'
              : 'Orienté automatiquement : le superviseur va désigner un agent.',
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
                mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.15,
                children: [
                  for (final c in config.categories) TuileCategorie(c, choisie: _type == c.code,
                      onTap: () { setState(() { _type = c.code; _etape = 1; }); _sauver(); }),
                ],
              ),
              const SizedBox(height: 6),
              Text('Photos d’exemple sous licence libre : elles illustrent le type, ce ne sont pas des incidents réels.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
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
            if (_etape == 3) ...[
              Text('Vérifiez puis envoyez', style: titre(18)),
              const SizedBox(height: 10),
              Carte(child: Column(children: [
                LigneInfo('Type', config.categorie(_type)?.libelle ?? '—'),
                LigneInfo('Description', _description.text.trim().isEmpty ? '—' : _description.text.trim()),
                LigneInfo('Lieu', '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}${_precision != null ? ' (GPS ± ${_precision!.round()} m)' : ''}'),
                if (_adresse.text.trim().isNotEmpty) LigneInfo('Repère', _adresse.text.trim()),
                const LigneInfo('Destinataire', 'Choisi automatiquement : la structure compétente la plus proche'),
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
                onPressed: !_etapeValide || _envoi ? null : (_etape < 3 ? _suivant : _envoyer),
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
