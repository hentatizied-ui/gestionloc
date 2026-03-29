import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SheetsService extends ChangeNotifier {
  static const String _proxyUrl = 'https://script.google.com/macros/s/AKfycbwjxQYCPNSjz_y47f01nJJ-4qEx-vwlHcbdNCndf--oG4gGz7Y7rEuD-xS07c-iKDNB/exec';
  static const String _secret = 'gestionloc2024';

  final bool _isReady = true;
  bool get isReady => _isReady;

  // ── Lire un onglet ──────────────────────────────────────────────────────

  Future<List<List<String>>> readSheet(String sheetName) async {
    try {
      final url = Uri.parse('$_proxyUrl?secret=$_secret&action=read&sheet=${Uri.encodeComponent(sheetName)}');
      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint('Sheets read error: ${response.body}');
        return [];
      }
      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        debugPrint('Sheets error: ${data['error']}');
        return [];
      }
      final values = data['values'] as List<dynamic>?;
      if (values == null || values.isEmpty) return [];
      return values.map((row) =>
        (row as List<dynamic>).map((c) => c.toString()).toList()
      ).toList();
    } catch (e) {
      debugPrint('readSheet error ($sheetName): $e');
      return [];
    }
  }

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
      if (map.values.any((v) => v.isNotEmpty)) result.add(map);
    }
    return result;
  }

  // ── Ajouter une ligne ───────────────────────────────────────────────────

  Future<bool> appendRow(String sheetName, List<String> values) async {
    try {
      final url = Uri.parse('$_proxyUrl?secret=$_secret&action=append&sheet=${Uri.encodeComponent(sheetName)}&row=${Uri.encodeComponent(jsonEncode(values))}');
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('appendRow error: $e');
      return false;
    }
  }

  // ── Mettre à jour une ligne ─────────────────────────────────────────────

  Future<bool> updateRow(String sheetName, String id, List<String> values) async {
    try {
      final url = Uri.parse('$_proxyUrl?secret=$_secret&action=update&sheet=${Uri.encodeComponent(sheetName)}&id=${Uri.encodeComponent(id)}&row=${Uri.encodeComponent(jsonEncode(values))}');
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('updateRow error: $e');
      return false;
    }
  }

  // ── Supprimer une ligne ─────────────────────────────────────────────────

  Future<bool> deleteRow(String sheetName, String id) async {
    try {
      final url = Uri.parse('$_proxyUrl?secret=$_secret&action=delete&sheet=${Uri.encodeComponent(sheetName)}&id=${Uri.encodeComponent(id)}');
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      debugPrint('deleteRow error: $e');
      return false;
    }
  }
}