class ApiConstants {
  static const String baseUrl   = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );
  static const String register  = '/auth/register/';
  static const String login     = '/auth/login/';
  static const String profile   = '/auth/profile/';
  static const String incidents = '/incidents/';
  static const String sosAlert  = '/alerts/sos/';
}
