import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';

/// Erreur d'API présentable à l'utilisateur.
class ApiException implements Exception {
  final int status;
  final String message;
  final String? code;
  final Map<String, dynamic>? champs;
  const ApiException(this.status, this.message, {this.code, this.champs});

  bool get estReseau => status == 0;
  bool get estConflit => status == 409;

  String? erreurChamp(String nom) {
    final v = champs?[nom];
    if (v is List && v.isNotEmpty) return v.first.toString();
    return v?.toString();
  }

  @override
  String toString() => message;
}

const _uuid = Uuid();
String nouvelleCle() => _uuid.v4();

/// Client HTTP unique de l'application.
///  * jetons stockés dans le trousseau sécurisé (Keychain / Keystore) ;
///  * jeton d'accès renouvelé automatiquement (une seule fois, en file) ;
///  * expiration définitive signalée via [sessionExpiree] ;
///  * aucune journalisation des en-têtes ni des corps (pas de fuite de jetons).
class Api {
  Api._() {
    dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ));
    dio.interceptors.add(QueuedInterceptorsWrapper(onRequest: _ajouterJeton, onError: _surErreur));
  }
  static final Api instance = Api._();

  late final Dio dio;
  final _stockage = const FlutterSecureStorage();
  final _expiration = StreamController<void>.broadcast();
  String? _access;

  Stream<void> get sessionExpiree => _expiration.stream;

  Future<void> enregistrerJetons(String access, String? refresh) async {
    _access = access;
    await _stockage.write(key: 'access', value: access);
    if (refresh != null) await _stockage.write(key: 'refresh', value: refresh);
  }

  Future<void> effacerJetons() async {
    _access = null;
    await _stockage.delete(key: 'access');
    await _stockage.delete(key: 'refresh');
  }

  Future<String?> refreshActuel() => _stockage.read(key: 'refresh');
  Future<bool> aUneSession() async => (await _stockage.read(key: 'refresh')) != null;

  Future<void> _ajouterJeton(RequestOptions o, RequestInterceptorHandler h) async {
    if (o.extra['auth'] != false) {
      _access ??= await _stockage.read(key: 'access');
      if (_access != null) o.headers['Authorization'] = 'Bearer $_access';
    }
    h.next(o);
  }

  Future<void> _surErreur(DioException e, ErrorInterceptorHandler h) async {
    final o = e.requestOptions;
    if (e.response?.statusCode == 401 && o.extra['auth'] != false && o.extra['rejoue'] != true) {
      if (await _rafraichir()) {
        o.extra['rejoue'] = true;
        o.headers['Authorization'] = 'Bearer $_access';
        try {
          // Instance distincte : une erreur du rejeu ne doit pas attendre dans cette file.
          return h.resolve(await Dio(dio.options).fetch(o));
        } on DioException catch (e2) {
          return h.next(e2);
        }
      }
      await effacerJetons();
      _expiration.add(null);
    }
    h.next(e);
  }

  Future<bool> _rafraichir() async {
    final refresh = await _stockage.read(key: 'refresh');
    if (refresh == null) return false;
    try {
      final r = await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl, connectTimeout: const Duration(seconds: 10)))
          .post('/auth/jeton/rafraichir/', data: {'refresh': refresh});
      await enregistrerJetons(r.data['access'], r.data['refresh']);
      return true;
    } catch (_) {
      return false;
    }
  }

  static ApiException convertir(Object e) {
    if (e is ApiException) return e;
    if (e is DioException) {
      final r = e.response;
      if (r == null) {
        return const ApiException(0,
            'Connexion au serveur impossible. Vérifiez votre réseau puis réessayez.', code: 'reseau');
      }
      final d = r.data;
      if (d is Map) {
        return ApiException(r.statusCode ?? 0, (d['detail'] ?? 'Erreur ${r.statusCode}').toString(),
            code: d['code']?.toString(), champs: d['champs'] is Map ? Map<String, dynamic>.from(d['champs']) : null);
      }
      return ApiException(r.statusCode ?? 0,
          (r.statusCode ?? 500) >= 500 ? 'Erreur du serveur. Réessayez plus tard.' : 'Requête refusée (${r.statusCode}).');
    }
    return ApiException(0, e.toString());
  }

  Future<T> _executer<T>(Future<Response> Function() appel) async {
    try {
      return (await appel()).data as T;
    } catch (e) {
      throw convertir(e);
    }
  }

  /// GET avec une nouvelle tentative en cas de coupure réseau (lecture idempotente).
  Future<T> get<T>(String chemin, {Map<String, dynamic>? params}) async {
    for (var essai = 0;; essai++) {
      try {
        return await _executer<T>(() => dio.get(chemin, queryParameters: _nettoyer(params)));
      } on ApiException catch (e) {
        if (!e.estReseau || essai >= 1) rethrow;
        await Future.delayed(const Duration(milliseconds: 900));
      }
    }
  }

  /// POST jamais rejoué automatiquement : la reprise passe par une clé d'idempotence.
  Future<T> post<T>(String chemin, {Object? data, bool auth = true}) =>
      _executer<T>(() => dio.post(chemin, data: data, options: Options(extra: {'auth': auth})));

  Future<T> patch<T>(String chemin, {Object? data}) => _executer<T>(() => dio.patch(chemin, data: data));

  Future<T> delete<T>(String chemin, {Object? data}) => _executer<T>(() => dio.delete(chemin, data: data));

  Future<List<int>> octets(String chemin) => _executer<List<int>>(
      () => dio.get<List<int>>(chemin.replaceFirst(RegExp(r'^/api'), ''), options: Options(responseType: ResponseType.bytes)));

  static Map<String, dynamic>? _nettoyer(Map<String, dynamic>? p) =>
      p == null ? null : (Map.of(p)..removeWhere((k, v) => v == null || v == ''));
}
