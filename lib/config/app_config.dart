// ═══════════════════════════════════════════════════════════════════════════
// CONFIGURATION DE L'APPLICATION
// ═══════════════════════════════════════════════════════════════════════════
//
// Ce fichier centralise les valoreurs de configuration qui peuvent varier
// selon l'environnement (dev, staging, prod).
//
// IMPORTANT: Les secrets ne doivent jamais être hardcodés. Utilisez
// --dart-define au moment de la compilation :
//
//   flutter run --dart-define=SHEETS_SECRET=xxx
//   flutter build apk --dart-define=SHEETS_SECRET=xxx
//
// Pour lister les defines:flutter build apk --dart-define=SHEETS_SECRET=xxx --trace
// ═══════════════════════════════════════════════════════════════════════════

class AppConfig {
  // Override du secret (pour mode debug seulement)
  static String? _overrideSecret;

  /// Secret pour l'API Google Apps Script
  /// Priorité : 1) override (mode debug), 2) --dart-define, 3) vide
  static String get sheetsSecret {
    // En debug, on peut utiliser un override
    if (_overrideSecret != null && _overrideSecret!.isNotEmpty) {
      return _overrideSecret!;
    }

    // Sinon, lire depuis dart-define
    const secret = String.fromEnvironment('SHEETS_SECRET', defaultValue: '');
    return secret;
  }

  /// Vérifie si le secret est configuré
  static bool get hasSheetsSecret {
    return sheetsSecret.isNotEmpty;
  }

  /// Définir le secret manuellement (mode debug seulement)
  static set sheetsSecret(String? value) {
    _overrideSecret = value;
  }

  /// Retourne true si un override de secret est défini (mode debug)
  static bool get hasSecretOverride => _overrideSecret?.isNotEmpty == true;

  /// URL du proxy Google Apps Script
  static const String sheetsProxyUrl =
      'https://script.google.com/macros/s/AKfycbwjxQYCPNSjz_y47f01nJJ-4qEx-vwlHcbdNCndf--oG4gGz7Y7rEuD-xS07c-iKDNB/exec';

  /// Timeout pour les requêtes HTTP (en secondes)
  /// Augmenté à 60s pour les feuilles volumineuses
  static const Duration httpTimeout = Duration(seconds: 60);

  /// Logs détaillés en debug
  static bool get enableDebugLogs => const bool.fromEnvironment('dart.vm.product') == false;
}
