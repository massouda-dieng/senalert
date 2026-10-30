import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/format.dart';
import '../../core/location.dart';
import '../../state/configuration.dart';
import '../../state/session.dart';
import '../../ui/kit.dart';
import '../../ui/photo.dart';

/// Incidents récents autour de soi : confirmation « je le vois aussi » et échanges modérés.
class CommunauteScreen extends StatefulWidget {
  const CommunauteScreen({super.key});
  @override
  State<CommunauteScreen> createState() => _CommunauteScreenState();
}

class _CommunauteScreenState extends State<CommunauteScreen> {
  Position2? _position;
  double _rayon = 10;
  List<Map<String, dynamic>> _liste = [];
  ApiException? _erreur;
  bool _chargement = false;

  @override
  void initState() {
    super.initState();
    _charger(localiser: true);
  }

  Future<void> _charger({bool localiser = false}) async {
    setState(() => _chargement = true);
    if (localiser) _position = await Localisation.lire();
    try {
      final r = await Api.instance.get<Map<String, dynamic>>('/incidents/communaute/', params: {
        'jours': 7,
        if (_position?.ok == true) ...{'lat': _position!.lat, 'lng': _position!.lng, 'rayon_km': _rayon},
      });
      _liste = List<Map<String, dynamic>>.from(r['results']);
      _erreur = null;
    } on ApiException catch (e) {
      _erreur = e;
    }
    if (mounted) setState(() => _chargement = false);
  }

  Future<void> _confirmer(Map<String, dynamic> i) async {
    try {
      final chemin = '/incidents/communaute/${i['id']}/confirmer/';
      final r = i['je_confirme'] == true
          ? await Api.instance.delete<Map<String, dynamic>>(chemin)
          : await Api.instance.post<Map<String, dynamic>>(chemin);
      setState(() { i['nb_confirmations'] = r['nb_confirmations']; i['je_confirme'] = r['je_confirme']; });
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<Configuration>();
    final u = context.watch<Session>().utilisateur!;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _charger,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 190 + MediaQuery.of(context).padding.top,
              child: PhotoIllustration('croix-rouge-equipe', credit: false, superposition: DecoratedBox(
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xF2003A1B), Color(0xB3006E33)])),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('Autour de moi', style: titre(26, couleur: Colors.white)),
                    const SizedBox(height: 4),
                    Text(_position?.ok == true ? 'Incidents des 7 derniers jours dans un rayon de ${_rayon.round()} km'
                        : 'Incidents récents (activez la localisation pour trier par distance)', style: const TextStyle(color: Colors.white70)),
                  ]),
                )),
              )),
            ),
          ),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              for (final r in [2.0, 5.0, 10.0, 50.0]) Padding(padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text('${r.round()} km'), selected: _rayon == r, onSelected: (_) { setState(() => _rayon = r); _charger(); })),
              const Spacer(),
              IconButton(tooltip: 'Me localiser', onPressed: () => _charger(localiser: true), icon: const Icon(Icons.my_location)),
            ]),
          )),
          if (_chargement && _liste.isEmpty) const SliverToBoxAdapter(child: Chargement())
          else if (_erreur != null && _liste.isEmpty) SliverToBoxAdapter(child: EtatErreur(_erreur!, onReessayer: _charger))
          else if (_liste.isEmpty) const SliverToBoxAdapter(child: EtatVide(icone: Icons.groups_rounded, titre: 'Aucun incident récent à proximité'))
          else SliverList.builder(
            itemCount: _liste.length,
            itemBuilder: (_, k) {
              final i = _liste[k];
              final c = config.categorie(i['type_incident']);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Carte(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 6, height: 40, decoration: BoxDecoration(color: couleurHex(c?.couleur), borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i['categorie_libelle'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('${i['region_libelle']} · ${ilYa(lireDate(i['date_creation']))}${i['distance_m'] != null ? ' · à ${distance(i['distance_m'])}' : ''}',
                          style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    ])),
                    BadgeStatut(i['statut']),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    if (u.estCitoyen && i['est_mien'] != true)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40), backgroundColor: i['je_confirme'] == true ? AppColors.vert100 : AppColors.surfaceSubtle),
                        onPressed: () => _confirmer(i), icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                        label: Text('${i['je_confirme'] == true ? 'Confirmé' : 'Je le vois aussi'} · ${i['nb_confirmations']}'))
                    else Chip(avatar: const Icon(Icons.thumb_up_alt_outlined, size: 16), label: Text('${i['nb_confirmations']}')),
                    const SizedBox(width: 8),
                    TextButton.icon(onPressed: () => _ouvrirCommentaires(i), icon: const Icon(Icons.chat_bubble_outline, size: 18), label: Text('${i['nb_commentaires']}')),
                  ]),
                ])),
              );
            },
          ),
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(20), child: Text(
              'Positions arrondies (~100 m). Ni description ni identité des déclarants ne sont affichées.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted)))),
        ]),
      ),
    );
  }

  void _ouvrirCommentaires(Map<String, dynamic> i) => showModalBottomSheet(
        context: context, isScrollControlled: true, useSafeArea: true,
        builder: (_) => _Commentaires(incident: i, onChange: _charger),
      );
}

class _Commentaires extends StatefulWidget {
  final Map<String, dynamic> incident;
  final VoidCallback onChange;
  const _Commentaires({required this.incident, required this.onChange});
  @override
  State<_Commentaires> createState() => _CommentairesState();
}

class _CommentairesState extends State<_Commentaires> {
  List<dynamic>? _liste;
  final _ctrl = TextEditingController();
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final r = await Api.instance.get<List>('/incidents/communaute/${widget.incident['id']}/commentaires/');
      if (mounted) setState(() => _liste = r);
    } catch (_) {
      if (mounted) setState(() => _liste = []);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${widget.incident['categorie_libelle']} — ${widget.incident['region_libelle']}', style: titre(18)),
          const SizedBox(height: 8),
          const Bandeau('Messages visibles par tous. N’indiquez ni nom, ni numéro, ni adresse personnelle.'),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: _liste == null ? const Chargement() : _liste!.isEmpty
                ? const Padding(padding: EdgeInsets.all(12), child: Text('Aucun message pour l’instant.', style: TextStyle(color: AppColors.textGrey)))
                : ListView(shrinkWrap: true, children: [
                    for (final c in _liste!) ListTile(
                      dense: true,
                      title: Text(c['auteur_nom'], style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(c['texte']),
                      trailing: Text(ilYa(lireDate(c['date'])), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ),
                  ]),
          ),
          Row(children: [
            Expanded(child: TextField(controller: _ctrl, maxLength: 500, decoration: const InputDecoration(hintText: 'Information utile…', counterText: ''))),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Publier',
              onPressed: _envoi ? null : () async {
                if (_ctrl.text.trim().length < 3) return;
                setState(() => _envoi = true);
                try {
                  await Api.instance.post('/incidents/communaute/${widget.incident['id']}/commentaires/', data: {'texte': _ctrl.text.trim()});
                  _ctrl.clear();
                  await _charger();
                  widget.onChange();
                } on ApiException catch (e) {
                  if (context.mounted) afficherMessage(context, e.message, erreur: true);
                } finally {
                  if (mounted) setState(() => _envoi = false);
                }
              },
              icon: const Icon(Icons.send_rounded),
            ),
          ]),
        ]),
      );
}
