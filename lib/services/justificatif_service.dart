import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _proxyUrl = 'https://script.google.com/macros/s/AKfycbwjxQYCPNSjz_y47f01nJJ-4qEx-vwlHcbdNCndf--oG4gGz7Y7rEuD-xS07c-iKDNB/exec';
const _secret = 'gestionloc2024';

class JustificatifService {

  /// Upload un fichier vers Drive et retourne l'URL
  static Future<String?> uploadFichier({
    required String entiteId, // tx_xxx ou cf_xxx
    required String source,   // 'camera', 'galerie', 'fichier'
  }) async {
    try {
      List<int>? bytes;
      String? mimeType;
      String? fileName;

      if (source == 'camera') {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
        if (picked == null) return null;
        bytes = await picked.readAsBytes();
        mimeType = 'image/jpeg';
        fileName = 'justif_${entiteId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else if (source == 'galerie') {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (picked == null) return null;
        bytes = await picked.readAsBytes();
        mimeType = 'image/jpeg';
        fileName = 'justif_${entiteId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } else if (source == 'fichier') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
          withData: true,
        );
        if (result == null || result.files.single.bytes == null) return null;
        bytes = result.files.single.bytes!;
        final ext = result.files.single.extension ?? 'pdf';
        mimeType = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
        fileName = 'justif_${entiteId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      }

      if (bytes == null) return null;

      final base64Data = base64Encode(bytes);

      final uri = Uri.parse(_proxyUrl);
      final sheetName = entiteId.startsWith('cf_') ? 'ChargesFixe' : 'Transactions';
      debugPrint('Upload: envoi de $fileName ($mimeType), ${bytes.length} octets');
      final resp = await http.post(uri, body: {
        'secret': _secret,
        'action': 'upload',
        'sheet': sheetName,
        'fileData': base64Data,
        'fileName': fileName,
        'mimeType': mimeType,
      });

      debugPrint('Upload: status=${resp.statusCode}');
      debugPrint('Upload: body=${resp.body}');

      final json = jsonDecode(resp.body);
      if (json['success'] == true) {
        return json['url'] as String;
      }
      debugPrint('Upload: échec — ${json['error'] ?? 'réponse inattendue'}');
      return null;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  /// Ouvre le justificatif dans le navigateur
  static Future<void> ouvrir(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Erreur ouverture justificatif: $e');
    }
  }

  /// Affiche le dialog de choix de source
  static Future<String?> choisirSource(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Text('Ajouter un justificatif', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _SourceBtn(Icons.camera_alt, 'Photo', () => Navigator.pop(context, 'camera')),
              _SourceBtn(Icons.photo_library, 'Galerie', () => Navigator.pop(context, 'galerie')),
              _SourceBtn(Icons.picture_as_pdf, 'Fichier PDF', () => Navigator.pop(context, 'fichier')),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

class _SourceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceBtn(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
          child: Center(child: Icon(icon, size: 28)),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}
