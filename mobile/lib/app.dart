import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/features/splash/splash_screen.dart';
import 'package:senalert_mobile/features/onboarding/onboarding_screen.dart';
import 'package:senalert_mobile/features/auth/screens/login_screen.dart';
import 'package:senalert_mobile/features/auth/screens/register_screen.dart';
import 'package:senalert_mobile/features/home/screens/home_screen.dart';
import 'package:senalert_mobile/features/incidents/screens/incident_list_screen.dart';
import 'package:senalert_mobile/features/incidents/screens/incident_detail_screen.dart';
import 'package:senalert_mobile/features/report/screens/report_screen.dart';
import 'package:senalert_mobile/features/profile/profile_screen.dart';
import 'package:senalert_mobile/features/sos/sos_screen.dart';
import 'package:senalert_mobile/features/first_aid/first_aid_screen.dart';
import 'package:senalert_mobile/features/agent/screens/agent_dashboard_screen.dart';
import 'package:senalert_mobile/features/incidents/screens/incidents_map_screen.dart';
import 'package:senalert_mobile/features/services/proximity_services_screen.dart';

// Écrans accessibles sans compte (cf. diagramme de cas d'utilisation Citoyen).
const _publicRoutes = {'/', '/onboarding', '/login', '/register', '/first-aid', '/services'};

final GoRouter _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final auth = context.read<AuthProvider>();
    final loc = state.matchedLocation;
    if (_publicRoutes.contains(loc)) return null;
    // SOS, signalement, incidents, profil… : authentification obligatoire.
    if (!auth.isAuthenticated) return '/login';
    if (loc == '/agent-dashboard' && !auth.isAgent) return '/home';
    if (loc == '/home' && auth.isAgent) return '/agent-dashboard';
    return null;
  },
  routes: [
    GoRoute(path: '/',                builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding',      builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/login',           builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register',        builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/home',            builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/incidents',       builder: (_, __) => const IncidentListScreen()),
    GoRoute(path: '/map',             builder: (_, __) => const IncidentsMapScreen()),
    GoRoute(path: '/services',        builder: (_, __) => const ProximityServicesScreen()),
    GoRoute(path: '/report',          builder: (_, __) => const ReportScreen()),
    GoRoute(path: '/profile',         builder: (_, __) => const ProfileScreen()),
    GoRoute(path: '/sos',             builder: (_, __) => const SosScreen()),
    GoRoute(path: '/first-aid',       builder: (_, __) => const FirstAidScreen()),
    GoRoute(path: '/agent-dashboard', builder: (_, __) => const AgentDashboardScreen()),
    GoRoute(
      path: '/incidents/:id',
      builder: (_, state) => IncidentDetailScreen(
        incidentId: state.pathParameters['id']!,
      ),
    ),
  ],
);

class SenAlertApp extends StatelessWidget {
  const SenAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SenAlert',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.navy800,
          primary: AppColors.navy800,
          secondary: AppColors.orange,
          error: AppColors.crimson,
          surface: AppColors.white,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.interTextTheme(
          ThemeData.light().textTheme,
        ).apply(bodyColor: AppColors.textDark, displayColor: AppColors.textDark),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: ZoomPageTransitionsBuilder(),
            TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          },
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.navy900,
          foregroundColor: AppColors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.navy800,
            foregroundColor: AppColors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.navy800,
            minimumSize: const Size(double.infinity, 54),
            side: const BorderSide(color: AppColors.border, width: 1.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.navy900,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentTextStyle: GoogleFonts.inter(
            color: AppColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: AppColors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.white : null,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.emerald : null,
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.navy800 : null,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.blue600, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
          ),
        ),
      ),
    );
  }
}
