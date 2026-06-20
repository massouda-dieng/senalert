import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:senalert_mobile/core/services/api_service.dart';
import 'package:senalert_mobile/core/constants/api_constants.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isLoading = false;
  String? _error;
  bool _isAuthenticated = false;

  bool get isLoading       => _isLoading;
  String? get error        => _error;
  bool get isAuthenticated => _isAuthenticated;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );
      final token = res.data['token'] ?? res.data['access'] ?? res.data['key'];
      if (token != null) {
        await _api.saveToken(token.toString());
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = 'Identifiants incorrects';
    } catch (_) {
      _error = 'Erreur de connexion. Vérifiez vos identifiants.';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register(String name, String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.dio.post(
        ApiConstants.register,
        data: {'name': name, 'email': email, 'password': password},
      );
      final token = res.data['token'] ?? res.data['access'] ?? res.data['key'];
      if (token != null) {
        await _api.saveToken(token.toString());
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _error = 'Erreur lors de l\'inscription';
    } catch (_) {
      _error = 'Erreur. Veuillez réessayer.';
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _api.deleteToken();
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final token = await _storage.read(key: 'auth_token');
    _isAuthenticated = token != null;
    notifyListeners();
  }
}
