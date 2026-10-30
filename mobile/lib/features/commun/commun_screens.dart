import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/format.dart';
import '../../core/push.dart';
import '../../state/apparence.dart';
import '../../state/configuration.dart';
import '../../state/session.dart';
import '../../ui/kit.dart';
import '../../state/langue.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>>? _liste;
  ApiException? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final r = await Api.instance.get<Map<String, dynamic>>('/notifications/');
      setState(() { _liste = List<Map<String, dynamic>>.from(r['results']); _erreur = null; });
    } on ApiException catch (e) {
      setState(() => _erreur = e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications'), actions: [
          IconButton(tooltip: 'Tout marquer comme lu', icon: const Icon(Icons.done_all), onPressed: () async {
            await Api.instance.post('/notifications/tout-lire/');
            _charger();
          }),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: _erreur != null && _liste == null
              ? ListView(children: [EtatErreur(_erreur!, onReessayer: _charger)])
              : _liste == null
                  ? const Chargement()
                  : _liste!.isEmpty
                      ? ListView(children: const [EtatVide(icone: Icons.notifications_none_rounded, titre: 'Aucune notification')])
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _liste!.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final n = _liste![i];
                            return Carte(
                              couleur: n['lue'] == true ? null : AppColors.vert50,
                              onTap: () async {
                                if (n['lue'] != true) Api.instance.post('/notifications/${n['id']}/lire/').then((_) {}, onError: (_) {});
                                final d = n['dossier'];
                                if (d != null) await context.push('/dossier/${d['type']}/${d['id']}');
                                _charger();
                              },
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(n['titre'], style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(n['message'], style: TextStyle(color: AppColors.textGrey)),
                                const SizedBox(height: 4),
                                Text(ilYa(lireDate(n['date_creation'])), style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              ]),
                            );
                          },
                        ),
        ),
      );
}

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});
  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  Future<void> _preference(String cle, bool valeur) async {
    try {
      final r = await Api.instance.patch<Map<String, dynamic>>('/auth/profil/', data: {'preferences': {cle: valeur}});
      if (mounted) context.read<Session>().remplacerProfil(r);
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  Future<void> _motDePasse() async {
    final u = context.read<Session>().utilisateur!;
    final ancien = TextEditingController();
    final nouveau = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text(u.aMotDePasse ? 'Changer de mot de passe' : 'Définir un mot de passe'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (u.aMotDePasse) TextField(controller: ancien, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe actuel')),
        const SizedBox(height: 10),
        TextField(controller: nouveau, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau mot de passe', helperText: '8 caractères minimum')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Valider'))],
    ));
    if (ok != true || !mounted) return;
    try {
      final r = await Api.instance.post<Map<String, dynamic>>('/auth/mot-de-passe/', data: {'ancien': ancien.text, 'nouveau': nouveau.text});
      if (!mounted) return;
      await context.read<Session>().ouvrirDepuisReponse(r);
      if (mounted) afficherMessage(context, 'Mot de passe modifié. Vos autres sessions ont été fermées.');
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.champs?.values.first is List ? (e.champs!.values.first as List).first.toString() : e.message, erreur: true);
    }
  }

  Future<void> _supprimer() async {
    final u = context.read<Session>().utilisateur!;
    final mdp = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Supprimer mon compte'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Action irréversible : votre compte sera anonymisé et vous serez déconnecté partout.'),
        if (u.aMotDePasse) TextField(controller: mdp, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.crimson), onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer'))],
    ));
    if (ok != true || !mounted) return;
    try {
      await Api.instance.delete('/auth/profil/', data: {'mot_de_passe': mdp.text, 'confirmation': 'SUPPRIMER'});
      if (mounted) await context.read<Session>().deconnexion();
    } on ApiException catch (e) {
      if (mounted) afficherMessage(context, e.message, erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final u = session.utilisateur!;
    final config = context.watch<Configuration>();
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Carte(child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: AppColors.vert800,
              child: Text(u.nomAffiche.isEmpty ? '?' : u.nomAffiche[0].toUpperCase(), style: titre(22, couleur: Colors.white))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.nomAffiche, style: titre(18)),
            Text(u.email, style: TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 4),
            Text('${u.roleLibelle}${u.serviceNom != null ? ' · ${u.serviceNom}' : ''}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.vert700)),
          ])),
        ])),
        if (u.doitChangerMotDePasse) const Padding(padding: EdgeInsets.only(top: 12), child: Bandeau.alerte('Votre compte utilise un mot de passe initial : remplacez-le.')),
        const SizedBox(height: 16),
        Text('Apparence', style: titre(16)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'systeme', label: Text('Système'), icon: Icon(Icons.brightness_auto_outlined)),
            ButtonSegment(value: 'clair', label: Text('Clair'), icon: Icon(Icons.light_mode_outlined)),
            ButtonSegment(value: 'sombre', label: Text('Sombre'), icon: Icon(Icons.dark_mode_outlined)),
          ],
          selected: {context.watch<Apparence>().mode},
          onSelectionChanged: (s) => context.read<Apparence>().choisir(s.first),
        ),
        if (u.estCitoyen) ...[
          const SizedBox(height: 16),
          Text(tr('Langue de l’espace citoyen'), style: titre(16)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'fr', label: Text('Français')),
              ButtonSegment(value: 'wo', label: Text('Wolof')),
            ],
            selected: {context.watch<Langue>().choix},
            onSelectionChanged: (s) => context.read<Langue>().choisir(s.first),
          ),
        ],
        const SizedBox(height: 16),
        Text('Notifications', style: titre(16)),
        SwitchListTile(value: u.preferences['notifications_push'] != false, onChanged: (v) => _preference('notifications_push', v),
            title: const Text('Notifications push'), subtitle: Text(Push.instance.disponible ? 'Sur cet appareil' : 'Firebase non configuré sur cet appareil : consultez la cloche de l’accueil')),
        if (u.estCitoyen) SwitchListTile(value: u.preferences['notifications_statut'] != false, onChanged: (v) => _preference('notifications_statut', v),
            title: const Text('Évolution de mes dossiers')),
        const Divider(height: 28),
        ListTile(leading: const Icon(Icons.key_outlined), title: Text(u.aMotDePasse ? 'Changer de mot de passe' : 'Définir un mot de passe'), onTap: _motDePasse),
        ListTile(leading: const Icon(Icons.devices_outlined), title: const Text('Se déconnecter de tous les appareils'),
            onTap: () => context.read<Session>().deconnexion(partout: true)),
        ListTile(leading: const Icon(Icons.logout), title: const Text('Se déconnecter'), onTap: () => context.read<Session>().deconnexion()),
        if (!u.estSuperadmin) ListTile(leading: const Icon(Icons.delete_forever_outlined, color: AppColors.crimson),
            title: const Text('Supprimer mon compte', style: TextStyle(color: AppColors.crimson)), onTap: _supprimer),
        const SizedBox(height: 16),
        Text('Confidentialité : vos données sont traitées conformément à la loi n° 2008-12. Votre position n’est transmise qu’à l’envoi d’un SOS ou d’un signalement. ${config.avertissement}',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ]),
    );
  }
}

/// Le superadministrateur travaille sur le web (tableaux, exports, configuration).
class SupervisionWebScreen extends StatelessWidget {
  const SupervisionWebScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final url = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '/app/supervision');
    return Scaffold(
      appBar: AppBar(title: const Text('Supervision')),
      body: EtatVide(
        icone: Icons.desktop_windows_rounded,
        titre: 'Espace supervision sur ordinateur',
        texte: 'Le centre de supervision (indicateurs, affectations, exports, configuration) est disponible dans l’application web :\n$url',
        action: Column(children: [
          FilledButton.icon(onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new), label: const Text('Ouvrir')),
          TextButton(onPressed: () => context.read<Session>().deconnexion(), child: const Text('Se déconnecter')),
        ]),
      ),
    );
  }
}
