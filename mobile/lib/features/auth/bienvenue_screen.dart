import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../state/configuration.dart';
import '../../ui/kit.dart';
import '../../ui/photo.dart';

/// Une page de présentation : photo réelle (assets/images/photos), titre et explication.
class _Etape {
  final String image;
  final Color accent;
  final String surtitre;
  final String titre;
  final String texte;
  const _Etape(this.image, this.accent, this.surtitre, this.titre, this.texte);
}

const _etapes = [
  _Etape('motards-sapeurs', AppColors.rouge, 'SOS',
      'Une urgence ? Un seul geste',
      'Votre SOS part avec votre position GPS vers le service de votre zone. Vous avez 5 secondes pour l’annuler, et sans internet il part par SMS.'),
  _Etape('rue-inondee', AppColors.orange, 'Signalement',
      'Signalez ce que vous voyez',
      'Inondation, accident, incendie… Ajoutez une photo et le lieu : le bon service est prévenu.'),
  _Etape('pompiers-bnsp', AppColors.marine500, 'Suivi',
      'Suivez chaque étape',
      'Nouveau, pris en charge, en cours, résolu : vous êtes notifié à chaque avancée de votre dossier.'),
];

/// Visuel de la page finale : un policier, une sapeuse-pompière et une secouriste réunis.
/// Image fournie par l'équipe, recadrée sur les trois agents (bandeau et slogan d'origine retirés).
const _visuelFinal = 'assets/images/accueil_agents.jpg';
const _ratioVisuel = 1280 / 878;

/// Voile sombre en haut de la photo, pour que « Passer » et l'heure restent lisibles.
const _voileHaut = DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
  begin: Alignment.topCenter, end: Alignment.bottomCenter,
  colors: [Color(0x800A1C2E), Color(0x000A1C2E)], stops: [0, 0.3],
)));

/// Accueil avant connexion : quelques pages de présentation, puis inscription ou connexion.
/// Une fois la présentation vue ou passée, l'application s'ouvre directement sur la dernière page.
class BienvenueScreen extends StatefulWidget {
  const BienvenueScreen({super.key});

  @override
  State<BienvenueScreen> createState() => _BienvenueScreenState();
}

class _BienvenueScreenState extends State<BienvenueScreen> {
  static const _cleVu = 'presentation_vue';
  final _pages = PageController();
  int _page = 0;
  bool _pret = false;

  bool get _derniere => _page == _etapes.length;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      if (p.getBool(_cleVu) == true) _page = _etapes.length;
      setState(() => _pret = true);
      if (_page > 0) WidgetsBinding.instance.addPostFrameCallback((_) => _pages.jumpToPage(_page));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Photos décodées d'avance pour un défilement fluide.
    for (final nom in _etapes.map((e) => e.image)) {
      precacheImage(AssetImage('assets/images/photos/$nom.jpg'), context, onError: (_, __) {});
    }
    precacheImage(const AssetImage(_visuelFinal), context, onError: (_, __) {});
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _aller(int page) => _pages.animateToPage(page, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);

  void _changement(int page) {
    setState(() => _page = page);
    if (page == _etapes.length) SharedPreferences.getInstance().then((p) => p.setBool(_cleVu, true));
  }

  @override
  Widget build(BuildContext context) {
    if (!_pret) return const Scaffold(backgroundColor: AppColors.marine950);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(children: [
        PageView(
          controller: _pages,
          onPageChanged: _changement,
          children: [
            for (final e in _etapes) _PageEtape(e),
            const _PageFinale(),
          ],
        ),
        // « Passer » en haut, points et « Suivant » en bas : masqués sur la page finale.
        SafeArea(child: Align(alignment: Alignment.topRight, child: AnimatedOpacity(
          opacity: _derniere ? 0 : 1, duration: const Duration(milliseconds: 200),
          child: IgnorePointer(ignoring: _derniere, child: Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white.withOpacity(0.14)),
              onPressed: () => _aller(_etapes.length), child: const Text('Passer'),
            ),
          )),
        ))),
        Align(alignment: Alignment.bottomCenter, child: SafeArea(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _derniere ? const SizedBox.shrink() : Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(children: [
              _Points(nombre: _etapes.length + 1, actif: _page),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.marine800, foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52), padding: const EdgeInsets.symmetric(horizontal: 22)),
                onPressed: () => _aller(_page + 1),
                icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                label: Text(_page == _etapes.length - 1 ? 'Commencer' : 'Suivant'),
              ),
            ]),
          ),
        ))),
      ]),
    );
  }
}

/// Indicateur de progression : le point actif s'allonge.
class _Points extends StatelessWidget {
  final int nombre;
  final int actif;
  const _Points({required this.nombre, required this.actif});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < nombre; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(right: 6),
            width: i == actif ? 24 : 8, height: 8,
            decoration: BoxDecoration(
              color: i == actif ? AppColors.marine800 : AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ]);
}

class _PageEtape extends StatelessWidget {
  final _Etape etape;
  const _PageEtape(this.etape);

  @override
  Widget build(BuildContext context) {
    final texte = Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 96),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(etape.surtitre.toUpperCase(), style: TextStyle(color: etape.accent, fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        Text(etape.titre, style: titre(28)),
        const SizedBox(height: 12),
        Text(etape.texte, style: TextStyle(color: AppColors.textGrey, fontSize: 15.5, height: 1.45)),
      ]),
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxHeight < 620) return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.only(top: 56), child: texte));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
          child: PhotoIllustration(etape.image, superposition: _voileHaut),
        )),
        const SizedBox(height: 28),
        texte,
      ]);
    });
  }
}

/// Dernière page : le visuel des trois services se fond dans le marine, la promesse de l'application,
/// puis inscription ou connexion dans un volet clair.
class _PageFinale extends StatelessWidget {
  const _PageFinale();

  @override
  Widget build(BuildContext context) {
    final numeros = context.watch<Configuration>().numeros;

    final marque = Row(children: [
      Container(
        width: 30, height: 30, padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: AppColors.marine800, borderRadius: BorderRadius.circular(9)),
        child: Image.asset('assets/images/senalert_icone.png', errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 18, color: Colors.white)),
      ),
      const SizedBox(width: 8),
      Text('SenAlert', style: titre(15)),
      Text('  ·  Urgences au Sénégal', style: TextStyle(color: AppColors.textGrey, fontSize: 12.5)),
    ]);

    // Hero : les trois agents bord à bord en haut de l'écran, en entier (pose et tenue),
    // avec le nom de chaque service en dessous.
    final hero = Column(children: [
      ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: AspectRatio(
          aspectRatio: _ratioVisuel,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(_visuelFinal, fit: BoxFit.cover, excludeFromSemantics: true,
                errorBuilder: (_, __, ___) => ColoredBox(color: AppColors.surfaceSubtle)),
            // Voile léger en haut pour que l'heure et la batterie restent lisibles.
            const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0x00000000)], stops: [0, 0.2],
            ))),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          for (final service in const ['Police', 'Sapeurs-pompiers', 'Secours médical'])
            Expanded(child: Text(service, textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      ),
    ]);

    final promesse = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text('Ensemble, protégeons des vies', style: titre(28).copyWith(height: 1.15, letterSpacing: -0.4)),
      const SizedBox(height: 10),
      Text('Un SOS ou un signalement part vers le service de votre zone, et vous suivez chaque étape.',
          style: TextStyle(color: AppColors.textGrey, fontSize: 15, height: 1.5)),
    ]);

    final actions = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.marine800, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(56)),
        onPressed: () => context.push('/inscription'), child: const Text('Créer mon compte'),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: () => context.push('/connexion'), child: const Text('J’ai déjà un compte'),
      ),
      const SizedBox(height: 14),
      if (numeros.isNotEmpty) Center(child: NumerosUrgence(numeros)),
      Center(child: TextButton(onPressed: () => context.push('/secours'), child: const Text('Premiers secours, sans compte'))),
    ]);

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(top: false, child: LayoutBuilder(builder: (context, c) {
        // Sur un écran bas (paysage), le visuel cède la place au texte et aux boutons.
        final avecVisuel = c.maxHeight >= 620;
        // Le contenu remplit la hauteur et ne défile que si l'écran est trop court.
        return CustomScrollView(slivers: [SliverFillRemaining(hasScrollBody: false, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (avecVisuel) hero else SizedBox(height: MediaQuery.paddingOf(context).top),
            const Spacer(),
            Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 14), child: marque),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: promesse),
            const Spacer(),
            Padding(padding: const EdgeInsets.fromLTRB(24, 20, 24, 8), child: actions),
          ],
        ))]);
      })),
    );
  }
}
