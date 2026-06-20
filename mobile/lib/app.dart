import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/',            builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/onboarding',  builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/login',       builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register',    builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/home',        builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/incidents',   builder: (_, __) => const IncidentListScreen()),
    GoRoute(path: '/report',      builder: (_, __) => const ReportScreen()),
    GoRoute(path: '/profile',     builder: (_, __) => const ProfileScreen()),
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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.danger),
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.danger,
          foregroundColor: AppColors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDark,
            minimumSize: const Size(double.infinity, 50),
            side: const BorderSide(color: Colors.grey),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
        ),
      ),
    );
  }
}
