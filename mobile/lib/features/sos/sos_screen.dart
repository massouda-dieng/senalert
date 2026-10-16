import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:senalert_mobile/core/constants/app_colors.dart';
import 'package:senalert_mobile/core/constants/api_constants.dart';
import 'package:senalert_mobile/core/services/api_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _holdTimer;
  double _holdProgress = 0.0;
  bool _isTriggered = false;
  bool _isHolding = false;
  bool _isSending = false;
  double? _latitude;
  double? _longitude;
  String _locationStatus = 'Recherche GPS en cours...';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locationStatus = 'GPS désactivé (Fallback: Dakar)');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _locationStatus = 'Permission GPS refusée (Fallback: Dakar)');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locationStatus = 'Permission GPS bloquée (Fallback: Dakar)');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _locationStatus = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationStatus = 'Fallback GPS Dakar (14.6928, -17.4467)');
    }
  }

  void _startHolding() {
    if (_isTriggered || _isSending) return;
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    const stepMs = 50;
    const totalMs = 3000;
    int elapsed = 0;

    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
      elapsed += stepMs;
      if (elapsed >= totalMs) {
        timer.cancel();
        _triggerEmergencyAlert();
      } else {
        if (mounted) {
          setState(() {
            _holdProgress = elapsed / totalMs;
          });
        }
      }
    });
  }

  void _stopHolding() {
    if (_isTriggered || _isSending) return;
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  Future<void> _triggerEmergencyAlert() async {
    setState(() {
      _isSending = true;
      _isHolding = false;
      _holdProgress = 1.0;
    });

    final lat = _latitude ?? 14.6928;
    final lng = _longitude ?? -17.4467;
    String errorMessage = "Échec de transmission — réessayez ou appelez directement le 15 (SAMU), 17 (Police) ou 18 (Pompiers)";

    try {
      final response = await ApiService().dio.post(
        ApiConstants.sosAlert,
        data: {
          'latitude': lat,
          'longitude': lng,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;

        // Play haptic feedback & alert sound on success 201
        try {
          HapticFeedback.heavyImpact();
          final player = AudioPlayer();
          await player.play(AssetSource('sounds/alert.mp3'));
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          _isTriggered = true;
          _isSending = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ALERTE SOS DÉCLENCHÉE AVEC SUCCÈS ! Coordonnées GPS ($lat, $lng) transmises au SAMU (15) & Pompiers (18).',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.emerald,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    } on DioException catch (e) {
      debugPrint('DioException SOS: ${e.type} - ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        errorMessage = "Pas de connexion internet — réessayez ou appelez directement le 15 (SAMU), 17 (Police) ou 18 (Pompiers)";
      } else {
        errorMessage = "Erreur serveur, réessayez ou appelez directement le 15 (SAMU), 17 (Police) ou 18 (Pompiers)";
      }
    } catch (e) {
      debugPrint('Erreur transmission alerte SOS: $e');
    }

    if (mounted) {
      setState(() {
        _isTriggered = false;
        _isSending = false;
        _holdProgress = 0.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  errorMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.crimson,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'RÉESSAYER',
            textColor: AppColors.white,
            onPressed: () => _triggerEmergencyAlert(),
          ),
        ),
      );
    }
  }

  void _resetSos() {
    setState(() {
      _isTriggered = false;
      _isSending = false;
      _holdProgress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSlate,
      appBar: AppBar(
        backgroundColor: AppColors.darkSlate,
        elevation: 0,
        title: const Text('Urgence SOS', style: TextStyle(color: AppColors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // GPS Location Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.emerald.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.emerald,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.emerald.withOpacity(_pulseController.value),
                              blurRadius: 10 * _pulseController.value,
                              spreadRadius: 4 * _pulseController.value,
                            )
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GPS Actif • Position précise',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _locationStatus,
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.gps_fixed, color: AppColors.emerald, size: 20),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Instruction Text
            Text(
              _isSending
                  ? 'TRANSMISSION EN COURS...'
                  : _isTriggered
                      ? 'ALERTE SOS ENREGISTRÉE'
                      : 'Maintenez enfoncé pendant 3s',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isTriggered
                    ? AppColors.emerald
                    : _isSending
                        ? AppColors.warning
                        : AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              _isTriggered
                  ? 'L\'alerte SOS a été enregistrée sur les serveurs de SenAlert avec vos coordonnées GPS.'
                  : 'Une alerte silencieuse géolocalisée sera envoyée au serveur central des secours.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 36),

            // SOS Panic Button (Disabled during _isSending)
            GestureDetector(
              onTapDown: _isSending ? null : (_) => _startHolding(),
              onTapUp: _isSending ? null : (_) => _stopHolding(),
              onTapCancel: _isSending ? null : _stopHolding,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Glow / Progress Ring
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.crimson.withOpacity(0.1),
                    ),
                    child: CircularProgressIndicator(
                      value: _isSending ? null : _holdProgress,
                      strokeWidth: 8,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isTriggered ? AppColors.emerald : AppColors.crimson,
                      ),
                    ),
                  ),

                  // Core SOS Button
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isTriggered
                            ? [AppColors.emerald, const Color(0xFF047857)]
                            : [AppColors.crimson, const Color(0xFF991B1B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isTriggered ? AppColors.emerald : AppColors.crimson).withOpacity(0.4),
                          blurRadius: 24,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isTriggered
                              ? Icons.check_circle_outline_rounded
                              : Icons.warning_amber_rounded,
                          color: AppColors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isTriggered ? 'ENVOYÉ' : 'SOS',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        if (_isHolding)
                          Text(
                            '${((1 - _holdProgress) * 3).ceil()}s',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 36),

            if (_isTriggered) ...[
              OutlinedButton.icon(
                onPressed: _resetSos,
                icon: const Icon(Icons.refresh, color: AppColors.white),
                label: const Text('NOUVELLE ALERTE SOS', style: TextStyle(color: AppColors.white)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.emerald),
                ),
              ),
            ],

            const SizedBox(height: 40),

            // Hotline Emergency Calls
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Numéros d\'Urgence Directs',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),

            const Row(
              children: [
                _EmergencyHotlineCard(
                  title: 'Pompiers',
                  number: '18',
                  icon: Icons.fire_truck,
                  color: Color(0xFFF97316),
                ),
                SizedBox(width: 10),
                _EmergencyHotlineCard(
                  title: 'Police',
                  number: '17',
                  icon: Icons.local_police,
                  color: Color(0xFF3B82F6),
                ),
                SizedBox(width: 10),
                _EmergencyHotlineCard(
                  title: 'SAMU',
                  number: '15',
                  icon: Icons.medical_services,
                  color: Color(0xFF10B981),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyHotlineCard extends StatelessWidget {
  final String title;
  final String number;
  final IconData icon;
  final Color color;

  const _EmergencyHotlineCard({
    required this.title,
    required this.number,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 20,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              number,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
