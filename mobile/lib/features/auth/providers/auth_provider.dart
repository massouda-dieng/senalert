import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:senalert_mobile/core/services/api_service.dart';
import 'package:senalert_mobile/core/constants/api_constants.dart';
import 'package:senalert_mobile/core/services/push_service.dart';

/// Gère l'authentification réelle auprès du backend Django (JWT).
/// Rôles backend : 'citoyen', 'autorite' (agent de secours), 'admin'.
class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  String _userName = '';
  String _userEmail = '';
  String _userRole = 'citoyen';

  bool get isLoading       => _isLoading;
  String? get error        => _error;
  bool get isAuthenticated => _isAuthenticated;
  String get userName      => _userName;
  String get userEmail     => _userEmail;
  String get userRole      => _userRole;
  bool get isAgent         => _userRole == 'autorite' || _userRole == 'admin';
  String get roleLabel     => isAgent ? 'Agent de secours' : 'Citoyen';

  /// Convertit le choix du formulaire en rôle backend.
  static String roleToApi(String formRole) =>
      formRole.toLowerCase().startsWith('citoyen') ? 'citoyen' : 'autorite';

  String _messageFor(Object e, {required String fallback}) {
    if (e is DioException) {
      if (e.response == null) {
        return 'Serveur injoignable. Vérifiez que le backend est lancé.';
      }
      final code = e.response!.statusCode;
      final data = e.response!.data;
      if (code == 401) return 'Email ou mot de passe incorrect.';
      if (data is Map && data.isNotEmpty) {
        final first = data.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
    }
    return fallback;
  }

  /// Récupère le profil (nom, email, rôle) avec le token courant.
  Future<bool> _loadProfile() async {
    try {
      final res = await _api.dio.get(ApiConstants.profile);
      _userName = (res.data['username'] ?? '').toString();
      _userEmail = (res.data['email'] ?? _userName).toString();
      _userRole = (res.data['role'] ?? 'citoyen').toString();
      await _storage.write(key: 'user_role', value: _userRole);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();
    try {
      final res = await _api.dio.post(
        ApiConstants.login,
        data: {'username': cleanEmail, 'password': password},
      );
      final token = res.data['access'];
      if (token == null) throw Exception('Token manquant');
      await _api.saveToken(token.toString());
      if (res.data['refresh'] != null) {
        await _storage.write(key: 'refresh_token', value: res.data['refresh'].toString());
      }
      if (!await _loadProfile()) {
        throw Exception('Profil indisponible');
      }
      _isAuthenticated = true;
      PushService().registerDeviceToken();
      return true;
    } catch (e) {
      await _api.deleteToken();
      _isAuthenticated = false;
      _error = _messageFor(e, fallback: 'Connexion impossible.');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String name, String email, String password,
      {String role = 'Citoyen'}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final cleanEmail = email.trim().toLowerCase();
    try {
      await _api.dio.post(
        ApiConstants.register,
        data: {
          'username': cleanEmail,
          'email': cleanEmail,
          'password': password,
          'role': roleToApi(role),
        },
      );
      return true;
    } catch (e) {
      _error = _messageFor(e, fallback: 'Erreur lors de l\'inscription.');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.deleteToken();
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'user_role');
    _isAuthenticated = false;
    _userName = '';
    _userEmail = '';
    _userRole = 'citoyen';
    notifyListeners();
  }

  /// Vérifie au démarrage si le token enregistré est encore valide.
  Future<void> checkAuth() async {
    final token = await _api.getToken();
    _isAuthenticated = token != null && await _loadProfile();
    if (!_isAuthenticated) await _api.deleteToken();
    notifyListeners();
  }
}
