import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class AuthService extends ChangeNotifier {
  static const String _webClientId =
      '77548941980-2qb736cep0b6sppff094nkuuaaocivu3.apps.googleusercontent.com';
  static const String _iosClientId =
      '77548941980-gshf15fetpo1su6t5ifnm4ku2h3s8kpm.apps.googleusercontent.com';

  static GoogleSignIn _buildGoogleSignIn() {
    if (kIsWeb) {
      return GoogleSignIn(
        clientId: _webClientId,
        scopes: [
          'email',
          'profile',
          drive.DriveApi.driveFileScope,
        ],
      );
    }
    return GoogleSignIn(
      clientId: _iosClientId,
      scopes: [
        'email',
        'profile',
        drive.DriveApi.driveFileScope,
      ],
      serverClientId: _webClientId,
    );
  }

  static final GoogleSignIn _googleSignIn = _buildGoogleSignIn();

  GoogleSignInAccount? _user;
  bool _isLoading = false;
  String? _error;

  GoogleSignInAccount? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSignedIn => _user != null;
  String? get error => _error;

  String get displayName => _user?.displayName ?? 'Utilisateur';
  String get email => _user?.email ?? '';
  String? get photoUrl => _user?.photoUrl;

  AuthService() {
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _googleSignIn.signInSilently();
    } catch (e) {
      _user = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> signIn() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _googleSignIn.signIn();
      _isLoading = false;
      notifyListeners();
      return _user != null;
    } catch (e) {
      _error = 'Erreur de connexion : $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _user = null;
    notifyListeners();
  }

  Future<Map<String, String>> getAuthHeaders() async {
    if (_user == null) throw Exception('Non connecté');
    return await _user!.authHeaders;
  }
}