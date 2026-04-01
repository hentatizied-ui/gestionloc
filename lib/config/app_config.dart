// ═══════════════════════════════════════════════════════════════════════════
// CONFIGURATION DE L'APPLICATION
// ═══════════════════════════════════════════════════════════════════════════
//
// L'application utilise un Google Apps Script déployé en mode "Public".
// Aucune authentification ni secret n'est requis.
// ═══════════════════════════════════════════════════════════════════════════

class AppConfig {
  /// URL du Google Apps Script (doit être déployé en "Public")
  static const String sheetsProxyUrl =
      'https://script.google.com/macros/s/AKfycbwjxQYCPNSjz_y47f01nJJ-4qEx-vwlHcbdNCndf--oG4gGz7Y7rEuD-xS07c-iKDNB/exec';

  /// Timeout pour les requêtes HTTP (en secondes)
  static const Duration httpTimeout = Duration(seconds: 60);

  /// Logs détaillés en debug
  static bool get enableDebugLogs => const bool.fromEnvironment('dart.vm.product') == false;
}
