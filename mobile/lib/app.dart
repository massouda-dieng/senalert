import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'features/agent/agent_home_screen.dart';
import 'features/auth/auth_screens.dart';
import 'features/auth/bienvenue_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/citoyen/assistant_screen.dart';
import 'features/citoyen/carte_screen.dart';
import 'features/citoyen/home_screen.dart';
import 'features/citoyen/report_screen.dart';
import 'features/citoyen/services_screen.dart';
import 'features/citoyen/sos_screen.dart';
import 'features/commun/commun_screens.dart';
import 'features/communaute/communaute_screen.dart';
import 'features/dossiers/dossiers.dart';
import 'features/secours/premiers_secours_screen.dart';
import 'state/apparence.dart';
import 'state/session.dart';
import 'ui/kit.dart';
import 'state/langue.dart';

const _publiques = {'/bienvenue', '/connexion', '/inscription', '/demande-agent', '/compte-superviseur', '/mot-de-passe-oublie', '/secours', '/onboarding'};
const _citoyen = {'/accueil', '/signaler', '/sos', '/services', '/assistant', '/carte', '/dossiers', '/communaute'};
const _agent = {'/agent', '/interventions', '/carte-agent'};

String accueilPour(String role) => switch (role) { 'agent' => '/agent', 'superadmin' => '/supervision', _ => '/accueil' };

GoRouter creerRouteur(Session session) => GoRouter(
      initialLocation: '/',
      refreshListenable: session,
      redirect: (context, state) {
        final lieu = state.matchedLocation;
        if (!session.initialisee) return lieu == '/' ? null : '/';
        final u = session.utilisateur;
        if (u == null) return _publiques.contains(lieu) ? null : '/bienvenue';
        if (lieu == '/' || const {'/bienvenue', '/connexion', '/inscription', '/demande-agent', '/compte-superviseur', '/mot-de-passe-oublie'}.contains(lieu)) return accueilPour(u.role);
        if (_citoyen.contains(lieu) && !u.estCitoyen) return accueilPour(u.role);
        if (_agent.contains(lieu) && !u.estAgent) return accueilPour(u.role);
        if (lieu == '/supervision' && !u.estSuperadmin) return accueilPour(u.role);
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (_, __) => const _Demarrage()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/bienvenue', builder: (_, __) => const BienvenueScreen()),
        GoRoute(path: '/connexion', builder: (_, __) => const ConnexionScreen()),
        GoRoute(path: '/inscription', builder: (_, __) => const InscriptionScreen()),
        GoRoute(path: '/demande-agent', builder: (_, __) => const DemandeAgentScreen()),
        GoRoute(path: '/compte-superviseur', builder: (_, __) => const CompteSuperviseurScreen()),
        GoRoute(path: '/mot-de-passe-oublie', builder: (_, __) => const MotDePasseOublieScreen()),
        GoRoute(path: '/sos', builder: (_, __) => const SosScreen()),
        GoRoute(path: '/signaler', builder: (_, __) => const SignalerScreen()),
        GoRoute(path: '/services', builder: (_, __) => const ServicesScreen()),
        GoRoute(path: '/assistant', builder: (_, __) => const AssistantScreen()),
        GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
        GoRoute(path: '/supervision', builder: (_, __) => const SupervisionWebScreen()),
        GoRoute(path: '/dossier/:type/:id', builder: (_, s) => DossierScreen(sos: s.pathParameters['type'] == 'sos', id: int.parse(s.pathParameters['id']!))),
        ShellRoute(
          builder: (_, state, enfant) => _Coquille(lieu: state.matchedLocation, child: enfant),
          routes: [
            GoRoute(path: '/accueil', builder: (_, __) => const AccueilCitoyen()),
            GoRoute(path: '/dossiers', builder: (_, __) => const ListeDossiersScreen()),
            GoRoute(path: '/carte', builder: (_, __) => const CarteScreen()),
            GoRoute(path: '/secours', builder: (_, __) => const PremiersSecoursScreen()),
            GoRoute(path: '/communaute', builder: (_, __) => const CommunauteScreen()),
            GoRoute(path: '/profil', builder: (_, __) => const ProfilScreen()),
            GoRoute(path: '/agent', builder: (_, __) => const AccueilAgent()),
            GoRoute(path: '/interventions', builder: (_, __) => const ListeDossiersScreen(agent: true)),
            GoRoute(path: '/carte-agent', builder: (_, __) => const CarteScreen(agent: true)),
          ],
        ),
      ],
    );

class _Coquille extends StatelessWidget {
  final String lieu;
  final Widget child;
  const _Coquille({required this.lieu, required this.child});

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Session>().utilisateur;
    if (u == null) return child; // fiches de premiers secours consultables sans compte
    Langue.instance.role = u.role;
    final onglets = u.estAgent
        ? const [('/agent', Icons.space_dashboard_outlined, 'Tableau'), ('/interventions', Icons.assignment_outlined, 'Interventions'),
            ('/carte-agent', Icons.map_outlined, 'Carte'), ('/secours', Icons.healing_outlined, 'Secours'), ('/profil', Icons.person_outline, 'Profil')]
        : [('/accueil', Icons.home_outlined, tr('Accueil')), ('/dossiers', Icons.folder_open_outlined, tr('Dossiers')),
            ('/communaute', Icons.groups_outlined, tr('Autour')), ('/carte', Icons.map_outlined, tr('Carte')), ('/profil', Icons.person_outline, tr('Profil'))];
    final index = onglets.indexWhere((o) => o.$1 == lieu);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(onglets[i].$1),
        destinations: [for (final o in onglets) NavigationDestination(icon: Icon(o.$2), label: o.$3)],
      ),
    );
  }
}

/// Écran de démarrage : logo et slogan apparaissent en douceur pendant l'ouverture de la session.
/// À la première ouverture, redirige vers l'onboarding.
class _Demarrage extends StatefulWidget {
  const _Demarrage();
  @override
  State<_Demarrage> createState() => _DemarrageState();
}

class _DemarrageState extends State<_Demarrage> {
  @override
  void initState() {
    super.initState();
    _rediriger();
  }

  Future<void> _rediriger() async {
    // Attend que la session soit initialisée
    final session = context.read<Session>();
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 80));
      return !session.initialisee;
    });
    if (!mounted) return;
    // Si l'utilisateur est déjà connecté, va directement à son accueil
    final u = session.utilisateur;
    if (u != null) {
      context.go(accueilPour(u.role));
      return;
    }
    // Sinon, onboarding à la première ouverture
    final aVoir = await onboardingAVoir();
    if (!mounted) return;
    context.go(aVoir ? '/onboarding' : '/bienvenue');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.headerGradient),
          child: SizedBox.expand(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (_, v, enfant) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: enfant)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.asset('assets/images/senalert_icone.png', width: 104, height: 104,
                      errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 104, color: Colors.white)),
                ),
                const SizedBox(height: 20),
                Text('SenAlert', style: titre(34, couleur: Colors.white)),
                const SizedBox(height: 6),
                const Text('Ensemble, protégeons des vies', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 36),
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white70)),
              ]),
            ),
          ),
        ),
      );
}

class SenAlertApp extends StatefulWidget {
  final Session session;
  const SenAlertApp({super.key, required this.session});
  @override
  State<SenAlertApp> createState() => _SenAlertAppState();
}

class _SenAlertAppState extends State<SenAlertApp> {
  late final GoRouter _routeur = creerRouteur(widget.session);
  @override
  Widget build(BuildContext context) {
    context.watch<Apparence>();
    context.watch<Langue>();
    return MaterialApp.router(
        title: 'SenAlert',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.clair(),
        routerConfig: _routeur,
      );
  }
}
