import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class SheetsService extends ChangeNotifier {
  final bool _isReady = true;
  bool get isReady => _isReady;

  // ── Lire un onglet ──────────────────────────────────────────────────────

  Future<List<List<String>>> readSheet(String sheetName) async {
    try {
      final url = Uri.parse('${AppConfig.sheetsProxyUrl}?secret=${AppConfig.sheetsSecret}&action=read&sheet=${Uri.encodeComponent(sheetName)}');
      final response = await http.get(url).timeout(
        AppConfig.httpTimeout,
        onTimeout: () => throw TimeoutException('Timeout lecture feuille "$sheetName" après ${AppConfig.httpTimeout.inSeconds}s'),
      );

      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode} lors de la lecture de "$sheetName"', uri: url);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['error'] != null) {
        throw Exception('Erreur Sheets: ${data['error']}');
      }

      final values = data['values'] as List<dynamic>?;
      if (values == null || values.isEmpty) return [];

      return values.map((row) =>
        (row as List<dynamic>).map((c) => c.toString()).toList()
      ).toList();
    } catch (e) {
      debugPrint('readSheet error ($sheetName): $e');
      rethrow;
    }
  }

  Future<List<Map<String, String>>> readSheetAsMap(String sheetName) async {
    final rows = await readSheet(sheetName);
    if (rows.isEmpty) return [];
    final headers = rows.first.map((h) => h.trim()).toList();
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
      final url = Uri.parse('${AppConfig.sheetsProxyUrl}?secret=${AppConfig.sheetsSecret}&action=append&sheet=${Uri.encodeComponent(sheetName)}&row=${Uri.encodeComponent(jsonEncode(values))}');
      final response = await http.get(url).timeout(AppConfig.httpTimeout);
      if (response.statusCode != 200) {
        debugPrint('appendRow HTTP error ${response.statusCode}: ${response.body}');
        return false;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    } catch (e) {
      debugPrint('appendRow error ($sheetName): $e');
      return false;
    }
  }

  // ── Mettre à jour une ligne ─────────────────────────────────────────────

  Future<bool> updateRow(String sheetName, String id, List<String> values) async {
    try {
      final url = Uri.parse('${AppConfig.sheetsProxyUrl}?secret=${AppConfig.sheetsSecret}&action=update&sheet=${Uri.encodeComponent(sheetName)}&id=${Uri.encodeComponent(id)}&row=${Uri.encodeComponent(jsonEncode(values))}');
      final response = await http.get(url).timeout(AppConfig.httpTimeout);
      if (response.statusCode != 200) {
        debugPrint('updateRow HTTP error ${response.statusCode}: ${response.body}');
        return false;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    } catch (e) {
      debugPrint('updateRow error ($sheetName/$id): $e');
      return false;
    }
  }

  // ── Lire / écrire une cellule ──────────────────────────────────────────

  Future<double?> readCell(String sheetName, String cell) async {
    try {
      final url = Uri.parse('${AppConfig.sheetsProxyUrl}?secret=${AppConfig.sheetsSecret}&action=readCell&sheet=${Uri.encodeComponent(sheetName)}&cell=${Uri.encodeComponent(cell)}');
      final response = await http.get(url).timeout(AppConfig.httpTimeout);

      if (response.statusCode != 200) {
        debugPrint('readCell HTTP ${response.statusCode} ($sheetName!$cell): ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['success'] != true) {
        debugPrint('readCell API error ($sheetName!$cell): ${data['error']}');
        return null;
      }

      final rawValue = data['value'];
      if (rawValue == null || rawValue.toString().isEmpty) {
        return null;
      }

      final parsed = double.tryParse(rawValue.toString());
      if (parsed == null) {
        debugPrint('readCell: valeur non numérique ($sheetName!$cell): $rawValue');
      }
      return parsed;
    } catch (e) {
      debugPrint('readCell exception ($sheetName!$cell): $e');
      return null;
    }
  }

  Future<bool> writeCell(String sheetName, String cell, dynamic value) async {
    try {
      final url = Uri.parse('${AppConfig.sheetsProxyUrl}?secret=${AppConfig.sheetsSecret}&action=writeCell&sheet=${Uri.encodeComponent(sheetName)}&cell=${Uri.encodeComponent(cell)}&value=${Uri.encodeComponent(value.toString())}');
      final response = await http.get(url).timeout(AppConfig.httpTimeout);

      if (response.statusCode != 200) {
        debugPrint('writeCell HTTP error ${response.statusCode} ($sheetName!$cell=$value): ${response.body.substring(0, math.min(response.body.length, 200))}');
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['error'] != null) {
        debugPrint('writeCell API error ($sheetName!$cell=$value): ${data['error']}');
        return false;
      }

      return data['success'] == true;
    } catch (e) {
      debugPrint('writeCell exception ($sheetName!$cell=$value): $e');
      return false;
    }
  }

  // ── Supprimer une ligne ─────────────────────────────────────────────────

  Future<bool> deleteRow(String sheetName, String id) async {
    try {
      final url = Uri.parse('${AppConfig.sheetsProxyUrl}?secret=${AppConfig.sheetsSecret}&action=delete&sheet=${Uri.encodeComponent(sheetName)}&id=${Uri.encodeComponent(id)}');
      final response = await http.get(url).timeout(AppConfig.httpTimeout);

      if (response.statusCode != 200) {
        debugPrint('deleteRow HTTP error ${response.statusCode} ($sheetName/$id): ${response.body}');
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['success'] == true;
    } catch (e) {
      debugPrint('deleteRow error ($sheetName/$id): $e');
      return false;
    }
  }
}