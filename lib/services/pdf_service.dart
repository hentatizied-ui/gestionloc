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

    final sig1Bytes = await rootBundle.load('assets/images/signature_saafi.png');
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
            pw.Text('Adresse de l\'appartement loue :',
                style: pw.TextStyle(font: fontBold, fontSize: 11, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 3),
            pw.Text('  - ' + adresse, style: styleNormal),
            if (bien.etage != null && bien.etage!.isNotEmpty)
              pw.Text('  - Etage : ' + bien.etage!, style: styleNormal),
            if (bien.numero != null && bien.numero!.isNotEmpty)
              pw.Text('  - Appartement N : ' + bien.numero!, style: styleNormal),
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

  static Future<Uint8List> genererBilanCompta({
    required dynamic data,
    required int annee,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    final styleNormal = pw.TextStyle(font: font, fontSize: 11);
    final styleBold = pw.TextStyle(font: fontBold, fontSize: 11);
    final styleTitle = pw.TextStyle(font: fontBold, fontSize: 14);
    final styleSmall = pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700);

    // Calculs
    final txs = (data.transactions as List<Transaction>).where((t) => t.date.year == annee).toList();
    double loyers = 0, chargesRec = 0, reparations = 0, assurances = 0, taxes = 0, autres = 0;
    for (final t in txs) {
      if (t.montant > 0) {
        if (t.type == TypeTransaction.loyer) loyers += t.montant;
        else chargesRec += t.montant;
      } else {
        final m = t.montant.abs();
        switch (t.type) {
          case TypeTransaction.reparation: reparations += m; break;
          case TypeTransaction.assurance: assurances += m; break;
          case TypeTransaction.taxe: taxes += m; break;
          default: autres += m;
        }
      }
    }
    taxes += (data.biens as List<Bien>).fold<double>(0, (s, b) => s + b.taxeFonciere);
    final cfMontant = (data.chargesFixes as List<ChargeFixe>).where((cf) => cf.actif).fold<double>(0, (s, cf) => s + cf.montant * 12);
    final totalRev = loyers + chargesRec;
    final totalChg = reparations + assurances + taxes + autres + cfMontant;
    final net = totalRev - totalChg;

    final euro = NumberFormat.currency(locale: 'fr_FR', symbol: 'EUR', decimalDigits: 0);

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 40),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Center(child: pw.Text('BILAN COMPTABLE $annee', style: styleTitle)),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('Généré le ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: styleSmall)),
        pw.SizedBox(height: 24),

        pw.Text('COMPTE DE RESULTAT', style: styleBold),
        pw.SizedBox(height: 8),
        pw.Divider(),
        _bilanLigne('Loyers encaissés', loyers, true, styleNormal, styleBold, euro),
        _bilanLigne('Charges récupérées', chargesRec, true, styleNormal, styleBold, euro),
        pw.Divider(),
        _bilanLigne('TOTAL REVENUS', totalRev, true, styleBold, styleBold, euro),
        pw.SizedBox(height: 8),
        _bilanLigne('Charges fixes (crédit, assurance)', cfMontant, false, styleNormal, styleBold, euro),
        _bilanLigne('Entretien et réparations', reparations, false, styleNormal, styleBold, euro),
        _bilanLigne('Assurances', assurances, false, styleNormal, styleBold, euro),
        _bilanLigne('Taxes foncières', taxes, false, styleNormal, styleBold, euro),
        _bilanLigne('Autres charges', autres, false, styleNormal, styleBold, euro),
        pw.Divider(),
        _bilanLigne('TOTAL CHARGES', totalChg, false, styleBold, styleBold, euro),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(color: PdfColors.green50, border: pw.Border.all(color: PdfColors.green)),
          child: _bilanLigne('RESULTAT NET', net, net >= 0, styleBold, styleBold, euro),
        ),
        pw.SizedBox(height: 24),

        pw.Text('DETAIL PAR BIEN', style: styleBold),
        pw.SizedBox(height: 8),
        pw.Divider(),
        ...(data.biens as List<Bien>).map((b) {
          final bTxs = (data.transactions as List<Transaction>).where((t) => t.bienId == b.id && t.date.year == annee).toList();
          final bRev = bTxs.where((t) => t.montant > 0).fold<double>(0, (s, t) => s + t.montant);
          final bChg = bTxs.where((t) => t.montant < 0).fold<double>(0, (s, t) => s + t.montant.abs()) + b.taxeFonciere;
          final bNet = bRev - bChg;
          final prixAchat = b.prixAchat;
          final rdt = prixAchat > 0 ? (bNet / prixAchat * 100) : 0.0;
          final rdtStr = prixAchat > 0 ? ' | Rdt: ' + rdt.toStringAsFixed(1) + '%' : '';
          final details = 'Rev: ' + euro.format(bRev) + ' | Chg: ' + euro.format(bChg) + ' | Net: ' + euro.format(bNet) + rdtStr;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text(b.nom, style: styleNormal),
              pw.Text(details, style: styleSmall),
            ]),
          );
        }).toList(),
      ]),
    ));

    return pdf.save();
  }

  static pw.Widget _bilanLigne(String label, double value, bool isPos, pw.TextStyle style, pw.TextStyle bold, NumberFormat euro) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: style),
        pw.Text((isPos ? '+' : '-') + euro.format(value.abs()), style: bold),
      ]),
    );
  }

}
