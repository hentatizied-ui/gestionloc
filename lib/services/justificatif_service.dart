import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class JustificatifService {

  /// Retourne le sous-dossier Drive selon le type de charge fixe
  static String? sousDossierPourType(String? typeName) {
    switch (typeName) {
      case 'charge':    return 'Justificatifs_Crédit';
      case 'assurance': return 'Justificatifs_Assurances';
      case 'taxe':      return 'Justificatifs_Taxes';
      case 'facture':   return 'Justificatifs_Factures';
      default:          return null;
    }
  }

  /// Retourne le sous-dossier Drive selon le sens de la transaction
  static String sousDossierPourTransaction(bool isRecette) =>
      isRecette ? 'Recettes' : 'Dépenses';

  /// Upload un fichier vers Drive et retourne l'URL
  static Future<String?> uploadFichier({
    required String entiteId, // tx_xxx ou cf_xxx
    required String source,   // 'camera', 'galerie', 'fichier'
    String? sousDossier,      // sous-dossier Drive cible
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

      final uri = Uri.parse(AppConfig.sheetsProxyUrl);
      final sheetName = entiteId.startsWith('cf_') ? 'ChargesFixe' : 'Transactions';
      final body = <String, String>{
        'secret': AppConfig.sheetsSecret,
        'action': 'upload',
        'sheet': sheetName,
        'fileData': base64Data,
        'fileName': fileName!,
        'mimeType': mimeType!,
        if (sousDossier != null) 'sousDossier': sousDossier,
      };
      debugPrint('Upload: envoi de $fileName ($mimeType), ${bytes.length} octets');

      try {
        // Google Apps Script renvoie un 302 redirect sur mobile
        // On suit le redirect manuellement si la réponse est du HTML
        var resp = await http.post(uri, body: body).timeout(AppConfig.httpTimeout);

        if (resp.body.trimLeft().startsWith('<')) {
          final match = RegExp(r'HREF="([^"]+)"', caseSensitive: false).firstMatch(resp.body);
          if (match != null) {
            final redirectUrl = match.group(1)!.replaceAll('&amp;', '&');
            resp = await http.get(Uri.parse(redirectUrl)).timeout(AppConfig.httpTimeout);
          }
        }

        debugPrint('Upload: status=${resp.statusCode}');
        debugPrint('Upload: body=${resp.body.substring(0, math.min(resp.body.length, 500))}');

        if (resp.statusCode != 200) {
          debugPrint('Upload HTTP error ${resp.statusCode}');
          return null;
        }

        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        if (json['success'] == true) {
          return json['url'] as String;
        }
        debugPrint('Upload: échec — ${json['error'] ?? 'réponse inattendue'}');
        return null;
      } on TimeoutException catch (e) {
        debugPrint('Upload timeout: $e');
        return null;
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  /// Extrait le fileId depuis une URL Drive
  static String? _extraireFileId(String url) {
    final match = RegExp(r'/file/d/([a-zA-Z0-9_-]+)').firstMatch(url);
    return match?.group(1);
  }

  /// Supprime le fichier de Drive
  static Future<void> supprimerFichier(String url) async {
    final fileId = _extraireFileId(url);
    if (fileId == null) return;
    try {
      final uri = Uri.parse('${AppConfig.sheetsProxyUrl}?secret=${AppConfig.sheetsSecret}&action=deleteFile&fileId=${Uri.encodeComponent(fileId)}');
      await http.get(uri).timeout(AppConfig.httpTimeout);
    } catch (e) {
      debugPrint('Erreur suppression Drive: $e');
    }
  }

  /// Vérifie si le fichier existe encore sur Drive
  static Future<bool> fichierExiste(String url) async {
    final fileId = _extraireFileId(url);
    if (fileId == null) return false;
    try {
      final uri = Uri.parse('${AppConfig.sheetsProxyUrl}?secret=${AppConfig.sheetsSecret}&action=checkFile&fileId=${Uri.encodeComponent(fileId)}');
      final resp = await http.get(uri).timeout(AppConfig.httpTimeout);
      if (resp.statusCode != 200) {
        debugPrint('fichierExiste HTTP ${resp.statusCode}: ${resp.body}');
        return false;
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return json['success'] == true;
    } catch (e) {
      debugPrint('fichierExiste error: $e');
      return false;
    }
  }

  /// Ouvre le justificatif, vérifie d'abord son existence.
  /// Si introuvable, affiche un dialog et appelle [onSupprimer] si confirmé.
  static Future<void> ouvrirAvecVerif(
    BuildContext context,
    String url, {
    required Future<void> Function() onSupprimer,
  }) async {
    final existe = await fichierExiste(url);
    if (!context.mounted) return;
    if (existe) {
      await ouvrir(url);
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Fichier introuvable'),
          content: const Text('Ce fichier a été supprimé de Drive. Voulez-vous supprimer ce lien ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await onSupprimer();
              },
              child: const Text('Supprimer le lien', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
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
