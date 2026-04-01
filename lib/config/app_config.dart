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
  /// Secret pour l'API Google Apps Script
  /// DOIT être passé via --dart-define=SHEETS_SECRET
  static String get sheetsSecret {
    const secret = String.fromEnvironment('SHEETS_SECRET', defaultValue: '');
    if (secret.isEmpty) {
      throw StateError(
        'SHEETS_SECRET non défini. '
        'Compilez avec: flutter run --dart-define=SHEETS_SECRET=votre_secret',
      );
    }
    return secret;
  }

  /// URL du proxy Google Apps Script
  static const String sheetsProxyUrl =
      'https://script.google.com/macros/s/AKfycbwjxQYCPNSjz_y47f01nJJ-4qEx-vwlHcbdNCndf--oG4gGz7Y7rEuD-xS07c-iKDNB/exec';

  /// Timeout pour les requêtes HTTP (en secondes)
  /// Augmenté à 60s pour les feuilles volumineuses
  static const Duration httpTimeout = Duration(seconds: 60);

  /// Logs détaillés en debug
  static bool get enableDebugLogs => const bool.fromEnvironment('dart.vm.product') == false;
}
