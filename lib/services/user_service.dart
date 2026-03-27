import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserService extends ChangeNotifier {
  String? _prenom;
  String? _nom;
  bool _isReady = false;

  String? get prenom => _prenom;
  String? get nom => _nom;
  bool get isReady => _isReady;
  bool get isConfigured => _prenom != null && _prenom!.isNotEmpty;
  String get displayName => '${_prenom ?? ''} ${_nom ?? ''}'.trim();
  String get initiales {
    final p = _prenom?.isNotEmpty == true ? _prenom![0] : '';
    final n = _nom?.isNotEmpty == true ? _nom![0] : '';
    return '$p$n'.toUpperCase();
  }

  UserService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _prenom = prefs.getString('user_prenom');
    _nom = prefs.getString('user_nom');
    _isReady = true;
    notifyListeners();
  }

  Future<void> saveUser(String prenom, String nom) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_prenom', prenom);
    await prefs.setString('user_nom', nom);
    _prenom = prenom;
    _nom = nom;
    notifyListeners();
  }

  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_prenom');
    await prefs.remove('user_nom');
    _prenom = null;
    _nom = null;
    notifyListeners();
  }
}
