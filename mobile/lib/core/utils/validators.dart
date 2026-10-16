class Validators {
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Identifiant / Email obligatoire';
    if (v.trim().length < 3) return 'Minimum 3 caractères';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Mot de passe obligatoire';
    if (v.length < 6) return 'Minimum 6 caractères';
    return null;
  }

  static String? required(String? v, String field) {
    if (v == null || v.isEmpty) return '$field obligatoire';
    return null;
  }

  static String? confirmPassword(String? v, String password) {
    if (v == null || v.isEmpty) return 'Confirmation obligatoire';
    if (v != password) return 'Les mots de passe ne correspondent pas';
    return null;
  }
}
