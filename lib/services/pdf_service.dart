import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

final _pdfEuro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);
final _pdfDateF = DateFormat('dd/MM/yyyy', 'fr_FR');
final _pdfDateMoisF = DateFormat('MMMM yyyy', 'fr_FR');

class PdfService {
  static Future<Uint8List> genererQuittance({
    required Locataire locataire,
    required Bien bien,
    required Transaction paiement,
    required DateTime mois,
  }) async {
    final pdf = pw.Document();

    // Charger les signatures
    final sig1Bytes = await rootBundle.load('assets/images/signature_saafi.png');
    final sig2Bytes = await rootBundle.load('assets/images/signature_hentati.jpg');
    final sig1 = pw.MemoryImage(sig1Bytes.buffer.asUint8List());
    final sig2 = pw.MemoryImage(sig2Bytes.buffer.asUint8List());

    // Charger une police
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    final moisStr = _capitalize(_pdfDateMoisF.format(mois));
    final loyer = bien.loyerMensuel;
    final charges = bien.charges;
    final total = loyer + charges;
    final debutMois = DateTime(mois.year, mois.month, 1);
    final finMois = DateTime(mois.year, mois.month + 1, 0);
    final adresse = '${bien.adresse}, ${bien.ville} ${bien.codePostal}';
    final totalLettre = _montantEnLettres(total);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

            // Titre
            pw.Center(child: pw.Text(
              'QUITTANCE DE LOYER DU MOIS DE ${moisStr.toUpperCase()}',
              style: pw.TextStyle(font: fontBold, fontSize: 14),
              textAlign: pw.TextAlign.center,
            )),
            pw.SizedBox(height: 20),

            // Propriétaires
            pw.Text('Propriétaires :', style: pw.TextStyle(font: fontItalic, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text('  • Mohamed SAAFI : 📞 +33 7 51 42 68 22', style: pw.TextStyle(font: fontItalic, fontSize: 11)),
            pw.Text('  • Zied HENTATI : 📞 +33 7 53 69 12 64', style: pw.TextStyle(font: fontItalic, fontSize: 11)),
            pw.SizedBox(height: 16),

            // Locataire
            pw.Text('À l\'Attention de ${locataire.nomComplet}', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Fait à ${bien.ville}, le ${_pdfDateF.format(paiement.date)}',
              style: pw.TextStyle(font: font, fontSize: 11),
            ),
            pw.SizedBox(height: 16),

            // Adresse
            pw.Text('Adresse de l\'appartement loué :', style: pw.TextStyle(font: fontBold, fontSize: 11,
                decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 4),
            pw.Text('  • $adresse', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.SizedBox(height: 16),

            // Corps
            pw.Text(
              'Nous soussignés, Mohamed SAAFI et Zied HENTATI, propriétaires de l\'appartement désigné ci-dessus, '
              'déclarons avoir reçu de ${locataire.nomComplet} '
              'la somme de ${total.toInt()} ($totalLettre euros), au titre du paiement du loyer et des charges '
              'pour la période de location du ${_pdfDateF.format(debutMois)} au ${_pdfDateF.format(finMois)}, '
              'et lui en donnons quittance, sous réserve de tous nos droits.',
              style: pw.TextStyle(font: font, fontSize: 11),
            ),
            pw.SizedBox(height: 20),

            // Détail
            pw.Text('Détail du règlement :', style: pw.TextStyle(font: fontBold, fontSize: 11,
                decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 6),
            pw.Text('  • Loyer : ${_pdfEuro.format(loyer)}', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.Text('  • Provision sur charges : ${_pdfEuro.format(charges)}', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text('  • Total : ${_pdfEuro.format(total)}', style: pw.TextStyle(font: fontBold, fontSize: 11)),
            pw.SizedBox(height: 8),
            pw.Text('Date de paiement : ${_pdfDateF.format(paiement.date)}', style: pw.TextStyle(font: font, fontSize: 11)),
            pw.SizedBox(height: 16),

            // Mention légale
            pw.Text(
              'Cette quittance annule tous les reçus qui auraient pu être établis précédemment en cas de paiement '
              'partiel du montant du présent terme. Elle est à conserver pendant trois ans par le locataire '
              '(loi n° 89-462 du 6 juillet 1989, art. 7-1).',
              style: pw.TextStyle(font: fontItalic, fontSize: 9, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 30),

            // Signatures
            pw.Text('Signatures :', style: pw.TextStyle(font: fontBold, fontSize: 11)),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(children: [
                  pw.Image(sig1, width: 100),
                  pw.SizedBox(height: 4),
                  pw.Text('Mohamed SAAFI', style: pw.TextStyle(font: font, fontSize: 11)),
                ]),
                pw.Column(children: [
                  pw.Image(sig2, width: 90),
                  pw.SizedBox(height: 4),
                  pw.Text('Zied HENTATI', style: pw.TextStyle(font: font, fontSize: 11)),
                ]),
              ],
            ),
          ],
        );
      },
    ));

    return pdf.save();
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _montantEnLettres(double montant) {
    final int m = montant.toInt();
    const unite = ['', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
      'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize', 'dix-sept', 'dix-huit', 'dix-neuf'];
    const dizaine = ['', '', 'vingt', 'trente', 'quarante', 'cinquante', 'soixante', 'soixante', 'quatre-vingt', 'quatre-vingt'];

    if (m < 20) return unite[m];
    if (m < 100) {
      final d = m ~/ 10;
      final u = m % 10;
      if (d == 7 || d == 9) return '${dizaine[d]}-${unite[10 + u]}';
      if (u == 1 && d != 8) return '${dizaine[d]}-et-un';
      if (u == 0 && d == 8) return 'quatre-vingts';
      return u == 0 ? dizaine[d] : '${dizaine[d]}-${unite[u]}';
    }
    if (m < 1000) {
      final c = m ~/ 100;
      final r = m % 100;
      final centStr = c == 1 ? 'cent' : '${unite[c]} cents';
      return r == 0 ? centStr : '${c == 1 ? "cent" : "${unite[c]} cent"} ${_montantEnLettres(r.toDouble())}';
    }
    return montant.toString();
  }
}