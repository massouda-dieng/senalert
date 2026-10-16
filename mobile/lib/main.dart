import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:senalert_mobile/app.dart';
import 'package:senalert_mobile/features/auth/providers/auth_provider.dart';
import 'package:senalert_mobile/features/incidents/providers/incident_provider.dart';
import 'services/auth_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<IncidentProvider>(create: (_) => IncidentProvider()),
        Provider<AuthService>(create: (_) => AuthService()),
      ],
      child: const SenAlertApp(),
    ),
  );
}
