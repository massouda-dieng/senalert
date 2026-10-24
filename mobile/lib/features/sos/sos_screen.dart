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
import 'package:senalert_mobile/shared/widgets/sa_ui.dart';

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
                    _latitude != null
                        ? 'ALERTE SOS DÉCLENCHÉE AVEC SUCCÈS ! Coordonnées GPS ($lat, $lng) transmises au SAMU (15) & Pompiers (18).'
                        : 'ALERTE SOS ENVOYÉE — GPS indisponible : position approximative (Dakar). Appelez aussi le 15 / 17 / 18.',
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
    final color = _isTriggered ? AppColors.emerald : AppColors.crimson;
    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: SaNightBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              children: [
                Row(children: [
                  SaIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Retour',
                    onTap: () => context.go('/home'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Urgence SOS', style: SaText.display(19, color: Colors.white))),
                ]),
                const SizedBox(height: 16),

                // Carte GPS (verre)
                SaGlass(
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
                              color: const Color(0xFF34D399),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF34D399).withOpacity(_pulseController.value),
                                  blurRadius: 10 * _pulseController.value,
                                  spreadRadius: 4 * _pulseController.value,
                                )
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_latitude != null ? 'GPS actif · position précise' : 'Localisation GPS',
                                style: SaText.body(13.5, color: Colors.white, weight: FontWeight.w700)),
                            Text(_locationStatus, style: SaText.body(12, color: Colors.white.withOpacity(0.7))),
                          ],
                        ),
                      ),
                      const Icon(Icons.gps_fixed_rounded, color: Color(0xFF34D399), size: 22),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _isSending
                        ? 'Transmission en cours…'
                        : _isTriggered
                            ? 'Alerte SOS enregistrée'
                            : 'Maintenez enfoncé pendant 3 s',
                    key: ValueKey('$_isSending$_isTriggered'),
                    textAlign: TextAlign.center,
                    style: SaText.display(21,
                        color: _isTriggered
                            ? const Color(0xFF34D399)
                            : _isSending
                                ? const Color(0xFFFDBA74)
                                : Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isTriggered
                      ? 'L\'alerte SOS a été enregistrée sur les serveurs de SenAlert avec vos coordonnées GPS.'
                      : 'Une alerte silencieuse géolocalisée sera envoyée au serveur central des secours.',
                  textAlign: TextAlign.center,
                  style: SaText.body(13.5, color: Colors.white.withOpacity(0.72)),
                ),

                const SizedBox(height: 26),

                // Bouton SOS lumineux
                Semantics(
                  button: true,
                  label: 'Bouton SOS, maintenir 3 secondes',
                  child: GestureDetector(
                    onTapDown: _isSending ? null : (_) => _startHolding(),
                    onTapUp: _isSending ? null : (_) => _stopHolding(),
                    onTapCancel: _isSending ? null : _stopHolding,
                    child: AnimatedScale(
                      scale: _isHolding ? 0.96 : 1,
                      duration: const Duration(milliseconds: 150),
                      child: SaPulse(
                        size: 290,
                        color: color,
                        active: !_isSending,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 228,
                              height: 228,
                              child: CircularProgressIndicator(
                                value: _isSending ? null : _holdProgress,
                                strokeWidth: 7,
                                strokeCap: StrokeCap.round,
                                backgroundColor: Colors.white.withOpacity(0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _isTriggered ? const Color(0xFF34D399) : Colors.white,
                                ),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 192,
                              height: 192,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: _isTriggered
                                    ? const LinearGradient(
                                        colors: [Color(0xFF10B981), Color(0xFF047857)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                    : AppColors.sosGradient,
                                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                                boxShadow: [
                                  BoxShadow(color: color.withOpacity(0.6), blurRadius: 40, spreadRadius: 6),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isTriggered ? Icons.check_circle_outline_rounded : Icons.sos_rounded,
                                    color: AppColors.white,
                                    size: 46,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isTriggered ? 'ENVOYÉ' : 'SOS',
                                    style: SaText.display(34, color: Colors.white, weight: FontWeight.w900),
                                  ),
                                  if (_isHolding)
                                    Text(
                                      '${((1 - _holdProgress) * 3).ceil()} s',
                                      style: SaText.body(16, color: Colors.white, weight: FontWeight.w800),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (_isTriggered)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _resetSos,
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
                      label: const Text('Nouvelle alerte SOS', style: TextStyle(color: AppColors.white)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.4)),
                      ),
                    ),
                  ),

                const SizedBox(height: 28),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Numéros d\'urgence directs', style: SaText.display(16, color: Colors.white)),
                ),
                const SizedBox(height: 12),

                const Row(
                  children: [
                    _EmergencyHotlineCard(
                      title: 'Pompiers',
                      number: '18',
                      icon: Icons.fire_truck_rounded,
                      color: Color(0xFFFB923C),
                    ),
                    SizedBox(width: 10),
                    _EmergencyHotlineCard(
                      title: 'Police',
                      number: '17',
                      icon: Icons.local_police_rounded,
                      color: Color(0xFF60A5FA),
                    ),
                    SizedBox(width: 10),
                    _EmergencyHotlineCard(
                      title: 'SAMU',
                      number: '15',
                      icon: Icons.medical_services_rounded,
                      color: Color(0xFF34D399),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
      child: SaGlass(
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(title, style: SaText.body(12, color: Colors.white, weight: FontWeight.w600)),
            Text(number, style: SaText.display(22, color: color)),
          ],
        ),
      ),
    );
  }
}
