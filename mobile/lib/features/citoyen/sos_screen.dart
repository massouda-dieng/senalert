import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/format.dart';
import '../../core/location.dart';
import '../../core/models.dart';
import '../../state/configuration.dart';
import '../../ui/kit.dart';
import '../../state/langue.dart';
import 'report_screen.dart' show formatImageAccepte;

enum _Etape { decompte, envoi, succes, echec }

/// Parcours SOS : 5 s annulables, type d'urgence facultatif (un appui envoie aussitôt),
/// position jointe si disponible (jamais inventée), résultat affiché uniquement après
/// confirmation du serveur, avec ce qui a réellement été enregistré.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  static const _duree = 5;
  final String _cle = nouvelleCle(); // réutilisée pour chaque nouvel essai : jamais deux alertes
  _Etape _etape = _Etape.decompte;
  int _reste = _duree;
  Timer? _minuteur;
  Timer? _suivi;
  Position2? _position;
  bool _positionEnCours = true;
  Dossier? _dossier;
  String _typeUrgence = 'non_precise';
  bool _dejaRecue = false;
  ApiException? _erreur;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    Localisation.lire().then((p) { if (mounted) setState(() { _position = p; _positionEnCours = false; }); });
    _minuteur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _reste--);
      HapticFeedback.selectionClick();
      if (_reste <= 0) { t.cancel(); _envoyer(); }
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _suivi?.cancel();
    super.dispose();
  }

  Future<void> _envoyer() async {
    _minuteur?.cancel();
    // Un seul envoi à la fois ; la clé d'idempotence protège aussi contre un renvoi réseau.
    if (_etape == _Etape.envoi || _etape == _Etape.succes) return;
    setState(() { _etape = _Etape.envoi; _erreur = null; });
    final corps = <String, dynamic>{'client_request_id': _cle, 'type_urgence': _typeUrgence};
    if (_position?.ok == true) {
      corps.addAll({'latitude': _position!.lat, 'longitude': _position!.lng, 'precision_gps': _position!.precision?.round()});
    }
    try {
      final r = await Api.instance.post<Map<String, dynamic>>('/alertes/sos/', data: corps);
      HapticFeedback.heavyImpact();
      setState(() { _dossier = Dossier.depuis(r, estSos: true); _dejaRecue = r['deja_enregistree'] == true; _etape = _Etape.succes; });
      _suivi = Timer.periodic(const Duration(seconds: 10), (_) => _actualiser());
    } on ApiException catch (e) {
      setState(() { _erreur = e; _etape = _Etape.echec; });
    }
  }

  /// Repli sans internet : ouvre l'application SMS avec un message prérempli (position GPS incluse).
  Future<void> _envoyerSms() async {
    final numero = context.read<Configuration>().smsSecours;
    if (numero == null) return;
    final p = _position;
    final texte = p?.ok == true
        ? 'SOS SenAlert - position ${p!.lat!.toStringAsFixed(5)},${p.lng!.toStringAsFixed(5)} (±${p.precision?.round()} m) https://maps.google.com/?q=${p.lat},${p.lng}'
        : 'SOS SenAlert - position inconnue';
    await launchUrl(Uri(scheme: 'sms', path: numero, queryParameters: {'body': texte}));
  }

  Future<void> _actualiser() async {
    if (_dossier == null) return;
    try {
      final r = await Api.instance.get<Map<String, dynamic>>(_dossier!.chemin);
      if (mounted) setState(() => _dossier = Dossier.depuis(r, estSos: true));
    } catch (_) {/* on garde le dernier état connu */}
  }

  @override
  Widget build(BuildContext context) {
    final numeros = context.watch<Configuration>().numeros;
    return PopScope(
      canPop: _etape != _Etape.envoi,
      child: Scaffold(
        backgroundColor: AppColors.marine900,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: Text(tr('Alerte SOS'), style: titre(19, couleur: Colors.white))),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            if (_etape == _Etape.decompte) ...[
              const SizedBox(height: 12),
              Text(tr('Envoi automatique dans'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              Center(child: SizedBox(width: 190, height: 190, child: Stack(alignment: Alignment.center, children: [
                // Anneau qui se vide en 5 s : l'utilisateur voit le temps restant pour annuler.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: (_reste + 1) / _duree, end: _reste / _duree),
                  duration: const Duration(seconds: 1),
                  key: ValueKey(_reste),
                  builder: (_, v, __) => SizedBox.expand(child: CircularProgressIndicator(
                      value: v.clamp(0, 1), strokeWidth: 10, strokeCap: StrokeCap.round,
                      color: Jetons.surSombreRouge, backgroundColor: Colors.white12)),
                ),
                Semantics(liveRegion: true, child: Text('$_reste', style: titre(88, couleur: Colors.white))),
              ]))),
              const SizedBox(height: 16),
              _infoPosition(),
              const SizedBox(height: 24),
              Text(tr('Quelle urgence ? (facultatif, envoie aussitôt)'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6,
                children: [
                  for (final t in typesUrgence.entries)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(horizontal: 10)),
                      onPressed: () { _typeUrgence = t.key; _envoyer(); },
                      icon: Icon(t.value.$2, size: 20),
                      label: Text(tr(t.value.$1), maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.rougeFonce, minimumSize: const Size.fromHeight(60)),
                  onPressed: _envoyer, child: Text(tr('Envoyer maintenant'))),
              const SizedBox(height: 12),
              OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38), minimumSize: const Size.fromHeight(56)),
                  onPressed: () => context.pop(), child: Text(tr('Annuler'))),
            ],
            if (_etape == _Etape.envoi) Padding(padding: const EdgeInsets.only(top: 80), child: Column(children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(tr('Transmission au serveur SenAlert…'), style: const TextStyle(color: Colors.white70)),
            ])),
            if (_etape == _Etape.succes && _dossier != null) ...[
              const Icon(Icons.check_circle_rounded, color: Jetons.surSombreVert, size: 72),
              const SizedBox(height: 12),
              Text(tr('Alerte enregistrée'), textAlign: TextAlign.center, style: titre(24, couleur: Colors.white)),
              const SizedBox(height: 6),
              SelectableText(_dossier!.reference, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              Carte(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(tr('Statut'), style: TextStyle(color: AppColors.textGrey, fontSize: 13))), BadgeStatut(_dossier!.statut)]),
                LigneInfo('Urgence', _dossier!.typeUrgenceLibelle ?? 'Non précisée'),
                LigneInfo('Envoyée le', dateHeure(_dossier!.creation)),
                LigneInfo('Position', _dossier!.lat == null ? 'Non jointe'
                    : '${_dossier!.lat!.toStringAsFixed(5)}, ${_dossier!.lng!.toStringAsFixed(5)}${_dossier!.precision != null ? ' (± ${_dossier!.precision!.round()} m)' : ''}'),
                LigneInfo('Destinataire', _dossier!.structureNom ?? 'Supervision SenAlert'),
                const SizedBox(height: 6),
                Text(_dejaRecue ? 'Cette alerte avait déjà été reçue : voici son suivi.'
                    : 'Le superviseur de cette structure a été prévenu : il affecte un agent.'),
                const SizedBox(height: 8),
                Text(tr('Tant qu’un agent ne l’a pas prise en charge, aucune intervention n’est garantie.'),
                    style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              ])),
              const SizedBox(height: 12),
              ComplementSos(dossier: _dossier!, onMaj: (d) => setState(() => _dossier = d)),
              if (_dossier!.lat == null) const Padding(padding: EdgeInsets.only(top: 12),
                  child: Bandeau.alerte('Votre position n’a pas pu être jointe. Indiquez votre lieu exact aux secours par téléphone.')),
              const SizedBox(height: 18),
              Text(tr('Danger immédiat : appelez aussi les secours.'), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              NumerosUrgence(numeros, sombre: true),
              const SizedBox(height: 18),
              FilledButton(onPressed: () => context.go('/dossier/sos/${_dossier!.id}'), child: Text(tr('Voir le détail de l’alerte'))),
              const SizedBox(height: 8),
              OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                  onPressed: () => context.go('/dossiers?type=sos'), child: Text(tr('Historique de mes SOS'))),
            ],
            if (_etape == _Etape.echec) ...[
              const Icon(Icons.error_rounded, color: Jetons.surSombreRouge, size: 72),
              const SizedBox(height: 12),
              Text(tr('L’alerte n’a PAS été transmise'), textAlign: TextAlign.center, style: titre(22, couleur: Colors.white)),
              const SizedBox(height: 8),
              Text(_erreur?.message ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              Text(tr('Appelez immédiatement les secours :'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final n in numeros) Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: AppColors.rougeFonce, minimumSize: const Size.fromHeight(58)),
                    onPressed: () => appeler(n.numero), icon: const Icon(Icons.call), label: Text('${n.service} · ${n.numero}')),
              ),
              OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                  onPressed: _envoyer, icon: const Icon(Icons.refresh), label: Text(tr('Réessayer l’envoi'))),
              if (context.read<Configuration>().smsSecours != null) Padding(
                padding: const EdgeInsets.only(top: 10),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38)),
                  onPressed: _envoyerSms, icon: const Icon(Icons.sms_outlined), label: Text(tr('Envoyer le SOS par SMS (sans internet)'))),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _infoPosition() {
    if (_positionEnCours) {
      return Text(tr('Recherche de votre position…'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70));
    }
    if (_position?.ok != true) {
      return Text('${tr(_position?.erreur ?? 'Position indisponible.')} ${tr('L’alerte sera envoyée sans position.')}',
          textAlign: TextAlign.center, style: const TextStyle(color: Jetons.surSombreOrange));
    }
    final p = _position!.precision ?? 0;
    return Text('${tr('Position obtenue · précision ± {m} m', {'m': p.round()})}${p > 100 ? ' (approximative)' : ''}',
        textAlign: TextAlign.center, style: TextStyle(color: p > 100 ? Jetons.surSombreOrange : Jetons.surSombreVertPale));
  }
}

/// Après l'envoi du SOS : choisir une autre structure (tant que l'alerte n'est pas affectée) et joindre des photos.
class ComplementSos extends StatefulWidget {
  final Dossier dossier;
  final ValueChanged<Dossier> onMaj;
  const ComplementSos({super.key, required this.dossier, required this.onMaj});
  @override
  State<ComplementSos> createState() => _ComplementSosState();
}

class _ComplementSosState extends State<ComplementSos> {
  List<Map<String, dynamic>> _proches = [];
  String? _envoi;

  Dossier get d => widget.dossier;
  bool get _modifiable => d.statut == 'nouveau' && d.lat != null;

  @override
  void initState() {
    super.initState();
    if (_modifiable) _chargerProches();
  }

  Future<void> _chargerProches() async {
    try {
      final r = await Api.instance.get<List<dynamic>>('/structures/',
          params: {'lat': d.lat, 'lng': d.lng, 'type_urgence': d.typeUrgence ?? 'non_precise', 'limite': 6});
      if (mounted) setState(() => _proches = r.cast<Map<String, dynamic>>());
    } on ApiException {/* le choix reste celui du serveur */}
  }

  Future<void> _agir(String cle, String chemin, Object corps) async {
    setState(() => _envoi = cle);
    try {
      final r = await Api.instance.post<Map<String, dynamic>>('${d.chemin}$chemin/', data: corps);
      widget.onMaj(Dossier.depuis(r, estSos: true));
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    } finally {
      if (mounted) setState(() => _envoi = null);
    }
  }

  Future<void> _ajouterPhoto() async {
    final source = kIsWeb ? ImageSource.gallery : await showModalBottomSheet<ImageSource>(context: context, builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Prendre une photo'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choisir dans la galerie'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ])));
    if (source == null) return;
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 2048, imageQuality: 82);
      if (x == null) return;
      final octets = await x.readAsBytes();
      if (!mounted) return;
      if (octets.length > 5 * 1024 * 1024 || !formatImageAccepte(octets)) {
        return afficherMessage(context, 'Photo refusée : JPEG, PNG ou WEBP de 5 Mo maximum.', erreur: true);
      }
      await _agir('photo', 'completer', FormData.fromMap({'photos': MultipartFile.fromBytes(octets, filename: 'photo.jpg')}));
    } catch (_) {
      if (mounted) afficherMessage(context, 'Impossible d’ouvrir l’appareil photo ou la galerie.', erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) => Carte(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_modifiable && _proches.length > 1) ...[
          Text(tr('Structure prévenue'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: _proches.any((s) => s['id'] == d.structureId) ? d.structureId : null,
            items: [for (final s in _proches) DropdownMenuItem(value: s['id'] as int,
                child: Text('${s['nom']} — ${s['service_nom']}${s['distance_m'] != null ? ' (${distance(s['distance_m'])})' : ''}',
                    overflow: TextOverflow.ellipsis))],
            onChanged: _envoi != null ? null : (v) { if (v != null && v != d.structureId) _agir('structure', 'changer-structure', {'structure': v}); },
          ),
          const SizedBox(height: 12),
        ],
        Row(children: [
          Expanded(child: Text(d.photos.isEmpty ? tr('Aucune photo jointe') : '${d.photos.length} photo(s) jointe(s)')),
          if (d.photos.length < 5 && d.statut != 'resolu')
            OutlinedButton.icon(onPressed: _envoi != null ? null : _ajouterPhoto,
                icon: _envoi == 'photo' ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_a_photo_outlined),
                label: Text(tr('Ajouter une photo'))),
        ]),
      ]));
}
