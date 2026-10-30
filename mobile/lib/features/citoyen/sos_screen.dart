import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/constants/app_colors.dart';
import '../../core/location.dart';
import '../../core/models.dart';
import '../../state/configuration.dart';
import '../../ui/kit.dart';
import '../../state/langue.dart';

enum _Etape { decompte, envoi, succes, echec }

/// Parcours SOS : 5 s annulables, position jointe si disponible (jamais inventée),
/// résultat affiché uniquement après confirmation du serveur.
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
    if (_etape == _Etape.envoi) return;
    setState(() { _etape = _Etape.envoi; _erreur = null; });
    final corps = <String, dynamic>{'client_request_id': _cle};
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
        backgroundColor: AppColors.vert900,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: Text(tr('Alerte SOS'), style: titre(19, couleur: Colors.white))),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            if (_etape == _Etape.decompte) ...[
              const SizedBox(height: 12),
              Text(tr('Envoi automatique dans'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              Semantics(liveRegion: true, child: Text('$_reste', textAlign: TextAlign.center, style: titre(96, couleur: const Color(0xFFFB7185)))),
              _infoPosition(),
              const SizedBox(height: 32),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.crimson, minimumSize: const Size.fromHeight(60)),
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
              const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 72),
              const SizedBox(height: 12),
              Text(tr('Alerte enregistrée'), textAlign: TextAlign.center, style: titre(24, couleur: Colors.white)),
              const SizedBox(height: 6),
              SelectableText(_dossier!.reference, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              Carte(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(tr('Statut actuel'))), BadgeStatut(_dossier!.statut)]),
                const SizedBox(height: 10),
                Text(_dejaRecue ? 'Cette alerte avait déjà été reçue : voici son suivi.'
                    : tr('Votre alerte est enregistrée et transmise aux agents SenAlert de votre zone.')),
                const SizedBox(height: 8),
                Text(tr('Tant qu’un agent ne l’a pas prise en charge, aucune intervention n’est garantie.'),
                    style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              ])),
              if (_dossier!.lat == null) const Padding(padding: EdgeInsets.only(top: 12),
                  child: Bandeau.alerte('Votre position n’a pas pu être jointe. Indiquez votre lieu exact aux secours par téléphone.')),
              const SizedBox(height: 18),
              Text(tr('Danger immédiat : appelez aussi les secours.'), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              NumerosUrgence(numeros, sombre: true),
              const SizedBox(height: 18),
              FilledButton(onPressed: () => context.go('/dossier/sos/${_dossier!.id}'), child: Text(tr('Suivre le dossier'))),
            ],
            if (_etape == _Etape.echec) ...[
              const Icon(Icons.error_rounded, color: Color(0xFFFB7185), size: 72),
              const SizedBox(height: 12),
              Text(tr('L’alerte n’a PAS été transmise'), textAlign: TextAlign.center, style: titre(22, couleur: Colors.white)),
              const SizedBox(height: 8),
              Text(_erreur?.message ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              Text(tr('Appelez immédiatement les secours :'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final n in numeros) Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: AppColors.crimson, minimumSize: const Size.fromHeight(58)),
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
          textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFCD34D)));
    }
    final p = _position!.precision ?? 0;
    return Text('${tr('Position obtenue · précision ± {m} m', {'m': p.round()})}${p > 100 ? ' (approximative)' : ''}',
        textAlign: TextAlign.center, style: TextStyle(color: p > 100 ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7)));
  }
}
