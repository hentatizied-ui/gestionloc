import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';

final _pdfEuro = NumberFormat.currency(locale: 'fr_FR', symbol: 'EUR', decimalDigits: 2);
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

    final sig1Bytes = await rootBundle.load('assets/images/signature_saafi.jpg');
    final sig2Bytes = await rootBundle.load('assets/images/signature_hentati.jpg');
    final sig1 = pw.MemoryImage(sig1Bytes.buffer.asUint8List());
    final sig2 = pw.MemoryImage(sig2Bytes.buffer.asUint8List());

    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    final moisStr = _capitalize(_pdfDateMoisF.format(mois));
    final loyer = bien.loyerMensuel;
    final charges = bien.charges;
    final total = loyer + charges;
    final debutMois = DateTime(mois.year, mois.month, 1);
    final finMois = DateTime(mois.year, mois.month + 1, 0);
    final adresse = bien.adresse + ', ' + bien.ville + ' ' + bien.codePostal;
    final totalLettre = _montantEnLettres(total);

    final styleNormal = pw.TextStyle(font: font, fontSize: 11);
    final styleBold = pw.TextStyle(font: fontBold, fontSize: 11);
    final styleItalic = pw.TextStyle(font: fontItalic, fontSize: 11);
    final styleLegal = pw.TextStyle(font: fontItalic, fontSize: 9, color: PdfColors.grey700);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 40),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [

            // Titre centré
            pw.Center(child: pw.Text(
              'QUITTANCE DE LOYER DU MOIS DE ' + moisStr.toUpperCase(),
              style: pw.TextStyle(font: fontBold, fontSize: 13),
              textAlign: pw.TextAlign.center,
            )),
            pw.SizedBox(height: 20),

            // Propriétaires (gauche)
            pw.Text('Proprietaires :', style: styleItalic),
            pw.SizedBox(height: 3),
            pw.Text('  - Mohamed SAAFI : +33 7 51 42 68 22', style: styleItalic),
            pw.Text('  - Zied HENTATI : +33 7 53 69 12 64', style: styleItalic),
            pw.SizedBox(height: 14),

            // À l'attention (droite)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('A l\'Attention de ' + locataire.nomComplet, style: styleNormal),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Fait a ' + bien.ville + ', le ' + _pdfDateF.format(paiement.date), style: styleNormal),
              ],
            ),
            pw.SizedBox(height: 14),

            // Adresse
            pw.Text('Adresse du Bien loué :',
                style: pw.TextStyle(font: fontBold, fontSize: 11, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 3),
            pw.Text('  - ' + adresse, style: styleNormal),
            if (bien.etage != null && bien.etage!.isNotEmpty)
              pw.Text('     Etage : ' + bien.etage!, style: styleNormal),
            if (bien.numero != null && bien.numero!.isNotEmpty)
              pw.Text('     Appartement N°' + bien.numero!, style: styleNormal),
            pw.SizedBox(height: 14),

            // Corps
            pw.Text(
              'Nous soussignes, Mohamed SAAFI et Zied HENTATI, proprietaires de l\'appartement designe ci-dessus, '
              'declarons avoir recu de ' + locataire.nomQuittance + ' '
              'la somme de ' + _pdfEuro.format(total) + ' (' + totalLettre + ' euros), '
              'au titre du paiement du loyer et des charges '
              'pour la periode de location du ' + _pdfDateF.format(debutMois) + ' au ' + _pdfDateF.format(finMois) + ', '
              'et lui en donnons quittance, sous reserve de tous nos droits.',
              style: styleNormal,
            ),
            pw.SizedBox(height: 18),

            // Détail
            pw.Text('Detail du reglement :',
                style: pw.TextStyle(font: fontBold, fontSize: 11, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 5),
            pw.Text('  - Loyer : ' + _pdfEuro.format(loyer), style: styleNormal),
            pw.Text('  - Provision sur charges : ' + _pdfEuro.format(charges), style: styleNormal),
            pw.SizedBox(height: 3),
            pw.Text('  - Total : ' + _pdfEuro.format(total), style: styleBold),
            pw.SizedBox(height: 6),
            pw.Text('Date de paiement : ' + _pdfDateF.format(paiement.date), style: styleNormal),
            pw.SizedBox(height: 14),

            // Mention légale
            pw.Text(
              'Cette quittance annule tous les recus qui auraient pu etre etablis precedemment en cas de paiement '
              'partiel du montant du present terme. Elle est a conserver pendant trois ans par le locataire '
              '(loi n 89-462 du 6 juillet 1989, art. 7-1).',
              style: styleLegal,
            ),
            pw.SizedBox(height: 30),

            // Signatures côte à côte
            pw.Text('Signatures :', style: styleBold),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(sig1, width: 120, height: 90, fit: pw.BoxFit.contain),
                    pw.Text('_________________________', style: styleNormal),
                    pw.SizedBox(height: 2),
                    pw.Text('Mohamed SAAFI', style: styleBold),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(sig2, width: 110, height: 90, fit: pw.BoxFit.contain),
                    pw.Text('_________________________', style: styleNormal),
                    pw.SizedBox(height: 2),
                    pw.Text('Zied HENTATI', style: styleBold),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    ));

    return pdf.save();
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _montantEnLettres(double montant) {
    final int m = montant.toInt();
    const unite = ['', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf',
      'dix', 'onze', 'douze', 'treize', 'quatorze', 'quinze', 'seize', 'dix-sept', 'dix-huit', 'dix-neuf'];
    const dizaine = ['', '', 'vingt', 'trente', 'quarante', 'cinquante',
      'soixante', 'soixante', 'quatre-vingt', 'quatre-vingt'];

    if (m == 0) return 'zero';
    if (m < 20) return unite[m];
    if (m < 100) {
      final d = m ~/ 10;
      final u = m % 10;
      if (d == 7 || d == 9) return dizaine[d] + '-' + unite[10 + u];
      if (u == 1 && d != 8) return dizaine[d] + '-et-un';
      if (u == 0 && d == 8) return 'quatre-vingts';
      return u == 0 ? dizaine[d] : dizaine[d] + '-' + unite[u];
    }
    if (m < 1000) {
      final c = m ~/ 100;
      final r = m % 100;
      final centStr = c == 1 ? 'cent' : unite[c] + ' cents';
      if (r == 0) return centStr;
      return (c == 1 ? 'cent' : unite[c] + ' cent') + ' ' + _montantEnLettres(r.toDouble());
    }
    if (m < 2000) {
      final r = m % 1000;
      return r == 0 ? 'mille' : 'mille ' + _montantEnLettres(r.toDouble());
    }
    final k = m ~/ 1000;
    final r = m % 1000;
    return r == 0
        ? _montantEnLettres(k.toDouble()) + ' mille'
        : _montantEnLettres(k.toDouble()) + ' mille ' + _montantEnLettres(r.toDouble());
  }
}