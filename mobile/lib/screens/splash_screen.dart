import 'package:flutter/material.dart';
import 'dart:async';
import 'home_screen.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2)); // Splash delay
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => token != null && token.isNotEmpty 
              ? const HomeScreen() 
              : const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/senalert_logo.png', // Assume you place the logo here
              height: 200,
            ),
            const SizedBox(height: 20),
            const Text(
              'SenAlert',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const Text(
              'Plateforme d\'alertes citoyennes',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.red),
          ],
        ),
      ),
    );
  }
}
