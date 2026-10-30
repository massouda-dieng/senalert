import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/format.dart';
import '../../core/location.dart';
import '../../core/models.dart';
import '../../state/session.dart';
import '../../ui/kit.dart';
import '../../state/langue.dart';

/// Liste paginée de dossiers (incidents ou SOS) avec recherche et vues simples.
class ListeDossiersScreen extends StatefulWidget {
  final bool agent;
  const ListeDossiersScreen({super.key, this.agent = false});
  @override
  State<ListeDossiersScreen> createState() => _ListeDossiersScreenState();
}

class _ListeDossiersScreenState extends State<ListeDossiersScreen> with SingleTickerProviderStateMixin {
  late final TabController _onglets = TabController(length: 2, vsync: this)..addListener(() { if (!_onglets.indexIsChanging) _recharger(); });
  final _recherche = TextEditingController();
  int _vue = 0;
  Map<String, int> _compteurs = {};
  final List<Dossier> _elements = [];
  int _page = 1;
  bool _suivante = false;
  bool _chargement = false;
  ApiException? _erreur;
  DateTime? _synchro;

  bool get _sos => _onglets.index == 1;

  List<(String, Map<String, dynamic>)> get _vues => widget.agent
      ? const [('Ouverts', {'actifs': true}), ('Mes interventions', {'actifs': true, 'affecte_a_moi': true}), ('Tous', {})]
      : const [('Tous', {}), ('En cours', {'actifs': true})];

  @override
  void initState() {
    super.initState();
    _recharger();
  }

  Future<void> _recharger() async {
    _page = 1;
    _elements.clear();
    if (widget.agent) _chargerCompteurs();
    await _charger();
  }

  Future<void> _chargerCompteurs() async {
    try {
      final r = await Future.wait([
        for (final c in ['/incidents/', '/alertes/sos/']) Api.instance.get<Map<String, dynamic>>(c, params: {'actifs': true, 'taille': 1}),
      ]);
      if (mounted) setState(() => _compteurs = {'incident': (r[0]['count'] as num).toInt(), 'sos': (r[1]['count'] as num).toInt()});
    } on ApiException {
      // Les onglets restent sans nombre : la liste affiche l'erreur réseau.
    }
  }

  Future<void> _charger() async {
    if (_chargement) return;
    setState(() { _chargement = true; _erreur = null; });
    try {
      final r = await Api.instance.get<Map<String, dynamic>>(_sos ? '/alertes/sos/' : '/incidents/', params: {
        'page': _page, 'q': _recherche.text.trim(), ..._vues[_vue].$2,
      });
      setState(() {
        _elements.addAll((r['results'] as List).map((j) => Dossier.depuis(j, estSos: _sos)));
        _suivante = r['next'] != null;
        _synchro = DateTime.now();
      });
    } on ApiException catch (e) {
      setState(() => _erreur = e);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.agent ? 'Interventions' : 'Mes dossiers'),
        bottom: TabBar(controller: _onglets, tabs: [
          Tab(text: 'Incidents${_compteurs['incident'] != null ? ' (${_compteurs['incident']})' : ''}'),
          Tab(text: 'Alertes SOS${_compteurs['sos'] != null ? ' (${_compteurs['sos']})' : ''}'),
        ]),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _recherche, textInputAction: TextInputAction.search, onSubmitted: (_) => _recharger(),
            decoration: InputDecoration(hintText: 'Référence, adresse…', prefixIcon: const Icon(Icons.search),
                suffixIcon: _recherche.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), tooltip: 'Effacer', onPressed: () { _recherche.clear(); _recharger(); })),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (var i = 0; i < _vues.length; i++)
              Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(
                label: Text(_vues[i].$1), selected: _vue == i, onSelected: (_) { setState(() => _vue = i); _recharger(); })),
          ]),
        ),
        if (_synchro != null) Padding(padding: const EdgeInsets.only(bottom: 4),
            child: Text('Actualisé ${ilYa(_synchro)} · tirez pour rafraîchir', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted))),
        Expanded(child: RefreshIndicator(
          onRefresh: _recharger,
          child: _erreur != null && _elements.isEmpty
              ? ListView(children: [EtatErreur(_erreur!, onReessayer: _recharger)])
              : _elements.isEmpty && _chargement
                  ? const Chargement()
                  : _elements.isEmpty
                      ? ListView(children: [EtatVide(icone: Icons.inbox_rounded, titre: 'Aucun dossier',
                          texte: widget.agent ? 'Les dossiers de votre zone apparaîtront ici.' : 'Vos signalements apparaîtront ici.',
                          action: widget.agent ? null : FilledButton(onPressed: () => context.push('/signaler'), child: const Text('Signaler un incident')))])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _elements.length + (_suivante ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            if (i == _elements.length) {
                              return Center(child: TextButton(onPressed: _chargement ? null : () { _page++; _charger(); }, child: const Text('Charger plus')));
                            }
                            final d = _elements[i];
                            return TuileDossier(d, onTap: () => context.push('/dossier/${d.estSos ? 'sos' : 'incident'}/${d.id}').then((_) => _recharger()));
                          },
                        ),
        )),
      ]),
    );
  }
}

/// Détail d'un dossier : informations, chronologie et actions autorisées pour le rôle.
class DossierScreen extends StatefulWidget {
  final bool sos;
  final int id;
  const DossierScreen({super.key, required this.sos, required this.id});
  @override
  State<DossierScreen> createState() => _DossierScreenState();
}

class _DossierScreenState extends State<DossierScreen> {
  Dossier? _d;
  List<Evenement> _evenements = [];
  ApiException? _erreur;
  bool _action = false;
  Timer? _actualisation;
  // Partage de position de l'agent affecté (toutes les 15 s, jusqu'à la clôture).
  Timer? _partage;
  String? _partageInfo;
  int _note = 0;
  final _commentaire = TextEditingController();

  String get _chemin => widget.sos ? '/alertes/sos/${widget.id}/' : '/incidents/${widget.id}/';
  bool get _enIntervention => const {'accepte', 'en_cours'}.contains(_d?.statut);

  @override
  void initState() {
    super.initState();
    _charger();
    _actualisation = Timer.periodic(const Duration(seconds: 15), (_) { if (mounted && !_action) _charger(); });
  }

  @override
  void dispose() {
    _actualisation?.cancel();
    _partage?.cancel();
    _commentaire.dispose();
    super.dispose();
  }

  void _basculerPartage() {
    if (_partage != null) {
      _partage!.cancel();
      setState(() { _partage = null; _partageInfo = null; });
      return;
    }
    setState(() { _partage = Timer.periodic(const Duration(seconds: 15), (_) => _envoyerPosition()); _partageInfo = 'Recherche de votre position…'; });
    _envoyerPosition();
  }

  Future<void> _envoyerPosition() async {
    if (!_enIntervention) { _partage?.cancel(); if (mounted) setState(() => _partage = null); return; }
    final p = await Localisation.lire(delai: const Duration(seconds: 10));
    if (!mounted || _partage == null) return;
    if (!p.ok) { setState(() => _partageInfo = p.erreur); return; }
    try {
      final r = await Api.instance.post<Map<String, dynamic>>('${_chemin}position-agent/',
          data: {'latitude': p.lat, 'longitude': p.lng, 'precision': p.precision});
      final dist = r['distance_m'] as num?;
      if (mounted) setState(() => _partageInfo = 'Envoyée à ${TimeOfDay.now().format(context)}${dist != null ? ' · ${distanceLisible(dist)} du lieu' : ''}');
    } on ApiException catch (e) {
      if (mounted) setState(() => _partageInfo = e.message);
    }
  }

  Future<void> _charger() async {
    try {
      final d = await Api.instance.get<Map<String, dynamic>>(_chemin);
      final e = await Api.instance.get<List>('${_chemin}evenements/');
      setState(() {
        _d = Dossier.depuis(d, estSos: widget.sos);
        _evenements = e.map((x) => Evenement.depuis(x)).toList();
        _erreur = null;
      });
    } on ApiException catch (e) {
      setState(() => _erreur = e);
    }
  }

  Future<void> _agir(String action, String message, [Map<String, dynamic>? corps]) async {
    setState(() => _action = true);
    try {
      await Api.instance.post('$_chemin$action/', data: corps);
      if (mounted) afficherMessage(context, message);
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    } finally {
      await _charger();
      if (mounted) setState(() => _action = false);
    }
  }

  Future<void> _cloturer() async {
    final cr = TextEditingController();
    final diff = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: StatefulBuilder(builder: (c, setState) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Clôturer l’intervention', style: titre(19)),
          const SizedBox(height: 14),
          TextField(controller: cr, maxLines: 4, maxLength: 4000, onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Compte rendu (visible par le citoyen)', helperText: '10 caractères minimum')),
          const SizedBox(height: 8),
          TextField(controller: diff, maxLines: 2, maxLength: 2000, decoration: const InputDecoration(labelText: 'Difficultés rencontrées (interne)')),
          const SizedBox(height: 12),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: cr.text.trim().length < 10 ? null : () => Navigator.pop(c, true), child: const Text('Clôturer comme résolu')),
        ])),
      ),
    );
    if (ok == true) await _agir('resoudre', 'Intervention clôturée.', {'compte_rendu': cr.text.trim(), 'difficultes': diff.text.trim()});
  }

  Future<void> _completer() async {
    final motif = await confirmer(context, titre: 'Compléter le signalement', message: 'Ajoutez une information utile aux secours.',
        motif: 'Information complémentaire', action: 'Envoyer');
    if (motif != null && motif.isNotEmpty) await _agir('completer', 'Complément envoyé.', {'message': motif});
  }

  List<Widget> _actions(Utilisateur u, Dossier d) {
    final mien = d.agentId == u.id;
    final b = <Widget>[];
    Widget bouton(String libelle, IconData icone, VoidCallback f, {Color? couleur, bool plein = true}) => plein
        ? FilledButton.icon(style: couleur == null ? null : FilledButton.styleFrom(backgroundColor: couleur), onPressed: _action ? null : f, icon: Icon(icone), label: Text(libelle))
        : OutlinedButton.icon(onPressed: _action ? null : f, icon: Icon(icone), label: Text(libelle));
    if (u.estCitoyen && d.estProprietaire) {
      if (!d.estClos && !d.estSos) b.add(bouton(tr('Compléter'), Icons.add_comment_outlined, _completer, plein: false));
      if (const {'nouveau', 'affecte'}.contains(d.statut)) {
        b.add(bouton(tr('Annuler'), Icons.cancel_outlined, () async {
          final m = await confirmer(context, titre: 'Annuler le dossier', message: 'Le dossier sera clos avec le statut « Annulé ».',
              motif: 'Motif', action: 'Annuler le dossier', danger: true);
          if (m != null) await _agir('annuler', 'Dossier annulé.', {'motif': m});
        }, plein: false));
      }
    }
    if (u.estAgent) {
      if (d.statut == 'nouveau') b.add(bouton('Prendre en charge', Icons.how_to_reg, () => _agir('prendre-en-charge', 'Dossier pris en charge.')));
      if (d.statut == 'affecte' && mien) {
        b.add(bouton('Accepter', Icons.check, () => _agir('accepter', 'Intervention acceptée.')));
        b.add(bouton('Décliner', Icons.close, () async {
          final m = await confirmer(context, titre: 'Décliner l’affectation', message: 'Le superviseur sera prévenu.', motif: 'Raison', action: 'Décliner');
          if (m != null) await _agir('decliner', 'Affectation déclinée.', {'motif': m});
        }, plein: false));
      }
      if (d.statut == 'accepte' && mien) b.add(bouton('Démarrer l’intervention', Icons.play_arrow_rounded, () => _agir('demarrer', 'Intervention démarrée.')));
      if (const {'accepte', 'en_cours'}.contains(d.statut) && mien) b.add(bouton('Clôturer', Icons.flag_rounded, _cloturer, couleur: AppColors.success));
      if (d.lat != null) b.add(bouton('Itinéraire', Icons.navigation_rounded, () => itineraire(d.lat!, d.lng!), plein: false));
    }
    return b;
  }

  Widget _evaluation(Dossier d) {
    final note = d.intervention!['note_satisfaction'] as int?;
    if (note != null) {
      final com = (d.intervention!['commentaire_satisfaction'] ?? '').toString();
      return Carte(couleur: AppColors.jaune.withOpacity(.18), child: Row(children: [
        _Etoiles(note),
        const SizedBox(width: 10),
        Expanded(child: Text('${tr(libellesNote[note]!)}${com.isEmpty ? '' : ' · « $com »'}', style: const TextStyle(fontWeight: FontWeight.w600))),
      ]));
    }
    return Carte(couleur: AppColors.jaune.withOpacity(.18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('Comment s’est passée l’intervention ?'), style: titre(16)),
      const SizedBox(height: 2),
      Text(tr('Votre avis aide à améliorer les services de secours.'), style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
      const SizedBox(height: 6),
      Row(children: [
        for (var n = 1; n <= 5; n++)
          IconButton(tooltip: '$n sur 5', visualDensity: VisualDensity.compact, onPressed: () => setState(() => _note = n),
              icon: Icon(n <= _note ? Icons.star_rounded : Icons.star_border_rounded, size: 32, color: n <= _note ? const Color(0xFFF5B400) : AppColors.textGrey)),
      ]),
      if (_note > 0) ...[
        Text(tr(libellesNote[_note]!), style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(controller: _commentaire, maxLength: 500, maxLines: 2, decoration: InputDecoration(labelText: tr('Un commentaire ? (facultatif)'))),
        FilledButton.icon(onPressed: _action ? null : () => _agir('evaluer', tr('Merci pour votre évaluation !'), {'note': _note, 'commentaire': _commentaire.text.trim()}),
            icon: const Icon(Icons.send_rounded), label: Text(tr('Envoyer mon avis'))),
      ],
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Session>().utilisateur!;
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: Text(d?.reference ?? 'Dossier'), actions: [IconButton(tooltip: 'Actualiser', onPressed: _charger, icon: const Icon(Icons.refresh))]),
      body: _erreur != null && d == null
          ? EtatErreur(_erreur!, onReessayer: _charger)
          : d == null
              ? const Chargement()
              : RefreshIndicator(
                  onRefresh: _charger,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Row(children: [
                      Expanded(child: Text(d.estSos ? tr('Alerte SOS') : Langue.instance.categorie(d.typeIncident, d.titre), style: titre(22))),
                      BadgeStatut(d.statut),
                    ]),
                    const SizedBox(height: 4),
                    Text('${d.regionLibelle.isEmpty ? 'Région inconnue' : d.regionLibelle} · ${dateHeure(d.creation)}',
                        style: TextStyle(color: AppColors.textGrey)),
                    if (d.enRetard) const Padding(padding: EdgeInsets.only(top: 10), child: Bandeau.alerte('Pas encore pris en charge dans le délai prévu.')),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: _actions(u, d)),
                    if (u.estAgent && d.agentId == u.id && _enIntervention) Padding(padding: const EdgeInsets.only(top: 12), child: _CartePartage(
                        actif: _partage != null, info: _partageInfo, onBasculer: _basculerPartage)),
                    if (!u.estAgent && _enIntervention && d.intervention?['position_agent'] != null)
                      Padding(padding: const EdgeInsets.only(top: 12), child: _AgentEnRoute(Map<String, dynamic>.from(d.intervention!['position_agent']))),
                    if (d.statut == 'resolu' && d.intervention != null &&
                        (d.intervention!['note_satisfaction'] != null || (u.estCitoyen && d.estProprietaire)))
                      Padding(padding: const EdgeInsets.only(top: 12), child: _evaluation(d)),
                    if (d.description.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Carte(couleur: AppColors.surfaceSubtle, child: Text(d.description)),
                    ],
                    const SizedBox(height: 12),
                    Carte(child: Column(children: [
                      LigneInfo('Gravité', gravites[d.gravite] ?? d.gravite),
                      if (d.serviceNom != null) LigneInfo('Service', d.serviceNom!),
                      if (d.adresse.isNotEmpty) LigneInfo('Repère', d.adresse),
                      LigneInfo('Position', d.lat == null ? 'Indisponible' : '${d.lat!.toStringAsFixed(5)}, ${d.lng!.toStringAsFixed(5)}${d.precision != null ? ' (± ${d.precision!.round()} m)' : ''}'),
                      if (d.priseEnCharge != null) LigneInfo('Prise en charge', dateHeure(d.priseEnCharge)),
                      if (d.intervention != null) LigneInfo('Intervenant', '${d.intervention!['agent_nom'] ?? 'Non affecté'}${d.intervention!['service_nom'] != null ? ' · ${d.intervention!['service_nom']}' : ''}'),
                      if (d.cloture != null) LigneInfo('Clôture', dateHeure(d.cloture)),
                      if (d.motifCloture.isNotEmpty) LigneInfo('Motif', d.motifCloture),
                    ])),
                    if (d.contact != null) Padding(padding: const EdgeInsets.only(top: 12), child: Carte(child: Row(children: [
                      const Icon(Icons.person_outline),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Déclarant : ${d.contact!['nom']}')),
                      if ((d.contact!['telephone'] ?? '').toString().isNotEmpty)
                        TextButton.icon(onPressed: () => appeler(d.contact!['telephone']), icon: const Icon(Icons.call), label: Text(d.contact!['telephone'])),
                    ]))),
                    if ((d.intervention?['compte_rendu'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12),
                        child: Bandeau.succes(d.intervention!['compte_rendu'], titre: 'Compte rendu')),
                    if (d.photos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(height: 96, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: d.photos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) => _Photo(d.photos[i]['url']))),
                    ],
                    if (d.lat != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(height: 200, child: FlutterMap(
                        key: ValueKey(d.intervention?['position_agent']?['date']),
                        options: _enIntervention && d.intervention?['position_agent'] != null
                            ? MapOptions(initialCameraFit: CameraFit.coordinates(padding: const EdgeInsets.all(40), coordinates: [
                                LatLng(d.lat!, d.lng!),
                                LatLng((d.intervention!['position_agent']['lat'] as num).toDouble(), (d.intervention!['position_agent']['lng'] as num).toDouble()),
                              ]))
                            : MapOptions(initialCenter: LatLng(d.lat!, d.lng!), initialZoom: 15),
                        children: [
                          TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}', userAgentPackageName: 'sn.senalert.mobile'),
                          MarkerLayer(markers: [
                            Marker(point: LatLng(d.lat!, d.lng!), width: 36, height: 36,
                                child: Icon(Icons.location_on, size: 36, color: d.estSos ? AppColors.crimson : AppColors.vert700)),
                            if (_enIntervention && d.intervention?['position_agent'] != null)
                              Marker(point: LatLng((d.intervention!['position_agent']['lat'] as num).toDouble(), (d.intervention!['position_agent']['lng'] as num).toDouble()),
                                  width: 34, height: 34, child: const CircleAvatar(backgroundColor: Color(0xFF1E3A8A), child: Icon(Icons.local_shipping, size: 18, color: Colors.white))),
                          ]),
                          const RichAttributionWidget(attributions: [TextSourceAttribution('Fond © Esri · © contributeurs OpenStreetMap')]),
                        ],
                      ))),
                    ],
                    const SizedBox(height: 20),
                    Text('Historique', style: titre(17)),
                    const SizedBox(height: 8),
                    for (final e in _evenements) _LigneEvenement(e),
                  ]),
                ),
    );
  }
}

const libellesNote = {1: 'Très insatisfait', 2: 'Insatisfait', 3: 'Correct', 4: 'Satisfait', 5: 'Très satisfait'};

String distanceLisible(num m) => m < 1000 ? '${(m / 10).round() * 10} m' : '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

class _Etoiles extends StatelessWidget {
  final int note;
  const _Etoiles(this.note);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var n = 1; n <= 5; n++) Icon(n <= note ? Icons.star_rounded : Icons.star_border_rounded, size: 20, color: const Color(0xFFF5B400)),
      ]);
}

class _CartePartage extends StatelessWidget {
  final bool actif;
  final String? info;
  final VoidCallback onBasculer;
  const _CartePartage({required this.actif, required this.info, required this.onBasculer});
  @override
  Widget build(BuildContext context) => Carte(
        couleur: actif ? const Color(0xFF1E3A8A).withOpacity(.1) : AppColors.surfaceSubtle,
        child: Row(children: [
          Icon(Icons.my_location, color: actif ? const Color(0xFF1E3A8A) : AppColors.textGrey),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(actif ? 'Position partagée avec le déclarant' : 'Partager ma position en direct', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(info ?? 'Le déclarant voit votre progression jusqu’à la clôture.', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ])),
          TextButton(onPressed: onBasculer, child: Text(actif ? 'Arrêter' : 'Partager')),
        ]),
      );
}

class _AgentEnRoute extends StatelessWidget {
  final Map<String, dynamic> position;
  const _AgentEnRoute(this.position);
  @override
  Widget build(BuildContext context) {
    final dist = position['distance_m'] as num?;
    return Carte(
      couleur: const Color(0xFF1E3A8A).withOpacity(.1),
      child: Row(children: [
        const CircleAvatar(radius: 22, backgroundColor: Color(0xFF1E3A8A), child: Icon(Icons.local_shipping, color: Colors.white)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('Les secours sont en route'), style: titre(16)),
          Text('${dist != null ? tr('L’agent est à environ {d} du lieu', {'d': distanceLisible(dist)}) : 'Position de l’agent disponible'} · ${ilYa(lireDate(position['date']))}',
              style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
        ])),
      ]),
    );
  }
}

class _LigneEvenement extends StatelessWidget {
  final Evenement e;
  const _LigneEvenement(this.e);
  @override
  Widget build(BuildContext context) {
    final s = statut(e.statutApres);
    const libelles = {'creation': 'Création', 'affectation': 'Affectation', 'complement': 'Complément', 'note': 'Note', 'gravite': 'Gravité', 'doublon': 'Doublon potentiel'};
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(margin: const EdgeInsets.only(top: 4), width: 12, height: 12, decoration: BoxDecoration(color: e.type == 'transition' ? s.couleur : AppColors.textMuted, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.type == 'transition' ? s.libelle : (libelles[e.type] ?? e.type) + (e.visibleCitoyen ? '' : ' · interne'), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (e.message.isNotEmpty) Text(e.message, style: TextStyle(color: AppColors.textGrey)),
          Text('${dateHeure(e.date)} · ${e.acteur}', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ])),
      ]),
    );
  }
}

class _Photo extends StatelessWidget {
  final String url;
  const _Photo(this.url);
  @override
  Widget build(BuildContext context) => FutureBuilder<List<int>>(
        future: Api.instance.octets(url),
        builder: (_, s) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 96, height: 96, child: s.hasData
              ? Image.memory(Uint8List.fromList(s.data!), fit: BoxFit.cover, semanticLabel: 'Photo jointe')
              : Container(color: AppColors.surfaceSubtle, child: s.hasError ? const Icon(Icons.broken_image_outlined) : null)),
        ),
      );
}
