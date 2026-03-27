import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class SheetsService extends ChangeNotifier {
  static const String _spreadsheetId = '1Z8HxMbYnMum7Z8ysgnG6SnwIMgV15a3n';
  static const String _baseUrl = 'https://sheets.googleapis.com/v4/spreadsheets';

  AuthService? _auth;
  bool _isReady = false;
  bool get isReady => _isReady;

  void updateAuth(AuthService auth) {
    _auth = auth;
    if (auth.isSignedIn) {
      _isReady = true;
      notifyListeners();
    } else {
      _isReady = false;
      notifyListeners();
    }
  }

  Future<Map<String, String>> _headers() async {
    if (_auth == null) throw Exception('Non connecté');
    return await _auth!.getAuthHeaders();
  }

  // ── Lire un onglet complet ──────────────────────────────────────────────

  Future<List<List<String>>> readSheet(String sheetName) async {
    try {
      final headers = await _headers();
      final url = '$_baseUrl/$_spreadsheetId/values/$sheetName';
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode != 200) {
        debugPrint('Sheets read error: ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body);
      final values = data['values'] as List<dynamic>?;
      if (values == null || values.isEmpty) return [];

      return values.map((row) {
        return (row as List<dynamic>).map((cell) => cell.toString()).toList();
      }).toList();
    } catch (e) {
      debugPrint('readSheet error ($sheetName): $e');
      return [];
    }
  }

  // ── Lire avec en-têtes → liste de maps ─────────────────────────────────

  Future<List<Map<String, String>>> readSheetAsMap(String sheetName) async {
    final rows = await readSheet(sheetName);
    if (rows.isEmpty) return [];

    final headers = rows.first;
    final result = <Map<String, String>>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final map = <String, String>{};
      for (int j = 0; j < headers.length; j++) {
        map[headers[j]] = j < row.length ? row[j] : '';
      }
      // Ignorer les lignes vides
      if (map.values.any((v) => v.isNotEmpty)) {
        result.add(map);
      }
    }
    return result;
  }

  // ── Ajouter une ligne ───────────────────────────────────────────────────

  Future<bool> appendRow(String sheetName, List<String> values) async {
    try {
      final headers = await _headers();
      final url = '$_baseUrl/$_spreadsheetId/values/$sheetName!A1:append'
          '?valueInputOption=RAW&insertDataOption=INSERT_ROWS';

      final body = jsonEncode({
        'values': [values],
      });

      final response = await http.post(
        Uri.parse(url),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('appendRow error ($sheetName): $e');
      return false;
    }
  }

  // ── Mettre à jour une ligne par ID ─────────────────────────────────────

  Future<bool> updateRow(String sheetName, String id, List<String> values) async {
    try {
      final rows = await readSheet(sheetName);
      if (rows.isEmpty) return false;

      // Trouver la ligne avec cet ID (colonne A)
      int rowIndex = -1;
      for (int i = 1; i < rows.length; i++) {
        if (rows[i].isNotEmpty && rows[i][0] == id) {
          rowIndex = i + 1; // +1 car Sheets est 1-indexé
          break;
        }
      }

      if (rowIndex == -1) return false;

      final headers = await _headers();
      final lastCol = _colLetter(values.length);
      final range = '$sheetName!A$rowIndex:$lastCol$rowIndex';
      final url = '$_baseUrl/$_spreadsheetId/values/$range'
          '?valueInputOption=RAW';

      final body = jsonEncode({
        'values': [values],
      });

      final response = await http.put(
        Uri.parse(url),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('updateRow error ($sheetName): $e');
      return false;
    }
  }

  // ── Supprimer une ligne par ID ──────────────────────────────────────────

  Future<bool> deleteRow(String sheetName, String id) async {
    try {
      final rows = await readSheet(sheetName);
      if (rows.isEmpty) return false;

      int rowIndex = -1;
      for (int i = 1; i < rows.length; i++) {
        if (rows[i].isNotEmpty && rows[i][0] == id) {
          rowIndex = i; // 0-indexé pour l'API batch
          break;
        }
      }

      if (rowIndex == -1) return false;

      // Récupérer le sheetId
      final sheetId = await _getSheetId(sheetName);
      if (sheetId == null) return false;

      final headers = await _headers();
      final url = '$_baseUrl/$_spreadsheetId:batchUpdate';

      final body = jsonEncode({
        'requests': [
          {
            'deleteDimension': {
              'range': {
                'sheetId': sheetId,
                'dimension': 'ROWS',
                'startIndex': rowIndex,
                'endIndex': rowIndex + 1,
              }
            }
          }
        ]
      });

      final response = await http.post(
        Uri.parse(url),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: body,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('deleteRow error ($sheetName): $e');
      return false;
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<int?> _getSheetId(String sheetName) async {
    try {
      final headers = await _headers();
      final url = '$_baseUrl/$_spreadsheetId?fields=sheets.properties';
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final sheets = data['sheets'] as List<dynamic>;
      for (final sheet in sheets) {
        final props = sheet['properties'];
        if (props['title'] == sheetName) {
          return props['sheetId'] as int;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String _colLetter(int count) {
    if (count <= 26) return String.fromCharCode(64 + count);
    return 'Z'; // max
  }
}
