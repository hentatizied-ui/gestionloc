import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/app_config.dart';

// ── Modèles ────────────────────────────────────────────────────────────────

class SimulationComplete {
  final String id;
  final String nom;
  final DateTime date;
  final Map<String, dynamic> params;
  final double echeance;
  final List<int> annees;
  final Map<String, List<double>> resultats;

  const SimulationComplete({
    required this.id,
    required this.nom,
    required this.date,
    required this.params,
    required this.echeance,
    required this.annees,
    required this.resultats,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'date': date.toIso8601String(),
    'params': params,
    'echeance': echeance,
    'annees': annees,
    'resultats': resultats,
  };

  factory SimulationComplete.fromJson(Map<String, dynamic> j) => SimulationComplete(
    id: j['id'] as String,
    nom: j['nom'] as String,
    date: DateTime.parse(j['date'] as String),
    params: Map<String, dynamic>.from(j['params'] as Map),
    echeance: (j['echeance'] as num).toDouble(),
    annees: (j['annees'] as List).map((e) => (e as num).toInt()).toList(),
    resultats: (j['resultats'] as Map).map((k, v) => MapEntry(
      k as String,
      (v as List).map((e) => (e as num).toDouble()).toList(),
    )),
  );
}

// ── Service ────────────────────────────────────────────────────────────────

class SimulationSaveService {
  static const _prefKey = 'simulations_v1';
  static const _uuid    = Uuid();

  // ─── SAUVEGARDER ──────────────────────────────────────────────────────
  static Future<SimulationComplete> sauvegarder({
    required String nom,
    required Map<String, dynamic> params,
    required double echeance,
    required List<int> annees,
    required Map<String, List<double>> resultats,
  }) async {
    final sim = SimulationComplete(
      id:        _uuid.v4(),
      nom:       nom,
      date:      DateTime.now(),
      params:    params,
      echeance:  echeance,
      annees:    annees,
      resultats: resultats,
    );

    await _sauvegarderLocal(sim);
    _sauvegarderRemote(sim); // background, ne bloque pas
    return sim;
  }

  static Future<void> _sauvegarderLocal(SimulationComplete sim) async {
    final prefs = await SharedPreferences.getInstance();
    final list  = await lister();
    final idx   = list.indexWhere((s) => s.id == sim.id);
    if (idx >= 0) list[idx] = sim; else list.insert(0, sim);
    await prefs.setStringList(_prefKey, list.map((s) => jsonEncode(s.toJson())).toList());
  }

  static Future<void> _sauvegarderRemote(SimulationComplete sim) async {
    try {
      final url = Uri.parse(AppConfig.sheetsProxyUrl);
      await http.post(
        url,
        headers: {'Content-Type': 'text/plain'},
        body: jsonEncode({
          'action':  'saveSimulation',
          'id':      sim.id,
          'nom':     sim.nom,
          'date':    sim.date.toIso8601String(),
          'data':    jsonEncode(sim.toJson()),
        }),
      ).timeout(AppConfig.httpTimeout);
    } catch (e) {
      debugPrint('Sync Drive (sauvegarde) échouée: $e');
    }
  }

  // ─── LISTER (local) ────────────────────────────────────────────────────
  static Future<List<SimulationComplete>> lister() async {
    final prefs    = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_prefKey) ?? [];
    return jsonList.map((s) {
      try {
        return SimulationComplete.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<SimulationComplete>().toList();
  }

  // ─── SUPPRIMER ─────────────────────────────────────────────────────────
  static Future<void> supprimer(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list  = await lister();
    list.removeWhere((s) => s.id == id);
    await prefs.setStringList(_prefKey, list.map((s) => jsonEncode(s.toJson())).toList());
    _supprimerRemote(id); // background
  }

  static Future<void> _supprimerRemote(String id) async {
    try {
      final url = Uri.parse(
        '${AppConfig.sheetsProxyUrl}?action=deleteSimulation&id=${Uri.encodeComponent(id)}',
      );
      await http.get(url).timeout(AppConfig.httpTimeout);
    } catch (e) {
      debugPrint('Sync Drive (suppression) échouée: $e');
    }
  }

  // ─── SYNCHRONISER DEPUIS DRIVE ─────────────────────────────────────────
  /// Récupère depuis Drive les simulations absentes en local (ex: après réinstallation).
  /// Retourne la liste des nouvelles simulations ajoutées.
  static Future<List<SimulationComplete>> syncFromDrive() async {
    try {
      final listUrl = Uri.parse('${AppConfig.sheetsProxyUrl}?action=listSimulations');
      final listResp = await http.get(listUrl).timeout(AppConfig.httpTimeout);
      if (listResp.statusCode != 200) return [];

      final listData = jsonDecode(listResp.body) as Map<String, dynamic>;
      final remoteSims = (listData['simulations'] as List?) ?? [];

      final local    = await lister();
      final localIds = local.map((s) => s.id).toSet();

      final newSims = <SimulationComplete>[];
      for (final r in remoteSims) {
        final rid = (r as Map)['id'] as String;
        if (localIds.contains(rid)) continue;

        final loadUrl = Uri.parse(
          '${AppConfig.sheetsProxyUrl}?action=loadSimulation&id=${Uri.encodeComponent(rid)}',
        );
        final loadResp = await http.get(loadUrl).timeout(AppConfig.httpTimeout);
        if (loadResp.statusCode != 200) continue;

        final loadData = jsonDecode(loadResp.body) as Map<String, dynamic>;
        if (loadData['success'] != true) continue;

        final sim = SimulationComplete.fromJson(
          jsonDecode(loadData['data'] as String) as Map<String, dynamic>,
        );
        newSims.add(sim);
      }

      if (newSims.isNotEmpty) {
        final merged = [...newSims, ...local];
        final prefs  = await SharedPreferences.getInstance();
        await prefs.setStringList(
          _prefKey,
          merged.map((s) => jsonEncode(s.toJson())).toList(),
        );
      }

      return newSims;
    } catch (e) {
      debugPrint('Sync depuis Drive échouée: $e');
      return [];
    }
  }
}
