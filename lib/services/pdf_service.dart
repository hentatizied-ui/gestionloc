import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/models.dart';

// ignore_for_file: avoid_positional_boolean_parameters

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

    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontItalic = pw.Font.helveticaOblique();

    final moisStr = _capitalize(_pdfDateMoisF.format(mois));
    final loyer = bien.loyerMensuel;
    final charges = bien.charges;
    final total = loyer + charges;
    final debutMois = DateTime(mois.year, mois.month, 1);
    final finMois = DateTime(mois.year, mois.month + 1, 0);
    final adresse = '${bien.adresse}, ${bien.ville} ${bien.codePostal}';
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
              'QUITTANCE DE LOYER DU MOIS DE ${moisStr.toUpperCase()}',
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
                pw.Text('A l\'Attention de ${locataire.nomComplet}', style: styleNormal),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Fait a ${bien.ville}, le ${_pdfDateF.format(paiement.date)}', style: styleNormal),
              ],
            ),
            pw.SizedBox(height: 14),

            // Adresse
            pw.Text('Adresse de l\'appartement loue :',
                style: pw.TextStyle(font: fontBold, fontSize: 11, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 3),
            pw.Text('  - $adresse', style: styleNormal),
            if (bien.etage != null && bien.etage!.isNotEmpty)
              pw.Text('  - Etage : ${bien.etage!}', style: styleNormal),
            if (bien.numero != null && bien.numero!.isNotEmpty)
              pw.Text('  - Appartement N : ${bien.numero!}', style: styleNormal),
            pw.SizedBox(height: 14),

            // Corps
            pw.Text(
              'Nous soussignes, Mohamed SAAFI et Zied HENTATI, proprietaires de l\'appartement designe ci-dessus, declarons avoir recu de ${locataire.nomQuittance} la somme de ${_pdfEuro.format(total)} ($totalLettre euros), au titre du paiement du loyer et des charges pour la periode de location du ${_pdfDateF.format(debutMois)} au ${_pdfDateF.format(finMois)}, et lui en donnons quittance, sous reserve de tous nos droits.',
              style: styleNormal,
            ),
            pw.SizedBox(height: 18),

            // Détail
            pw.Text('Detail du reglement :',
                style: pw.TextStyle(font: fontBold, fontSize: 11, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 5),
            pw.Text('  - Loyer : ${_pdfEuro.format(loyer)}', style: styleNormal),
            pw.Text('  - Provision sur charges : ${_pdfEuro.format(charges)}', style: styleNormal),
            pw.SizedBox(height: 3),
            pw.Text('  - Total : ${_pdfEuro.format(total)}', style: styleBold),
            pw.SizedBox(height: 6),
            pw.Text('Date de paiement : ${_pdfDateF.format(paiement.date)}', style: styleNormal),
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
      if (d == 7 || d == 9) return '${dizaine[d]}-${unite[10 + u]}';
      if (u == 1 && d != 8) return '${dizaine[d]}-et-un';
      if (u == 0 && d == 8) return 'quatre-vingts';
      return u == 0 ? dizaine[d] : '${dizaine[d]}-${unite[u]}';
    }
    if (m < 1000) {
      final c = m ~/ 100;
      final r = m % 100;
      final centStr = c == 1 ? 'cent' : '${unite[c]} cents';
      if (r == 0) return centStr;
      return '${c == 1 ? 'cent' : '${unite[c]} cent'} ${_montantEnLettres(r.toDouble())}';
    }
    if (m < 2000) {
      final r = m % 1000;
      return r == 0 ? 'mille' : 'mille ${_montantEnLettres(r.toDouble())}';
    }
    final k = m ~/ 1000;
    final r = m % 1000;
    return r == 0
        ? '${_montantEnLettres(k.toDouble())} mille'
        : '${_montantEnLettres(k.toDouble())} mille ${_montantEnLettres(r.toDouble())}';
  }

  static Future<Uint8List> genererBilanCompta({
    required dynamic data,
    required int annee,
  }) async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    final styleNormal = pw.TextStyle(font: font, fontSize: 11);
    final styleBold = pw.TextStyle(font: fontBold, fontSize: 11);
    final styleTitle = pw.TextStyle(font: fontBold, fontSize: 14);
    final styleSmall = pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700);

    // Calculs
    final txs = (data.transactions as List<Transaction>).where((t) => t.date.year == annee).toList();
    double loyers = 0, chargesRec = 0, reparations = 0, assurances = 0, taxes = 0, autres = 0;
    for (final t in txs) {
      if (t.montant > 0) {
        if (t.type == TypeTransaction.loyer) {
          loyers += t.montant;
        } else {
          chargesRec += t.montant;
        }
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
    final cfMontant = (data.chargesFixes as List<ChargeFixe>).fold<double>(0, (s, cf) => s + cf.montantAnnee(annee));
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
          final rdtStr = prixAchat > 0 ? ' | Rdt: ${rdt.toStringAsFixed(1)}%' : '';
          final details = 'Rev: ${euro.format(bRev)} | Chg: ${euro.format(bChg)} | Net: ${euro.format(bNet)}$rdtStr';
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 6),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text(b.nom, style: styleNormal),
              pw.Text(details, style: styleSmall),
            ]),
          );
        }),
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

  // ─────────────────────────────────────────────────────────────────────────
  // SIMULATION PDF
  // ─────────────────────────────────────────────────────────────────────────

  static Future<Uint8List> genererSimulation({
    required double prixAchat,
    required double honoraires,
    required double travaux,
    required double fraisBancaires,
    required double apport,
    required double fraisNotaire,
    required double coutAcquisition,
    required double montantEmprunt,
    required String typeBien,
    required int nbApparts,
    required List<double> loyers,
    required double assurancePno,
    required double copropriete,
    required double taxeFonciere,
    required int nbAnnees,
    required double taux,
    required String dateDebut,
    required int amortissement,
    required double echeance,
    required List<int> annees,
    required Map<String, List<double>> resultats,
  }) async {
    final pdf = pw.Document();
    final font     = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final euro     = NumberFormat.currency(locale: 'fr_FR', symbol: 'EUR', decimalDigits: 0);
    final dateStr  = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final sTitle  = pw.TextStyle(font: fontBold, fontSize: 15, color: PdfColors.blue900);
    final sHead   = pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.white);
    final sBold   = pw.TextStyle(font: fontBold, fontSize: 9);
    final sSmall  = pw.TextStyle(font: font,     fontSize: 8,  color: PdfColors.grey700);

    // ── Helpers ────────────────────────────────────────────────────────────
    pw.Widget param(String label, String val) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(children: [
        pw.SizedBox(width: 145, child: pw.Text(label, style: sSmall)),
        pw.Expanded(child: pw.Text(val, style: sBold)),
      ]),
    );

    pw.Widget sectionBox(String title, List<pw.Widget> children) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          color: PdfColors.blue800,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: pw.Text(title, style: sHead),
        ),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blue200),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
        ),
        pw.SizedBox(height: 10),
      ],
    );

    // ─── PAGE 1 : PARAMÈTRES ───────────────────────────────────────────────
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 30),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Center(child: pw.Text('SIMULATION D\'ACQUISITION', style: sTitle)),
        pw.SizedBox(height: 3),
        pw.Center(child: pw.Text('Généré le $dateStr', style: sSmall)),
        pw.SizedBox(height: 18),

        // Acquisition | Recettes (2 colonnes)
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: sectionBox('ACQUISITION', [
            param('Prix d\'achat',         euro.format(prixAchat)),
            param('Honoraires',            euro.format(honoraires)),
            param('Travaux',               euro.format(travaux)),
            param('Frais bancaires',       euro.format(fraisBancaires)),
            param('Apport',                euro.format(apport)),
            param('Frais de notaire (8%)', euro.format(fraisNotaire)),
          ])),
          pw.SizedBox(width: 16),
          pw.Expanded(child: sectionBox('RECETTES & CHARGES', [
            param('Type de bien', typeBien == 'independant'
                ? 'Indépendant'
                : 'Immeuble ($nbApparts apparts)'),
            ...List.generate(loyers.length, (i) =>
                param('Loyer appart ${i + 1}', euro.format(loyers[i]))),
            param('Total loyers/mois', euro.format(loyers.fold(0.0, (a, b) => a + b))),
            param('Assurance PNO',         euro.format(assurancePno)),
            param('Copropriété',           euro.format(copropriete)),
            param('Taxe foncière',         euro.format(taxeFonciere)),
          ])),
        ]),

        sectionBox('EMPRUNT', [
          pw.Row(children: [
            pw.Expanded(child: param('Durée',          '$nbAnnees ans')),
            pw.Expanded(child: param('Amortissement',  '$amortissement mois')),
          ]),
          pw.Row(children: [
            pw.Expanded(child: param('Taux',       '${taux.toStringAsFixed(2)} %')),
            pw.Expanded(child: param('Date début', dateDebut)),
          ]),
        ]),

        // Récapitulatif financier
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            border: pw.Border.all(color: PdfColors.blue800),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            _kpiCard('Coût acquisition',   euro.format(coutAcquisition), fontBold, font),
            _kpiCard('Montant emprunt',    euro.format(montantEmprunt),  fontBold, font),
            _kpiCard('Échéance mensuelle', euro.format(echeance),        fontBold, font),
            _kpiCard('Durée',             '$nbAnnees ans / $amortissement mois', fontBold, font),
          ]),
        ),
      ]),
    ));

    // ─── PAGES RÉSULTATS (landscape, 10 ans/page) ─────────────────────────
    const _metriques = [
      ('Intérêts par année',       'interets',             false),
      ('Capital emprunt',          'capitalEmprunt',       false),
      ('Echéance annuelle',        'echeance',             false),
      ('Capital remboursé',        'capitalRembourse',     false),
      ('Loyer avec augmentation',  'loyer',                false),
      ('Résultat exploitation',    'resultatExploitation', false),
      ('Frais bancaire',           'fraisBancaire',        false),
      ('Frais de notaire',         'fraisNotaire',         false),
      ('Assurance PNO',            'assurancePno',         false),
      ('Taxe Foncière',            'taxeFonciere',         false),
      ('Travaux',                  'travaux',              false),
      ('Résultat net',             'resultatNet',          false),
      ('Déficit Reportable',       'deficitReportable',    false),
      ('Résultat Fiscal',          'resultatFiscal',       false),
      ('Prél. Sociaux (17.2%)',    'prelevementsSociaux',  false),
      ('Impôts (TMI 30%)',         'impots',               false),
      ('CAF (Hors travaux)',       'cafHorsTravaux',       false),
      ('CAF Nette',                'cafNette',             false),
      ('Taux Renta Brut',          'tauxRentaBrut',        true),
      ('Taux Renta Net',           'tauxRentaNet',         true),
      ('Impact capacité emprunt',  'impactCapacite',       false),
    ];

    const _financialKeys = {'resultatExploitation', 'resultatNet', 'resultatFiscal', 'cafHorsTravaux', 'cafNette'};
    const _chargeKeys    = {'fraisBancaire', 'fraisNotaire', 'assurancePno', 'taxeFonciere', 'travaux'};
    const _tauxKeys      = {'tauxRentaBrut', 'tauxRentaNet'};
    const _sepAfter      = {3, 10}; // séparateur visuel après ces indices

    PdfColor cellColor(String key, double v) {
      if (_financialKeys.contains(key)) return v >= 0 ? PdfColors.green700 : PdfColors.red700;
      if (_chargeKeys.contains(key))    return PdfColors.grey700;
      if (_tauxKeys.contains(key))      return PdfColors.blue800;
      if (key == 'loyer')               return PdfColors.blue700;
      return PdfColors.black;
    }

    String fmtVal(bool isPercent, double v) =>
        isPercent ? '${(v * 100).toStringAsFixed(2)}%' : euro.format(v);

    const int yearsPerPage = 10;
    final int nbPages = max(1, ((annees.length - 1) ~/ yearsPerPage) + 1);
    const double labelW = 135.0;
    // Landscape A4 usable: 841.89 - 40 margins = ~802pt
    const double totalW = 802.0;

    for (int p = 0; p < nbPages; p++) {
      final int start  = p * yearsPerPage;
      final int end    = min(start + yearsPerPage, annees.length);
      final pageYears  = annees.sublist(start, end);
      final int nCols  = pageYears.length;
      final double colW = (totalW - labelW) / nCols;

      // ── cellules ──────────────────────────────────────────────────────
      pw.Widget hCell(String t, {bool isLabel = false}) => pw.Container(
        width: isLabel ? labelW : colW,
        height: 20,
        color: PdfColors.blue800,
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(horizontal: 2),
        child: pw.Text(t,
          style: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
          textAlign: pw.TextAlign.center,
        ),
      );

      pw.Widget dCell(String t, {PdfColor? color, bool isLabel = false, bool alt = false}) => pw.Container(
        width: isLabel ? labelW : colW,
        height: 16,
        color: alt ? PdfColors.grey200 : PdfColors.white,
        alignment: isLabel ? pw.Alignment.centerLeft : pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Text(t,
          style: pw.TextStyle(font: isLabel ? fontBold : font, fontSize: 7, color: color ?? PdfColors.black),
          textAlign: isLabel ? pw.TextAlign.left : pw.TextAlign.right,
        ),
      );

      final List<pw.Widget> rows = [
        // En-tête
        pw.Row(children: [
          hCell('Indicateur', isLabel: true),
          ...pageYears.map((y) => hCell(y.toString())),
        ]),
      ];

      for (int mi = 0; mi < _metriques.length; mi++) {
        final (label, key, isPercent) = _metriques[mi];
        final vals = resultats[key] ?? [];

        // Séparateur visuel
        if (_sepAfter.contains(mi)) {
          rows.add(pw.Container(height: 4, color: PdfColors.blue100));
        }

        final bool alt = mi % 2 == 0;
        rows.add(pw.Row(children: [
          dCell(label, isLabel: true, alt: alt),
          ...List.generate(nCols, (ci) {
            final gi = start + ci;
            final v  = gi < vals.length ? vals[gi] : 0.0;
            return dCell(fmtVal(isPercent, v), color: cellColor(key, v), alt: alt);
          }),
        ]));
      }

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(child: pw.Text(
              nbPages > 1
                ? 'RÉSULTATS PAR ANNÉE — Page ${p + 1} / $nbPages  (${pageYears.first} → ${pageYears.last})'
                : 'RÉSULTATS PAR ANNÉE  (${pageYears.first} → ${pageYears.last})',
              style: sTitle,
            )),
            pw.SizedBox(height: 8),
            pw.Column(children: rows),
            pw.Spacer(),
            pw.Center(child: pw.Text(
              'Simulation générée le $dateStr  ·  ${annees.length} années au total',
              style: sSmall,
            )),
          ],
        ),
      ));
    }

    return pdf.save();
  }

  static pw.Widget _kpiCard(String label, String value, pw.Font fontBold, pw.Font font) =>
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
      pw.Text(label, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
      pw.SizedBox(height: 2),
      pw.Text(value, style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.blue900)),
    ]);
}
