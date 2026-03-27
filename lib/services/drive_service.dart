import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Stocke les données dans un dossier "GestionLocative" sur Google Drive
/// Format : un fichier JSON par entité (biens.json, locataires.json, etc.)
class DriveService extends ChangeNotifier {
  AuthService? _auth;
  drive.DriveApi? _driveApi;
  String? _folderId;

  static const String _folderName = 'GestionLocative';
  static const List<String> _files = [
    'biens.json',
    'locataires.json',
    'transactions.json',
    'tickets.json',
  ];

  bool _isReady = false;
  bool get isReady => _isReady;

  void updateAuth(AuthService auth) {
    _auth = auth;
    if (auth.isSignedIn) {
      _initialize();
    } else {
      _driveApi = null;
      _folderId = null;
      _isReady = false;
      notifyListeners();
    }
  }

  Future<void> _initialize() async {
    try {
      final headers = await _auth!.getAuthHeaders();
      final client = _AuthClient(headers);
      _driveApi = drive.DriveApi(client);
      _folderId = await _getOrCreateFolder();
      await _ensureFilesExist();
      _isReady = true;
      notifyListeners();
    } catch (e) {
      debugPrint('DriveService init error: $e');
      _isReady = false;
      notifyListeners();
    }
  }

  Future<String> _getOrCreateFolder() async {
    final result = await _driveApi!.files.list(
      q: "name='$_folderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      spaces: 'drive',
      $fields: 'files(id,name)',
    );

    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id!;
    }

    final folder = drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await _driveApi!.files.create(folder);
    return created.id!;
  }

  Future<void> _ensureFilesExist() async {
    for (final fileName in _files) {
      final existing = await _getFileId(fileName);
      if (existing == null) {
        await _writeFile(fileName, '[]');
      }
    }
  }

  Future<String?> _getFileId(String fileName) async {
    final result = await _driveApi!.files.list(
      q: "name='$fileName' and '${_folderId!}' in parents and trashed=false",
      spaces: 'drive',
      $fields: 'files(id,name)',
    );
    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> readJson(String fileName) async {
    try {
      final fileId = await _getFileId(fileName);
      if (fileId == null) return [];

      final media = await _driveApi!.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      final content = utf8.decode(bytes);
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('DriveService readJson error ($fileName): $e');
      return [];
    }
  }

  Future<void> writeJson(String fileName, List<Map<String, dynamic>> data) async {
    final content = jsonEncode(data);
    await _writeFile(fileName, content);
  }

  Future<void> _writeFile(String fileName, String content) async {
    final bytes = utf8.encode(content);
    final stream = Stream.fromIterable([bytes]);
    final media = drive.Media(stream, bytes.length, contentType: 'application/json');

    final existingId = await _getFileId(fileName);

    if (existingId != null) {
      await _driveApi!.files.update(
        drive.File(),
        existingId,
        uploadMedia: media,
      );
    } else {
      final file = drive.File()
        ..name = fileName
        ..parents = [_folderId!];
      await _driveApi!.files.create(file, uploadMedia: media);
    }
  }

  Future<void> refreshAuth() async {
    if (_auth != null && _auth!.isSignedIn) {
      await _initialize();
    }
  }
}

/// Client HTTP qui injecte les headers Google OAuth
class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _AuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
