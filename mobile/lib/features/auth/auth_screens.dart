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
                  Image.asset('assets/images/senalert_logo.png', width: 40, height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 40)),
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

class _ConnexionScreenState extends State<ConnexionScreen> {
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
      await context.read<Session>().connexion(_ident.text, _mdp.text);
    } on ApiException catch (e) {
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expiree = context.watch<Session>().expiree;
    return _Cadre(titreEcran: 'Connexion', sousTitre: 'Citoyens et agents de secours.', enfants: [
      if (expiree) const Padding(padding: EdgeInsets.only(bottom: 16), child: Bandeau.alerte('Votre session a expiré. Reconnectez-vous.')),
      _BoutonGoogle(onErreur: (e) => setState(() => _erreur = e.message)),
      const _Separateur('ou'),
      TextField(controller: _ident, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'E-mail ou identifiant', prefixIcon: Icon(Icons.alternate_email))),
      const SizedBox(height: 12),
      TextField(controller: _mdp, obscureText: !_visible, autofillHints: const [AutofillHints.password], onSubmitted: (_) => _valider(),
          decoration: InputDecoration(labelText: 'Mot de passe', prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(tooltip: _visible ? 'Masquer' : 'Afficher', icon: Icon(_visible ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _visible = !_visible)))),
      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.push('/mot-de-passe-oublie'), child: const Text('Mot de passe oublié ?'))),
      if (_erreur != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Bandeau.erreur(_erreur!)),
      FilledButton(onPressed: _envoi ? null : _valider,
          child: _envoi ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Text('Se connecter')),
      const SizedBox(height: 12),
      TextButton(onPressed: () => context.push('/inscription'), child: const Text('Pas de compte ? Créer un compte citoyen')),
    ]);
  }
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
    return _Cadre(titreEcran: 'Créer un compte', sousTitre: 'Compte citoyen. Les comptes agents sont créés par un responsable habilité.', enfants: [
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
