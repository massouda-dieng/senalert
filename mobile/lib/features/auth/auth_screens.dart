import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../state/configuration.dart';
import '../../state/session.dart';
import '../../ui/kit.dart';

class _Cadre extends StatelessWidget {
  final String titreEcran;
  final String? sousTitre;
  final List<Widget> enfants;
  const _Cadre({required this.titreEcran, this.sousTitre, required this.enfants});
  @override
  Widget build(BuildContext context) {
    final config = context.watch<Configuration>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Image.asset('assets/images/senalert_icone.png', width: 40, height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 40)),
                  const SizedBox(width: 10),
                  Text('SenAlert', style: titre(22)),
                ]),
                const SizedBox(height: 28),
                Text(titreEcran, style: titre(26)),
                if (sousTitre != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(sousTitre!, style: TextStyle(color: AppColors.textGrey))),
                const SizedBox(height: 24),
                ...enfants,
                const SizedBox(height: 28),
                if (config.numeros.isNotEmpty) ...[
                  Text('Urgence vitale ? Appelez directement :', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                  const SizedBox(height: 8),
                  NumerosUrgence(config.numeros),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoutonGoogle extends StatefulWidget {
  final void Function(ApiException) onErreur;
  const _BoutonGoogle({required this.onErreur});
  @override
  State<_BoutonGoogle> createState() => _BoutonGoogleState();
}

class _BoutonGoogleState extends State<_BoutonGoogle> {
  bool _envoi = false;
  @override
  Widget build(BuildContext context) {
    if (!Session.googleConfigure) {
      return Text('Connexion Google non configurée dans cette version (voir la documentation).',
          textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12.5));
    }
    return OutlinedButton.icon(
      onPressed: _envoi ? null : () async {
        setState(() => _envoi = true);
        try {
          await context.read<Session>().connexionGoogle();
        } on ApiException catch (e) {
          widget.onErreur(e);
        } finally {
          if (mounted) setState(() => _envoi = false);
        }
      },
      icon: _envoi ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.g_mobiledata_rounded, size: 30),
      label: const Text('Continuer avec Google'),
    );
  }
}

class _Separateur extends StatelessWidget {
  final String texte;
  const _Separateur(this.texte);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(children: [
          const Expanded(child: Divider()),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(texte, style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
          const Expanded(child: Divider()),
        ]),
      );
}

class ConnexionScreen extends StatefulWidget {
  const ConnexionScreen({super.key});
  @override
  State<ConnexionScreen> createState() => _ConnexionScreenState();
}

const _espaces = {
  'citoyen': ('Citoyen', Icons.person_outline, 'Signalez un incident, lancez un SOS et suivez vos dossiers.', 'E-mail ou identifiant'),
  'agent': ('Agent', Icons.badge_outlined, 'Police, pompiers, santé, SENELEC, ONAS : traitez les interventions de votre service.', 'E-mail professionnel'),
  'superadmin': ('Superviseur', Icons.admin_panel_settings_outlined, 'Supervisez les dossiers, les agents et la plateforme.', 'E-mail ou identifiant'),
};

class _ConnexionScreenState extends State<ConnexionScreen> {
  String _espace = 'citoyen';
  final _ident = TextEditingController();
  final _mdp = TextEditingController();
  bool _visible = false;
  bool _envoi = false;
  String? _erreur;

  Future<void> _valider() async {
    if (_ident.text.trim().isEmpty || _mdp.text.isEmpty) {
      setState(() => _erreur = 'Renseignez votre e-mail et votre mot de passe.');
      return;
    }
    setState(() { _envoi = true; _erreur = null; });
    try {
      await context.read<Session>().connexion(_ident.text, _mdp.text, espace: _espace);
    } on ApiException catch (e) {
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiree = context.watch<Session>().expiree;
    final e = _espaces[_espace]!;
    return _Cadre(titreEcran: 'Connexion', sousTitre: e.$3, enfants: [
      SegmentedButton<String>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact, padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6))),
        segments: [for (final x in _espaces.entries) ButtonSegment(value: x.key, label: Text(x.value.$1, maxLines: 1, softWrap: false))],
        selected: {_espace},
        onSelectionChanged: (s) => setState(() { _espace = s.first; _erreur = null; }),
      ),
      const SizedBox(height: 20),
      if (expiree) const Padding(padding: EdgeInsets.only(bottom: 16), child: Bandeau.alerte('Votre session a expiré. Reconnectez-vous.')),
      if (_espace == 'citoyen') ...[
        _BoutonGoogle(onErreur: (e) => setState(() => _erreur = e.message)),
        const _Separateur('ou'),
      ],
      TextField(controller: _ident, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next, decoration: InputDecoration(labelText: e.$4, prefixIcon: const Icon(Icons.alternate_email))),
      const SizedBox(height: 12),
      TextField(controller: _mdp, obscureText: !_visible, autofillHints: const [AutofillHints.password], onSubmitted: (_) => _valider(),
          decoration: InputDecoration(labelText: 'Mot de passe', prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(tooltip: _visible ? 'Masquer' : 'Afficher', icon: Icon(_visible ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _visible = !_visible)))),
      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.push('/mot-de-passe-oublie'), child: const Text('Mot de passe oublié ?'))),
      if (_erreur != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Bandeau.erreur(_erreur!)),
      FilledButton(onPressed: _envoi ? null : _valider,
          child: _envoi
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text('Se connecter en tant que ${e.$1.toLowerCase()}')),
      const SizedBox(height: 12),
      if (_espace == 'citoyen') TextButton(onPressed: () => context.push('/inscription'), child: const Text('Pas de compte ? Créer un compte citoyen')),
      if (_espace == 'agent') ...[
        TextButton.icon(onPressed: () => context.push('/demande-agent'), icon: const Icon(Icons.badge_outlined, size: 18), label: const Text('Pas de compte ? Demander un compte agent')),
        Text('Activé après vérification par un superviseur.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
      ],
      if (_espace == 'superadmin')
        Text('Les comptes superviseur ne se créent pas dans l’application : ils sont attribués par l’administrateur du serveur.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
    ]);
  }
}

/// Choix du type de compte à créer : citoyen (libre), agent (sur demande), superviseur (jamais dans l'application).
class _ChoixCompte extends StatelessWidget {
  final String actif;
  const _ChoixCompte(this.actif);
  static const _chemins = {'citoyen': '/inscription', 'agent': '/demande-agent', 'superadmin': '/compte-superviseur'};
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact, padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6))),
          segments: [for (final x in _espaces.entries) ButtonSegment(value: x.key, label: Text(x.value.$1, maxLines: 1, softWrap: false))],
          selected: {actif},
          onSelectionChanged: (s) => context.pushReplacement(_chemins[s.first]!),
        ),
      );
}

class CompteSuperviseurScreen extends StatelessWidget {
  const CompteSuperviseurScreen({super.key});
  @override
  Widget build(BuildContext context) => _Cadre(titreEcran: 'Compte superviseur', sousTitre: 'Accès réservé aux responsables de la plateforme.', enfants: [
        const _ChoixCompte('superadmin'),
        const Bandeau.alerte('Pour protéger les données des citoyens, un compte superviseur n’est jamais créé dans l’application : il est attribué par l’administrateur du serveur.'),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.go('/connexion'), child: const Text('J’ai déjà un compte')),
      ]);
}

class InscriptionScreen extends StatefulWidget {
  const InscriptionScreen({super.key});
  @override
  State<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends State<InscriptionScreen> {
  final _c = {for (final k in ['first_name', 'last_name', 'email', 'telephone', 'password']) k: TextEditingController()};
  String? _region;
  bool _envoi = false;
  ApiException? _erreur;

  Future<void> _valider() async {
    setState(() { _envoi = true; _erreur = null; });
    try {
      await context.read<Session>().inscription({for (final e in _c.entries) e.key: e.value.text.trim(), 'region': _region ?? ''});
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      setState(() => _erreur = e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Widget _champ(String cle, String libelle, {TextInputType? clavier, bool secret = false, String? aide}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: _c[cle], keyboardType: clavier, obscureText: secret,
            decoration: InputDecoration(labelText: libelle, helperText: aide, errorText: _erreur?.erreurChamp(cle))),
      );

  @override
  Widget build(BuildContext context) {
    final config = context.watch<Configuration>();
    return _Cadre(titreEcran: 'Créer un compte', sousTitre: 'Compte citoyen : actif tout de suite.', enfants: [
      const _ChoixCompte('citoyen'),
      _BoutonGoogle(onErreur: (e) => setState(() => _erreur = e)),
      const _Separateur('ou avec votre e-mail'),
      Row(children: [Expanded(child: _champ('first_name', 'Prénom')), const SizedBox(width: 10), Expanded(child: _champ('last_name', 'Nom'))]),
      _champ('email', 'E-mail', clavier: TextInputType.emailAddress),
      _champ('telephone', 'Téléphone (facultatif)', clavier: TextInputType.phone, aide: 'Permet aux secours de vous rappeler.'),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: _region, isExpanded: true,
          decoration: const InputDecoration(labelText: 'Région (facultatif)'),
          items: [for (final r in config.regions) DropdownMenuItem(value: r.code, child: Text(r.libelle))],
          onChanged: (v) => setState(() => _region = v),
        ),
      ),
      _champ('password', 'Mot de passe', secret: true, aide: '8 caractères minimum, pas uniquement des chiffres.'),
      Text('Vos données servent uniquement au traitement de vos signalements (loi n° 2008-12). Votre position n’est envoyée que lors d’un SOS ou d’un signalement.',
          style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
      const SizedBox(height: 14),
      if (_erreur != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Bandeau.erreur(_erreur!.message)),
      FilledButton(onPressed: _envoi ? null : _valider, child: _envoi ? const CircularProgressIndicator(color: Colors.white) : const Text('Créer mon compte')),
      TextButton(onPressed: () => context.pop(), child: const Text('J’ai déjà un compte')),
    ]);
  }
}

class MotDePasseOublieScreen extends StatefulWidget {
  const MotDePasseOublieScreen({super.key});
  @override
  State<MotDePasseOublieScreen> createState() => _MotDePasseOublieScreenState();
}

class _MotDePasseOublieScreenState extends State<MotDePasseOublieScreen> {
  final _email = TextEditingController();
  String? _ok;
  String? _erreur;
  bool _envoi = false;
  @override
  Widget build(BuildContext context) => _Cadre(titreEcran: 'Mot de passe oublié', sousTitre: 'Un lien valable une heure vous sera envoyé par e-mail.', enfants: [
        if (_ok != null) Bandeau.succes(_ok!) else ...[
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail du compte')),
          const SizedBox(height: 14),
          if (_erreur != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Bandeau.erreur(_erreur!)),
          FilledButton(
            onPressed: _envoi ? null : () async {
              setState(() { _envoi = true; _erreur = null; });
              try {
                final r = await Api.instance.post('/auth/mot-de-passe/oubli/', data: {'email': _email.text.trim()}, auth: false);
                setState(() => _ok = r['detail']);
              } on ApiException catch (e) {
                setState(() => _erreur = e.message);
              } finally {
                if (mounted) setState(() => _envoi = false);
              }
            },
            child: const Text('Envoyer le lien'),
          ),
        ],
        TextButton(onPressed: () => context.pop(), child: const Text('Retour')),
      ]);
}

/// Demande d'accès agent : le compte n'existe qu'après validation par un superadministrateur.
class DemandeAgentScreen extends StatefulWidget {
  const DemandeAgentScreen({super.key});
  @override
  State<DemandeAgentScreen> createState() => _DemandeAgentScreenState();
}

class _DemandeAgentScreenState extends State<DemandeAgentScreen> {
  final _c = {for (final k in ['prenom', 'nom', 'email', 'telephone', 'matricule', 'structure', 'fonction', 'message', 'mot_de_passe']) k: TextEditingController()};
  int? _service;
  final Set<String> _zones = {};
  bool _envoi = false;
  ApiException? _erreur;
  String? _ok;

  Future<void> _valider() async {
    setState(() { _envoi = true; _erreur = null; });
    try {
      final r = await Api.instance.post('/auth/demandes-agent/', auth: false, data: {
        for (final e in _c.entries) e.key: e.key == 'mot_de_passe' ? e.value.text : e.value.text.trim(),
        'service': _service,
        'zones': _zones.toList(),
      });
      setState(() => _ok = r['detail']);
    } on ApiException catch (e) {
      setState(() => _erreur = e);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  Widget _champ(String cle, String libelle, {TextInputType? clavier, bool secret = false, String? aide, int lignes = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: _c[cle], keyboardType: clavier, obscureText: secret, maxLines: lignes,
            decoration: InputDecoration(labelText: libelle, helperText: aide, helperMaxLines: 2, errorText: _erreur?.erreurChamp(cle))),
      );

  @override
  Widget build(BuildContext context) {
    final config = context.watch<Configuration>();
    if (_ok != null) {
      return _Cadre(titreEcran: 'Demande envoyée', enfants: [
        Bandeau.succes(_ok!),
        const SizedBox(height: 12),
        Text('Un superviseur vérifie votre service, votre matricule et votre structure. Tant que la demande n’est pas validée, la connexion est impossible.',
            style: TextStyle(color: AppColors.textGrey)),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => context.go('/connexion'), child: const Text('Retour à la connexion')),
      ]);
    }
    return _Cadre(
      titreEcran: 'Demander un compte agent',
      sousTitre: 'Réservé aux agents des services de secours et d’intervention. Chaque demande est vérifiée avant activation.',
      enfants: [
        const _ChoixCompte('agent'),
        Row(children: [Expanded(child: _champ('prenom', 'Prénom')), const SizedBox(width: 10), Expanded(child: _champ('nom', 'Nom'))]),
        _champ('email', 'E-mail professionnel', clavier: TextInputType.emailAddress, aide: 'Servira d’identifiant de connexion.'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<int>(
            value: _service, isExpanded: true,
            decoration: InputDecoration(labelText: 'Service', errorText: _erreur?.erreurChamp('service')),
            items: [for (final (id, nom) in config.services) DropdownMenuItem(value: id, child: Text(nom))],
            onChanged: (v) => setState(() => _service = v),
          ),
        ),
        _champ('matricule', 'Matricule'),
        _champ('structure', 'Structure d’affectation', aide: 'Commissariat, caserne, district sanitaire, agence…'),
        Row(children: [Expanded(child: _champ('fonction', 'Fonction / grade')), const SizedBox(width: 10),
          Expanded(child: _champ('telephone', 'Téléphone', clavier: TextInputType.phone))]),
        Text('Zones d’intervention', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final r in config.regions)
            FilterChip(label: Text(r.libelle), selected: _zones.contains(r.code),
                onSelected: (v) => setState(() => v ? _zones.add(r.code) : _zones.remove(r.code))),
        ]),
        if (_erreur?.erreurChamp('zones') != null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text(_erreur!.erreurChamp('zones')!, style: const TextStyle(color: Colors.red, fontSize: 12))),
        const SizedBox(height: 14),
        _champ('message', 'Message au superviseur (facultatif)', lignes: 2),
        _champ('mot_de_passe', 'Mot de passe', secret: true, aide: 'Choisi par vous, stocké chiffré : le superviseur ne le voit jamais.'),
        if (_erreur != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Bandeau.erreur(_erreur!.message)),
        FilledButton(onPressed: _envoi ? null : _valider, child: _envoi ? const CircularProgressIndicator(color: Colors.white) : const Text('Envoyer ma demande')),
        TextButton(onPressed: () => context.pop(), child: const Text('Retour')),
      ],
    );
  }
}
