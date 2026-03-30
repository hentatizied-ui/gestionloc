import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:printing/printing.dart';
import '../services/data_service.dart';
import '../services/pdf_service.dart';
import '../models/models.dart';
import '../main.dart';

final _euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);
final _pct = NumberFormat('##0.0#', 'fr_FR');

// ═══════════════════════════════════════════════════════════════
// COMPTA SCREEN
// ═══════════════════════════════════════════════════════════════

class ComptaScreen extends StatefulWidget {
  const ComptaScreen({super.key});
  @override
  State<ComptaScreen> createState() => _ComptaScreenState();
}

class _ComptaScreenState extends State<ComptaScreen> with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 3, vsync: this);
  int _annee = DateTime.now().year;

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tab,
            labelColor: AppTheme.primary,
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: AppTheme.primary,
            tabs: const [
              Tab(text: 'Récapitulatif'),
              Tab(text: 'Par bien'),
              Tab(text: 'Graphiques'),
            ],
          ),
        ),
      ),
      body: Column(children: [
        Container(
          color: Colors.grey[50],
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: () => setState(() => _annee--)),
            Text('Exercice $_annee', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () => setState(() => _annee++)),
          ]),
        ),
        Expanded(child: TabBarView(
          controller: _tab,
          children: [
            _RecapTab(data: data, annee: _annee),
            _ParBienTab(data: data, annee: _annee),
            _GraphTab(data: data, annee: _annee),
          ],
        )),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_compta',
        onPressed: () => _exportPdf(context, data),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
        label: const Text('Export PDF', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _exportPdf(BuildContext context, DataService data) async {
    try {
      final bytes = await PdfService.genererBilanCompta(data: data, annee: _annee);
      await Printing.sharePdf(bytes: bytes, filename: 'Bilan_$_annee.pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// RECAPITULATIF
// ═══════════════════════════════════════════════════════════════

Map<String, double> _calcCompta(DataService data, int annee) {
  final txs = data.transactions.where((t) => t.date.year == annee).toList();
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
  taxes += data.biens.fold<double>(0, (s, b) => s + b.taxeFonciere);
  final cfMontant = data.chargesFixes.where((cf) => cf.actif).fold<double>(0, (s, cf) => s + cf.montantAnnee(annee));
  final totalRev = loyers + chargesRec;
  final totalChg = reparations + assurances + taxes + autres + cfMontant;
  return {
    'loyers': loyers, 'chargesRecuperees': chargesRec,
    'totalRevenus': totalRev, 'chargesFixes': cfMontant,
    'reparations': reparations, 'assurances': assurances,
    'taxes': taxes, 'autres': autres,
    'totalCharges': totalChg, 'resultatNet': totalRev - totalChg,
  };
}

class _RecapTab extends StatelessWidget {
  final DataService data;
  final int annee;
  const _RecapTab({required this.data, required this.annee});

  @override
  Widget build(BuildContext context) {
    final c = _calcCompta(data, annee);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle('Compte de résultat $annee'),
        const SizedBox(height: 8),
        _LigneCompta('Loyers encaissés', c['loyers']!, isPositif: true),
        _LigneCompta('Charges récupérées', c['chargesRecuperees']!, isPositif: true),
        const Divider(),
        _LigneCompta('Total revenus', c['totalRevenus']!, isPositif: true, isBold: true),
        const SizedBox(height: 8),
        _LigneCompta('Charges fixes (crédit, assurance)', c['chargesFixes']!, isPositif: false),
        _LigneCompta('Entretien & réparations', c['reparations']!, isPositif: false),
        _LigneCompta('Assurances', c['assurances']!, isPositif: false),
        _LigneCompta('Taxes foncières', c['taxes']!, isPositif: false),
        _LigneCompta('Autres charges', c['autres']!, isPositif: false),
        const Divider(),
        _LigneCompta('Total charges', c['totalCharges']!, isPositif: false, isBold: true),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c['resultatNet']! >= 0 ? AppTheme.primaryLight : const Color(0xFFFCEBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c['resultatNet']! >= 0 ? AppTheme.primary.withOpacity(0.3) : AppTheme.danger.withOpacity(0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('RÉSULTAT NET', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(_euro.format(c['resultatNet']!),
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16,
                    color: c['resultatNet']! >= 0 ? AppTheme.primary : AppTheme.danger)),
          ]),
        ),
        const SizedBox(height: 20),
        _SectionTitle('Indicateurs clés'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.0,
          children: [
            _KpiBox('Taux occupation', '${(data.tauxOccupation * 100).toStringAsFixed(0)}%', AppTheme.primary),
            _KpiBox('Charges / Revenus', c['totalRevenus']! > 0 ? '${_pct.format(c['totalCharges']! / c['totalRevenus']! * 100)}%' : '-', AppTheme.warning),
            _KpiBox('Revenus moy./mois', _euro.format(c['totalRevenus']! / 12), AppTheme.blue),
            _KpiBox('Charges moy./mois', _euro.format(c['totalCharges']! / 12), AppTheme.danger),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PAR BIEN
// ═══════════════════════════════════════════════════════════════

class _ParBienTab extends StatelessWidget {
  final DataService data;
  final int annee;
  const _ParBienTab({required this.data, required this.annee});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];

    for (final immeuble in data.immeubles) {
      final biens = data.getBiensDeLImmeuble(immeuble.id);
      if (biens.isEmpty) continue;
      final chargesCommunes = data.transactions.where((t) =>
        !t.isRecette && t.date.year == annee &&
        (t.bienId == null || t.bienId!.isEmpty) &&
        t.immeubleId == immeuble.id
      ).toList();
      // Charges fixes (taxe, factures eau/elec) rattachées à l'immeuble
      final cfCommunes = data.chargesFixes.where((cf) =>
        cf.bienId == immeuble.id
      ).toList();
      items.add(_ImmeubleSection(immeuble: immeuble, biens: biens,
          chargesCommunes: chargesCommunes, cfCommunes: cfCommunes, data: data, annee: annee));
    }

    final biensSansImm = data.biensSansImmeuble;
    if (biensSansImm.isNotEmpty) {
      items.add(_BienIndependantSection(biens: biensSansImm, data: data, annee: annee));
    }

    return ListView(padding: const EdgeInsets.all(16), children: items);
  }
}

class _BienIndependantSection extends StatefulWidget {
  final List<Bien> biens;
  final DataService data;
  final int annee;
  const _BienIndependantSection({required this.biens, required this.data, required this.annee});
  @override
  State<_BienIndependantSection> createState() => _BienIndependantSectionState();
}

class _BienIndependantSectionState extends State<_BienIndependantSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.biens.map((b) => _BienIndependantCard(bien: b, data: widget.data, annee: widget.annee)).toList(),
    );
  }
}

class _BienIndependantCard extends StatefulWidget {
  final Bien bien;
  final DataService data;
  final int annee;
  const _BienIndependantCard({required this.bien, required this.data, required this.annee});
  @override
  State<_BienIndependantCard> createState() => _BienIndependantCardState();
}

class _BienIndependantCardState extends State<_BienIndependantCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final txs = widget.data.getTransactionsDuBien(widget.bien.id).where((t) => t.date.year == widget.annee).toList();
    final loyer = txs.where((t) => t.isRecette && t.type == TypeTransaction.loyer).fold<double>(0, (s, t) => s + t.montant);
    final cfBien = widget.data.chargesFixes.where((cf) => cf.bienId == widget.bien.id && cf.actif).toList();
    final charges = txs.where((t) => !t.isRecette).fold<double>(0, (s, t) => s + t.montant.abs())
        + cfBien.fold<double>(0, (s, cf) => s + cf.montantAnnee(widget.annee))
        + widget.bien.taxeFonciere;
    final net = loyer - charges;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(children: [
            Row(children: [
              Icon(Icons.home_outlined, size: 16, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.bien.nom,
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey[800]))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: net >= 0 ? AppTheme.primary.withOpacity(0.15) : AppTheme.danger.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_euro.format(net),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: net >= 0 ? AppTheme.primary : AppTheme.danger)),
              ),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey[600], size: 18),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const SizedBox(width: 24),
              Expanded(child: Row(children: [
                Icon(Icons.arrow_upward, size: 12, color: AppTheme.primary.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text('Loyers ' + _euro.format(loyer),
                    style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              ])),
              Row(children: [
                Icon(Icons.arrow_downward, size: 12, color: AppTheme.danger.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text('Charges ' + _euro.format(charges),
                    style: TextStyle(fontSize: 11, color: Colors.grey[700])),
              ]),
            ]),
          ]),
        ),
      ),
      if (_expanded) ...[
        const SizedBox(height: 6),
        _BienComptaCard(bien: widget.bien, data: widget.data, annee: widget.annee),
      ],
      const SizedBox(height: 8),
    ]);
  }
}

class _ImmeubleSection extends StatefulWidget {
  final Immeuble immeuble;
  final List<Bien> biens;
  final List<Transaction> chargesCommunes;
  final List<ChargeFixe> cfCommunes;
  final DataService data;
  final int annee;
  const _ImmeubleSection({required this.immeuble, required this.biens,
      required this.chargesCommunes, required this.cfCommunes, required this.data, required this.annee});
  @override
  State<_ImmeubleSection> createState() => _ImmeubleSectionState();
}

class _ImmeubleSectionState extends State<_ImmeubleSection> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) {
    final totalTxCommunes = widget.chargesCommunes.fold<double>(0, (s, t) => s + t.montant.abs());
    final totalCfCommunes = widget.cfCommunes.fold<double>(0, (s, cf) => s + cf.montantAnnee(widget.annee));
    final totalCommun = totalTxCommunes + totalCfCommunes;

    // Calcul loyer total annuel et charges totales de l'immeuble
    double loyerTotal = 0;
    double chargesTotal = totalCommun;
    for (final b in widget.biens) {
      final txs = widget.data.getTransactionsDuBien(b.id).where((t) => t.date.year == widget.annee).toList();
      loyerTotal += txs.where((t) => t.isRecette && t.type == TypeTransaction.loyer).fold<double>(0, (s, t) => s + t.montant);
      chargesTotal += txs.where((t) => !t.isRecette).fold<double>(0, (s, t) => s + t.montant.abs());
      // Charges fixes du bien
      final cfBien = widget.data.chargesFixes.where((cf) => cf.bienId == b.id && cf.actif).toList();
      chargesTotal += cfBien.fold<double>(0, (s, cf) => s + cf.montantAnnee(widget.annee));
      chargesTotal += b.taxeFonciere;
    }
    final net = loyerTotal - chargesTotal;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3))),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.apartment, size: 16, color: AppTheme.primaryDark),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.immeuble.nom,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.primaryDark))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: net >= 0 ? AppTheme.primary.withOpacity(0.2) : AppTheme.danger.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_euro.format(net),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: net >= 0 ? AppTheme.primaryDark : AppTheme.danger)),
              ),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.primaryDark, size: 18),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const SizedBox(width: 24),
              Expanded(child: Row(children: [
                Icon(Icons.arrow_upward, size: 12, color: AppTheme.primary.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text('Loyers ' + _euro.format(loyerTotal),
                    style: TextStyle(fontSize: 11, color: AppTheme.primaryDark.withOpacity(0.8))),
              ])),
              Row(children: [
                Icon(Icons.arrow_downward, size: 12, color: AppTheme.danger.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text('Charges ' + _euro.format(chargesTotal),
                    style: TextStyle(fontSize: 11, color: AppTheme.danger.withOpacity(0.8))),
              ]),
            ]),
          ]),
        ),
      ),
      if (_expanded) ...[
        const SizedBox(height: 8),
        ...widget.biens.map((b) => _BienComptaCard(bien: b, data: widget.data, annee: widget.annee)),
        _ChargesCommunesCard(
          charges: widget.chargesCommunes,
          cfCommunes: widget.cfCommunes,
          total: totalCommun,
          annee: widget.annee,
        ),
      ],
      const SizedBox(height: 16),
    ]);
  }
}

class _ChargesCommunesCard extends StatefulWidget {
  final List<Transaction> charges;
  final List<ChargeFixe> cfCommunes;
  final double total;
  final int annee;
  const _ChargesCommunesCard({required this.charges, required this.cfCommunes, required this.total, required this.annee});
  @override
  State<_ChargesCommunesCard> createState() => _ChargesCommunesCardState();
}

class _ChargesCommunesCardState extends State<_ChargesCommunesCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFFFFF8E1),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.share_outlined, size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              const Expanded(child: Text('Charges communes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
              Text(_euro.format(widget.total),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.danger)),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.grey, size: 18),
            ]),
            if (_expanded) ...[
              const Divider(height: 16),
              if (widget.cfCommunes.isEmpty && widget.charges.isEmpty)
                Text('Ajoutez des charges communes via Finances → Charges fixes (Taxe) ou Transactions.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]))
              else ...[
                ...widget.cfCommunes.map((cf) => _LigneCommuneRow(
                    cf.label, cf.montantAnnee(widget.annee))),
                ...widget.charges.map((tx) => _LigneCommuneRow(tx.label, tx.montant.abs())),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}

class _BienComptaCard extends StatefulWidget {
  final Bien bien;
  final DataService data;
  final int annee;
  const _BienComptaCard({required this.bien, required this.data, required this.annee});
  @override
  State<_BienComptaCard> createState() => _BienComptaCardState();
}

class _BienComptaCardState extends State<_BienComptaCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final txs = widget.data.getTransactionsDuBien(widget.bien.id).where((t) => t.date.year == widget.annee).toList();
    final loyerEncaisse = txs.where((t) => t.isRecette && t.type == TypeTransaction.loyer).fold<double>(0, (s, t) => s + t.montant);
    final chargesRec = txs.where((t) => t.isRecette && t.type != TypeTransaction.loyer).fold<double>(0, (s, t) => s + t.montant);
    final reparations = txs.where((t) => !t.isRecette && t.type == TypeTransaction.reparation).fold<double>(0, (s, t) => s + t.montant.abs());
    final loyerAnnuel = widget.bien.loyerMensuel * 12;
    final cfBien = widget.data.chargesFixes.where((cf) => cf.bienId == widget.bien.id && cf.actif).toList();
    final credits = cfBien.where((cf) => cf.type == TypeTransaction.charge).fold<double>(0, (s, cf) => s + cf.montantAnnee(widget.annee));
    final assurancesCf = cfBien.where((cf) => cf.type == TypeTransaction.assurance).fold<double>(0, (s, cf) => s + cf.montantAnnee(widget.annee));
    final totalCharges = reparations + credits + assurancesCf;
    final net = loyerEncaisse + chargesRec - totalCharges;
    final rendBrut = widget.bien.prixAchat > 0 ? (loyerAnnuel / widget.bien.prixAchat * 100) : 0.0;
    final rendNet = widget.bien.prixAchat > 0 ? (net / widget.bien.prixAchat * 100) : 0.0;
    final autres = txs.where((t) => !t.isRecette && t.type != TypeTransaction.reparation && t.type != TypeTransaction.assurance && t.type != TypeTransaction.taxe).fold<double>(0, (s, t) => s + t.montant.abs());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(widget.bien.nom, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: net >= 0 ? AppTheme.primaryLight : const Color(0xFFFCEBEB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_euro.format(net), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                    color: net >= 0 ? AppTheme.primary : AppTheme.danger)),
              ),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey, size: 18),
            ]),
            if (_expanded) ...[
              const SizedBox(height: 8),
              _LigneSection('REVENUS'),
              _LigneD('Loyer encaissé', loyerEncaisse, true),
              if (chargesRec > 0) _LigneD('Charges récupérées', chargesRec, true),
              const SizedBox(height: 6),
              _LigneSection('CHARGES'),
              _LigneD('Crédit(s)', credits, false),
              _LigneD('Assurance(s)', assurancesCf, false),
              _LigneD('Entretien / réparations', reparations, false),
              _LigneD('Autre(s)', autres, false),
              if (widget.bien.prixAchat > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Expanded(child: _MiniStat2('Prix achat', _euro.format(widget.bien.prixAchat), Colors.grey[600]!)),
                    Expanded(child: _MiniStat2('Rdt brut', _pct.format(rendBrut) + '%', AppTheme.blue)),
                    Expanded(child: _MiniStat2('Rdt net', _pct.format(rendNet) + '%',
                        rendNet > 0 ? AppTheme.primary : AppTheme.danger)),
                  ]),
                ),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}

class _LigneCommuneRow extends StatelessWidget {
  final String label;
  final double value;
  const _LigneCommuneRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
        Text(value == 0 ? '0 €' : '-' + _euro.format(value),
            style: TextStyle(fontSize: 11,
                color: value == 0 ? Colors.grey[400] : AppTheme.danger)),
      ]),
    );
  }
}

class _LigneD extends StatelessWidget {
  final String label;
  final double value;
  final bool isRevenu;
  final bool isTheo;
  const _LigneD(this.label, this.value, this.isRevenu, {this.isTheo = false});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12,
            color: isTheo ? Colors.grey[400] : Colors.grey[700],
            fontStyle: isTheo ? FontStyle.italic : FontStyle.normal)),
        Text((isRevenu ? '+' : '-') + _euro.format(value),
            style: TextStyle(fontSize: 12,
                fontWeight: isTheo ? FontWeight.normal : FontWeight.w500,
                color: isTheo ? Colors.grey[400] : (isRevenu ? AppTheme.primary : AppTheme.danger))),
      ]),
    );
  }
}

class _LigneSection extends StatelessWidget {
  final String label;
  const _LigneSection(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: Colors.grey[500], letterSpacing: 0.5)),
    );
  }
}

class _MiniStat2 extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat2(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// GRAPHIQUES
// ═══════════════════════════════════════════════════════════════

class _GraphTab extends StatelessWidget {
  final DataService data;
  final int annee;
  const _GraphTab({required this.data, required this.annee});

  @override
  Widget build(BuildContext context) {
    final moisLabels = ['J','F','M','A','M','J','J','A','S','O','N','D'];
    final revenus = List<double>.filled(12, 0);
    final charges = List<double>.filled(12, 0);
    for (final t in data.transactions.where((t) => t.date.year == annee)) {
      if (t.isRecette) revenus[t.date.month - 1] += t.montant;
      else charges[t.date.month - 1] += t.montant.abs();
    }
    final maxVal = [...revenus, ...charges].fold<double>(0, (a, b) => a > b ? a : b);
    final compta = _calcCompta(data, annee);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Revenus vs Charges mensuels', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            const SizedBox(height: 12),
            Row(children: [
              _Dot(AppTheme.primary, 'Revenus'),
              const SizedBox(width: 16),
              _Dot(AppTheme.danger, 'Charges'),
            ]),
            const SizedBox(height: 12),
            SizedBox(height: 160, child: BarChart(BarChartData(
              maxY: maxVal == 0 ? 1000 : maxVal * 1.2,
              barGroups: List.generate(12, (i) => BarChartGroupData(
                x: i, barsSpace: 2,
                barRods: [
                  BarChartRodData(toY: revenus[i], color: AppTheme.primary, width: 10,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                  BarChartRodData(toY: charges[i], color: AppTheme.danger.withOpacity(0.7), width: 10,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3))),
                ],
              )),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                    getTitlesWidget: (v, _) => Text(moisLabels[v.toInt()],
                        style: const TextStyle(fontSize: 10, color: Colors.grey)))),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            ))),
          ]),
        )),
        const SizedBox(height: 16),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Répartition des charges', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            const SizedBox(height: 16),
            ...{
              'Charges fixes': compta['chargesFixes']!,
              'Réparations': compta['reparations']!,
              'Assurances': compta['assurances']!,
              'Taxes': compta['taxes']!,
              'Autres': compta['autres']!,
            }.entries.where((e) => e.value > 0).map((e) {
              final total = compta['totalCharges']!;
              final pct = total > 0 ? e.value / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(e.key, style: const TextStyle(fontSize: 12)),
                    Text(_euro.format(e.value) + ' (' + _pct.format(pct * 100) + '%)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: pct, minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primary))),
                ]),
              );
            }),
          ]),
        )),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot(this.color, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGETS COMMUNS
// ═══════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.primaryDark));
  }
}

class _LigneCompta extends StatelessWidget {
  final String label;
  final double value;
  final bool isPositif;
  final bool isBold;
  const _LigneCompta(this.label, this.value, {required this.isPositif, this.isBold = false});
  @override
  Widget build(BuildContext context) {
    final color = isPositif ? AppTheme.primary : AppTheme.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal)),
        Text((isPositif ? '+' : '-') + _euro.format(value.abs()),
            style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.w600 : FontWeight.w500, color: color)),
      ]),
    );
  }
}

class _KpiBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _KpiBox(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
