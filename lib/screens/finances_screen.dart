import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../models/models.dart';
import '../main.dart';

final _euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);
final _dateF = DateFormat('dd MMM yyyy', 'fr_FR');

// ═══════════════════════════════════════════════════════════════
// FINANCES
// ═══════════════════════════════════════════════════════════════

class FinancesScreen extends StatefulWidget {
  const FinancesScreen({super.key});
  @override
  State<FinancesScreen> createState() => _FinancesScreenState();
}

class _FinancesScreenState extends State<FinancesScreen> with SingleTickerProviderStateMixin {
  late final _tab = TabController(length: 2, vsync: this);

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
              Tab(text: 'Transactions'),
              Tab(text: 'Charges fixes'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TransactionsTab(data: data),
          _ChargesFixesTab(data: data),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, __) {
          if (_tab.index == 0) {
            return FloatingActionButton(
              heroTag: 'fab_tx',
              onPressed: () => showModalBottomSheet(
                context: context, isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => FormTransaction(data: data),
              ),
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          if (_tab.index == 1) {
            return FloatingActionButton(
              heroTag: 'fab_cf',
              onPressed: () => showModalBottomSheet(
                context: context, isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => FormChargeFixe(data: data),
              ),
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─── TRANSACTIONS ──────────────────────────────────────────────────────────

class _TransactionsTab extends StatefulWidget {
  final DataService data;
  const _TransactionsTab({required this.data});
  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  int _annee = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final all = widget.data.transactions.where((t) => t.date.year == _annee).toList();
    final recettes = all.where((t) => t.isRecette).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final depenses = all.where((t) => !t.isRecette).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final totalRec = recettes.fold<double>(0, (s, t) => s + t.montant);
    final totalDep = depenses.fold<double>(0, (s, t) => s + t.montant.abs());
    final net = totalRec - totalDep;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sélecteur année
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: () => setState(() => _annee--)),
          Text('$_annee', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () => setState(() => _annee++)),
        ]),
        const SizedBox(height: 8),

        // KPIs
        Row(children: [
          Expanded(child: _KpiCard('Revenus $_annee', _euro.format(totalRec), AppTheme.primary)),
          const SizedBox(width: 10),
          Expanded(child: _KpiCard('Dépenses $_annee', _euro.format(totalDep), AppTheme.danger)),
          const SizedBox(width: 10),
          Expanded(child: _KpiCard('Net', _euro.format(net), net >= 0 ? AppTheme.blue : AppTheme.danger)),
        ]),
        const SizedBox(height: 20),

        // Recettes
        _CollapsibleSection(
          label: '💰 Recettes',
          total: totalRec,
          color: AppTheme.primary,
          empty: 'Aucune recette en $_annee',
          children: recettes.map((tx) => _TxRow(tx: tx, data: widget.data)).toList(),
        ),
        const SizedBox(height: 12),

        // Dépenses
        _CollapsibleSection(
          label: '💸 Dépenses',
          total: totalDep,
          color: AppTheme.danger,
          empty: 'Aucune dépense en $_annee',
          children: depenses.map((tx) => _TxRow(tx: tx, data: widget.data)).toList(),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final double total;
  final Color color;
  const _SectionHeader(this.label, this.total, this.color);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Text(_euro.format(total), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
      ),
    ]);
  }
}

class _EmptySection extends StatelessWidget {
  final String msg;
  const _EmptySection(this.msg);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: Text(msg, style: TextStyle(color: Colors.grey[500], fontSize: 13))),
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  final String label;
  final double total;
  final Color color;
  final String empty;
  final List<Widget> children;
  const _CollapsibleSection({
    required this.label, required this.total, required this.color,
    required this.empty, required this.children,
  });
  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(widget.label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(_euro.format(widget.total),
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: widget.color)),
            ),
            const SizedBox(width: 8),
            Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey, size: 20),
          ]),
        ),
      ),
      if (_expanded) ...[
        const SizedBox(height: 4),
        if (widget.children.isEmpty)
          _EmptySection(widget.empty)
        else
          ...widget.children,
      ],
    ]);
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _KpiCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
      ]),
    );
  }
}

class _TxRow extends StatelessWidget {
  final Transaction tx;
  final DataService data;
  const _TxRow({required this.tx, required this.data});

  String _icon(TypeTransaction t) {
    switch (t) {
      case TypeTransaction.loyer: return '💰';
      case TypeTransaction.reparation: return '🔧';
      case TypeTransaction.assurance: return '📋';
      case TypeTransaction.taxe: return '🏛';
      case TypeTransaction.charge: return '⚡';
      default: return '💳';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bien = data.getBienById(tx.bienId);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: tx.isRecette ? const Color(0xFFE1F5EE) : const Color(0xFFFCEBEB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(_icon(tx.type), style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            Text('${bien?.nom ?? ''} · ${_dateF.format(tx.date)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              (tx.isRecette ? '+' : '-') + _euro.format(tx.montant.abs()),
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14,
                  color: tx.isRecette ? AppTheme.primary : AppTheme.danger),
            ),
            InkWell(
              onTap: () => data.supprimerTransaction(tx.id),
              child: const Icon(Icons.delete_outline, size: 14, color: Colors.grey),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─── BILAN ─────────────────────────────────────────────────────────────────

class _BilanTab extends StatefulWidget {
  final DataService data;
  const _BilanTab({required this.data});
  @override
  State<_BilanTab> createState() => _BilanTabState();
}

class _BilanTabState extends State<_BilanTab> {
  int _annee = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    double totalRevenus = 0, totalCharges = 0;
    final bilansBiens = <Map<String, dynamic>>[];

    for (final bien in data.biens) {
      final txs = data.getTransactionsDuBien(bien.id).where((t) => t.date.year == _annee).toList();
      final revenus = txs.where((t) => t.isRecette).fold<double>(0, (s, t) => s + t.montant);
      final charges = txs.where((t) => !t.isRecette).fold<double>(0, (s, t) => s + t.montant.abs());
      totalRevenus += revenus;
      totalCharges += charges;
      bilansBiens.add({'bien': bien, 'revenus': revenus, 'charges': charges, 'net': revenus - charges, 'txCount': txs.length});
    }

    final txsSansBien = data.transactions.where((t) => t.date.year == _annee && (t.bienId == null || t.bienId!.isEmpty)).toList();
    final revSansBien = txsSansBien.where((t) => t.isRecette).fold<double>(0, (s, t) => s + t.montant);
    final chgSansBien = txsSansBien.where((t) => !t.isRecette).fold<double>(0, (s, t) => s + t.montant.abs());
    totalRevenus += revSansBien;
    totalCharges += chgSansBien;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _annee--)),
          Text('$_annee', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _annee++)),
        ]),
        const SizedBox(height: 8),
        _BilanGlobalCard(revenus: totalRevenus, charges: totalCharges),
        const SizedBox(height: 20),
        const Text('Bilan par bien', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
        const SizedBox(height: 10),
        ...bilansBiens.map((b) => _BilanBienCard(
          bien: b['bien'] as Bien, revenus: b['revenus'] as double,
          charges: b['charges'] as double, net: b['net'] as double,
          txCount: b['txCount'] as int, annee: _annee, data: data,
        )),
        if (revSansBien > 0 || chgSansBien > 0) ...[
          const SizedBox(height: 8),
          _BilanSansBienCard(revenus: revSansBien, charges: chgSansBien),
        ],
      ],
    );
  }
}

class _BilanGlobalCard extends StatelessWidget {
  final double revenus, charges;
  const _BilanGlobalCard({required this.revenus, required this.charges});

  @override
  Widget build(BuildContext context) {
    final net = revenus - charges;
    final taux = revenus > 0 ? (charges / revenus * 100) : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bilan global', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 8),
        Text(_euro.format(net), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500)),
        Text('résultat net', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _BStat('Revenus', _euro.format(revenus), Colors.white)),
          Expanded(child: _BStat('Charges', _euro.format(charges), Colors.orangeAccent)),
          Expanded(child: _BStat('Taux charge', '${taux.toStringAsFixed(0)}%', Colors.white70)),
        ]),
      ]),
    );
  }
}

class _BStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
      Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
    ]);
  }
}

class _BilanBienCard extends StatefulWidget {
  final Bien bien;
  final double revenus, charges, net;
  final int txCount, annee;
  final DataService data;
  const _BilanBienCard({required this.bien, required this.revenus, required this.charges, required this.net, required this.txCount, required this.annee, required this.data});
  @override
  State<_BilanBienCard> createState() => _BilanBienCardState();
}

class _BilanBienCardState extends State<_BilanBienCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isPos = widget.net >= 0;
    final txs = widget.data.getTransactionsDuBien(widget.bien.id).where((t) => t.date.year == widget.annee).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: isPos ? AppTheme.primaryLight : const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.home_outlined, size: 20, color: isPos ? AppTheme.primary : AppTheme.danger),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.bien.nom, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                Text('${widget.txCount} transaction(s)', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_euro.format(widget.net), style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: isPos ? AppTheme.primary : AppTheme.danger)),
                Text('net', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ]),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                Expanded(child: _MiniKpi('Revenus', _euro.format(widget.revenus), AppTheme.primary)),
                const SizedBox(width: 8),
                Expanded(child: _MiniKpi('Charges', _euro.format(widget.charges), AppTheme.danger)),
                const SizedBox(width: 8),
                Expanded(child: _MiniKpi('Net', _euro.format(widget.net), isPos ? AppTheme.primary : AppTheme.danger)),
              ]),
              const SizedBox(height: 12),
              if (txs.isEmpty)
                Text('Aucune transaction', style: TextStyle(fontSize: 12, color: Colors.grey[500]))
              else
                ...txs.map((tx) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const SizedBox(width: 4),
                    Expanded(child: Text(tx.label, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                    Text(
                      (tx.isRecette ? '+' : '-') + _euro.format(tx.montant.abs()),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tx.isRecette ? AppTheme.primary : AppTheme.danger),
                    ),
                  ]),
                )),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniKpi(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color)),
      ]),
    );
  }
}

class _BilanSansBienCard extends StatelessWidget {
  final double revenus, charges;
  const _BilanSansBienCard({required this.revenus, required this.charges});
  @override
  Widget build(BuildContext context) {
    final net = revenus - charges;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.receipt_outlined, size: 20, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Charges générales', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const Text('Non rattachées à un bien', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ])),
          Text(_euro.format(net), style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14,
              color: net >= 0 ? AppTheme.primary : AppTheme.danger)),
        ]),
      ),
    );
  }
}

// ─── CHARGES FIXES ─────────────────────────────────────────────────────────

class _ChargesFixesTab extends StatefulWidget {
  final DataService data;
  const _ChargesFixesTab({required this.data});
  @override
  State<_ChargesFixesTab> createState() => _ChargesFixesTabState();
}

class _ChargesFixesTabState extends State<_ChargesFixesTab> {
  int _annee = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final all = widget.data.chargesFixes;

    // Filtrer par actif pendant l'année sélectionnée
    final credits = all.where((c) => c.type == TypeTransaction.charge && c.moisActifsDansAnnee(_annee) > 0).toList();
    final assurances = all.where((c) => c.type == TypeTransaction.assurance && c.moisActifsDansAnnee(_annee) > 0).toList();
    final taxes = all.where((c) => c.type == TypeTransaction.taxe && c.moisActifsDansAnnee(_annee) > 0).toList();
    final factures = all.where((c) => c.type == TypeTransaction.facture && c.moisActifsDansAnnee(_annee) > 0).toList();

    final totalAnnee = all.fold<double>(0, (s, c) => s + c.montantAnnee(_annee));

    if (all.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.repeat, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        Text('Aucune charge fixe', style: TextStyle(color: Colors.grey[600])),
        const SizedBox(height: 6),
        Text('Ajoutez vos crédits, assurances...', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ]));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sélecteur année
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: () => setState(() => _annee--)),
          Text('$_annee', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: () => setState(() => _annee++)),
        ]),
        const SizedBox(height: 8),

        // Résumé
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.danger.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total $_annee', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(_euro.format(totalAnnee),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.danger)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${credits.length + assurances.length + taxes.length + factures.length} actives',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text('sur ${all.length} total', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // Crédits
        _CfSection(label: '⚡ Crédits', items: credits, data: widget.data, annee: _annee),
        const SizedBox(height: 8),
        // Assurances
        _CfSection(label: '📋 Assurances', items: assurances, data: widget.data, annee: _annee),
        const SizedBox(height: 8),
        // Taxes
        _CfSection(label: '🏛 Taxes', items: taxes, data: widget.data, annee: _annee),
        const SizedBox(height: 8),
        // Factures
        _CfSection(label: '🧾 Factures', items: factures, data: widget.data, annee: _annee),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _CfSection extends StatefulWidget {
  final String label;
  final List<ChargeFixe> items;
  final DataService data;
  final int annee;
  const _CfSection({required this.label, required this.items, required this.data, required this.annee});
  @override
  State<_CfSection> createState() => _CfSectionState();
}

class _CfSectionState extends State<_CfSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final total = widget.items.fold<double>(0, (s, c) => s + c.montantAnnee(widget.annee));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(widget.label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            if (widget.items.isEmpty)
              Text('Aucune', style: TextStyle(fontSize: 12, color: Colors.grey[400]))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_euro.format(total),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.danger)),
              ),
            const SizedBox(width: 8),
            Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey, size: 20),
          ]),
        ),
      ),
      if (_expanded) ...[
        if (widget.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Aucun élément pour ' + widget.annee.toString(),
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          )
        else
          ...widget.items.map((cf) => _ChargeFixeRow(cf: cf, data: widget.data)),
      ],
    ]);
  }
}

class _ChargeFixeRow extends StatelessWidget {
  final ChargeFixe cf;
  final DataService data;
  const _ChargeFixeRow({required this.cf, required this.data});

  String _icon(TypeTransaction t) {
    switch (t) {
      case TypeTransaction.charge: return '⚡';
      case TypeTransaction.assurance: return '📋';
      case TypeTransaction.taxe: return '🏛';
      case TypeTransaction.facture: return '🧾';
      default: return '💳';
    }
  }

  String _datesCf(ChargeFixe cf) {
    final fmt = DateFormat('MM/yyyy', 'fr_FR');
    final debut = fmt.format(cf.dateDebut);
    if (cf.dateFin == null) return 'Depuis ' + debut + ' · sans fin';
    return debut + ' → ' + fmt.format(cf.dateFin!);
  }

  @override
  Widget build(BuildContext context) {
    final bien = data.getBienById(cf.bienId);
    String _nomBienOuImmeuble() {
      if (bien != null) return bien.nom;
      if (cf.bienId == null || cf.bienId!.isEmpty) return 'Global';
      try { return data.immeubles.firstWhere((i) => i.id == cf.bienId).nom; } catch (_) {}
      return cf.bienId!;
    }
    final nomCible = _nomBienOuImmeuble();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: cf.actif ? const Color(0xFFFCEBEB) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(_icon(cf.type), style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cf.label, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13,
                color: cf.actif ? Colors.black : Colors.grey)),
            Text(nomCible,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            Text(_datesCf(cf), style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('-' + _euro.format(cf.estAnnuelle ? cf.montant * 12 : cf.montant) + (cf.estAnnuelle ? '/an' : '/mois'),
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13,
                    color: cf.actif ? AppTheme.danger : Colors.grey)),
            const SizedBox(height: 4),

          ]),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
            onPressed: () => showModalBottomSheet(
              context: context, isScrollControlled: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => FormChargeFixe(data: data, charge: cf),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
            onPressed: () => data.supprimerChargeFixe(cf.id),
          ),
        ]),
      ),
    );
  }
}

class FormChargeFixe extends StatefulWidget {
  final DataService data;
  final ChargeFixe? charge;
  const FormChargeFixe({super.key, required this.data, this.charge});
  @override
  State<FormChargeFixe> createState() => _FormChargeFixeState();
}

class _FormChargeFixeState extends State<FormChargeFixe> {
  final _key = GlobalKey<FormState>();
  late final _label = TextEditingController();
  late final _montant = TextEditingController(text: () {
    if (widget.charge == null) return '';
    if (widget.charge!.estAnnuelle) {
      // Show annual amount (stored as monthly)
      final annuel = widget.charge!.montant * 12;
      return annuel % 1 == 0 ? annuel.toInt().toString() : annuel.toStringAsFixed(0);
    }
    return widget.charge!.montant.toString();
  }());
  late String _typeCharge = _initType();
  String? _bienId;
  late DateTime _dateDebut = widget.charge?.dateDebut ?? DateTime.now();
  late DateTime? _dateFin = widget.charge?.dateFin;
  int? _anneeSelectionnee;

  bool _estAnnuelle = false;
  String _sousTypeFacture = 'eau';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _typeCharge = _initType();
    _bienId = widget.charge?.bienId;
    _dateDebut = widget.charge?.dateDebut ?? DateTime.now();
    _dateFin = widget.charge?.dateFin;
    _anneeSelectionnee = widget.charge?.dateDebut.year;
    _label.text = widget.charge?.label ?? '';
    if (widget.charge != null) {
      _estAnnuelle = widget.charge!.estAnnuelle;
      _montant.text = widget.charge!.estAnnuelle
          ? (widget.charge!.montant * 12).toStringAsFixed(0)
          : widget.charge!.montant.toString();
    }
  }

  String _initType() {
    if (widget.charge == null) return 'credit';
    switch (widget.charge!.type) {
      case TypeTransaction.charge: return 'credit';
      case TypeTransaction.assurance: return 'assurance';
      case TypeTransaction.taxe: return 'taxe';
      case TypeTransaction.facture: return 'facture';
      default: return 'credit';
    }
  }

  TypeTransaction get _dartType {
    switch (_typeCharge) {
      case 'assurance': return TypeTransaction.assurance;
      case 'taxe': return TypeTransaction.taxe;
      case 'facture': return TypeTransaction.facture;
      default: return TypeTransaction.charge;
    }
  }

  List<DropdownMenuItem<String?>> get _biensItems {
    if (_typeCharge == 'taxe' || _typeCharge == 'facture') {
      final seen = <String?>{null};
      final items = <DropdownMenuItem<String?>>[
        const DropdownMenuItem(value: null, child: Text('Sélectionner')),
      ];
      for (final i in widget.data.immeubles) {
        if (seen.add(i.id)) items.add(DropdownMenuItem(value: i.id, child: Text('🏢 ' + i.nom)));
      }
      for (final b in widget.data.biensSansImmeuble) {
        if (seen.add(b.id)) items.add(DropdownMenuItem(value: b.id, child: Text('🏠 ' + b.nom)));
      }
      return items;
    }
    final seen = <String?>{null};
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem(value: null, child: Text('Global (tous les biens)')),
    ];
    for (final b in widget.data.biens) {
      if (seen.add(b.id)) items.add(DropdownMenuItem(value: b.id, child: Text(b.nom)));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => Form(
          key: _key,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const Text('Ajouter une charge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),

              // Type
              Row(children: [
                _TypeCBtn('Crédit', Icons.account_balance, _typeCharge == 'credit',
                    widget.charge != null && _typeCharge != 'credit' ? null :
                    () => setState(() { _typeCharge = 'credit'; _estAnnuelle = false; _anneeSelectionnee = null; })),
                const SizedBox(width: 8),
                _TypeCBtn('Assurance', Icons.shield_outlined, _typeCharge == 'assurance',
                    widget.charge != null && _typeCharge != 'assurance' ? null :
                    () => setState(() { _typeCharge = 'assurance'; _anneeSelectionnee = null; })),
                const SizedBox(width: 8),
                _TypeCBtn('Taxe', Icons.receipt_long_outlined, _typeCharge == 'taxe',
                    widget.charge != null && _typeCharge != 'taxe' ? null :
                    () => setState(() { _typeCharge = 'taxe'; _anneeSelectionnee = null; })),
                const SizedBox(width: 8),
                _TypeCBtn('Facture', Icons.bolt_outlined, _typeCharge == 'facture',
                    widget.charge != null && _typeCharge != 'facture' ? null :
                    () => setState(() { _typeCharge = 'facture'; _anneeSelectionnee = null; })),
              ]),
              const SizedBox(height: 20),

              // Libellé
              // Sous-type facture
              if (_typeCharge == 'facture') ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _SousTypeBtn('Eau', '💧', _sousTypeFacture == 'eau', () => setState(() { _sousTypeFacture = 'eau'; _label.text = 'Facture Eau'; })),
                    const SizedBox(width: 8),
                    _SousTypeBtn('Électricité', '⚡', _sousTypeFacture == 'electricite', () => setState(() { _sousTypeFacture = 'electricite'; _label.text = 'Facture Électricité'; })),
                    const SizedBox(width: 8),
                    _SousTypeBtn('Gaz', '🔥', _sousTypeFacture == 'gaz', () => setState(() { _sousTypeFacture = 'gaz'; _label.text = 'Facture Gaz'; })),
                    const SizedBox(width: 8),
                    _SousTypeBtn('Internet', '📶', _sousTypeFacture == 'internet', () => setState(() { _sousTypeFacture = 'internet'; _label.text = 'Facture Internet'; })),
                    const SizedBox(width: 8),
                    _SousTypeBtn('Autre', '📄', _sousTypeFacture == 'autre', () => setState(() { _sousTypeFacture = 'autre'; _label.text = ''; })),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _label,
                decoration: _deco(_typeCharge == 'credit' ? 'Nom du crédit (ex: Crédit BNP)' :
                    _typeCharge == 'assurance' ? 'Nom assurance (ex: Assurance PNO)' :
                    _typeCharge == 'facture' ? 'Libellé facture' :
                    'Nom taxe (ex: Taxe foncière)'),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 14),

              // Fréquence (assurance et taxe seulement)
              if (_typeCharge != 'credit') ...[
                Row(children: [
                  Expanded(child: _FreqCBtn('Mensuelle', !_estAnnuelle,
                      () => setState(() { _estAnnuelle = false; _anneeSelectionnee = null; }))),
                  const SizedBox(width: 8),
                  Expanded(child: _FreqCBtn('Annuelle', _estAnnuelle,
                      () => setState(() { _estAnnuelle = true; _anneeSelectionnee = null; }))),
                ]),
                const SizedBox(height: 14),
              ],

              // Montant
              TextFormField(
                controller: _montant,
                keyboardType: TextInputType.number,
                decoration: _deco(_estAnnuelle ? 'Montant annuel (€)' : 'Mensualité (€)'),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 14),

              // Bien concerné
              DropdownButtonFormField<String?>(
                value: _biensItems.any((item) => item.value == _bienId) ? _bienId : null,
                decoration: _deco('Bien concerné'),
                items: _biensItems,
                onChanged: (v) => setState(() => _bienId = v),
              ),
              const SizedBox(height: 14),

              // Période
              if ((_typeCharge == 'taxe' || _typeCharge == 'facture') && _estAnnuelle) ...[
                // Taxe annuelle : saisie de l'année uniquement
                if (_anneeSelectionnee == null)
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDialog<int>(
                        context: context,
                        builder: (_) => _AnneeDialog(initial: DateTime.now().year),
                      );
                      if (picked != null) setState(() {
                        _anneeSelectionnee = picked;
                        _dateDebut = DateTime(picked, 1, 1);
                        _dateFin = DateTime(picked, 12, 31);
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.orange.withOpacity(0.05),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.orange),
                        const SizedBox(width: 10),
                        Text("Sélectionner l'année fiscale *",
                            style: TextStyle(color: Colors.orange[700], fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  )
                else
                  _AnneePickerCF(
                    annee: _anneeSelectionnee!,
                    onPick: (annee) => setState(() {
                      _anneeSelectionnee = annee;
                      _dateDebut = DateTime(annee, 1, 1);
                      _dateFin = DateTime(annee, 12, 31);
                    }),
                  ),
              ] else ...[
                Row(children: [
                  Expanded(child: _DatePickerCF(
                    label: 'Début',
                    date: _dateDebut,
                    onPick: (d) { if (d != null) setState(() => _dateDebut = d); },
                  )),
                  const SizedBox(width: 12),
                  if (_typeCharge == 'credit' ||
                      (_typeCharge == 'assurance' && !_estAnnuelle) ||
                      (_typeCharge == 'facture' && !_estAnnuelle) ||
                      (_typeCharge == 'taxe' && !_estAnnuelle))
                    Expanded(child: _DatePickerCF(
                      label: 'Fin',
                      date: _dateFin,
                      onPick: (d) => setState(() => _dateFin = d),
                      nullable: true,
                    )),
                ]),
              ],
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if ((_typeCharge == 'taxe' || _typeCharge == 'facture') && _estAnnuelle && _anneeSelectionnee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une année fiscale')),
      );
      return;
    }
    setState(() => _saving = true);
    double montant = double.tryParse(_montant.text) ?? 0;
    if (_estAnnuelle) montant = montant / 12;
    if (widget.charge != null) {
      await widget.data.modifierChargeFixe(widget.charge!.copyWith(
        label: _label.text,
        montant: montant,
        type: _dartType,
        bienId: _bienId,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        estAnnuelle: _estAnnuelle,
      ));
    } else {
      await widget.data.ajouterChargeFixe(widget.data.nouvChargeFixe(
        label: _label.text,
        montant: montant,
        type: _dartType,
        bienId: _bienId,
        dateDebut: _dateDebut,
        dateFin: _dateFin,
        estAnnuelle: _estAnnuelle,
      ));
    }
    if (mounted) Navigator.pop(context);
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

class _TypeCBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  const _TypeCBtn(this.label, this.icon, this.active, this.onTap);
  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null && !active;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.35 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? AppTheme.primary : Colors.grey[300]!),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: active ? AppTheme.primary : Colors.grey[500]),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                color: active ? AppTheme.primary : Colors.grey[600])),
          ]),
        ),
      ),
    ));
  }
}

class _FreqCBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FreqCBtn(this.label, this.active, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppTheme.primary : Colors.grey[300]!),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: active ? AppTheme.primary : Colors.grey[600])),
      ),
    );
  }
}


// ─── SOUS TYPE FACTURE BTN ───────────────────────────────────────────────

class _SousTypeBtn extends StatelessWidget {
  final String label;
  final String emoji;
  final bool active;
  final VoidCallback onTap;
  const _SousTypeBtn(this.label, this.emoji, this.active, this.onTap);
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppTheme.primary : Colors.grey[300]!),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
              color: active ? AppTheme.primary : Colors.grey[600])),
        ]),
      ),
    );
  }
}

// ─── ANNEE DIALOG ────────────────────────────────────────────────────────

class _AnneeDialog extends StatefulWidget {
  final int initial;
  const _AnneeDialog({required this.initial});
  @override
  State<_AnneeDialog> createState() => _AnneeDialogState();
}

class _AnneeDialogState extends State<_AnneeDialog> {
  late int _annee = widget.initial;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Année fiscale'),
      content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _annee--)),
        Text(_annee.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _annee++)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _annee),
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}

// ─── ANNEE PICKER CHARGE FIXE ────────────────────────────────────────────

class _AnneePickerCF extends StatelessWidget {
  final int annee;
  final ValueChanged<int> onPick;
  const _AnneePickerCF({required this.annee, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: () => onPick(annee - 1),
      ),
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Année fiscale', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(annee.toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
        ]),
      )),
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: () => onPick(annee + 1),
      ),
    ]);
  }
}

// ─── DATE PICKER CHARGE FIXE ──────────────────────────────────────────────

class _DatePickerCF extends StatelessWidget {
  final String label;
  final DateTime? date;
  final ValueChanged<DateTime?> onPick;
  final bool nullable;
  const _DatePickerCF({required this.label, required this.date, required this.onPick, this.nullable = false});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MM/yyyy', 'fr_FR');
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        if (nullable && date != null) {
          showDialog(context: context, builder: (_) => AlertDialog(
            title: Text(label),
            actions: [
              TextButton(onPressed: () { Navigator.pop(context); onPick(null); }, child: const Text('Supprimer la date')),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final picked = await showDatePicker(context: context,
                    initialDate: date!, firstDate: DateTime(2000), lastDate: DateTime(2050));
                  if (picked != null) onPick(picked);
                },
                child: const Text('Choisir une date'),
              ),
            ],
          ));
        } else {
          final picked = await showDatePicker(context: context,
            initialDate: date ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2050));
          if (picked != null) onPick(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(date != null ? fmt.format(date!) : 'Sans fin',
                style: TextStyle(fontSize: 13, fontWeight: date != null ? FontWeight.w500 : FontWeight.normal,
                    color: date != null ? Colors.black : Colors.grey)),
          ])),
        ]),
      ),
    );
  }
}

// ─── FORMULAIRE TRANSACTION ────────────────────────────────────────────────

class FormTransaction extends StatefulWidget {
  final DataService data;
  const FormTransaction({super.key, required this.data});
  @override
  State<FormTransaction> createState() => _FormTransactionState();
}

class _FormTransactionState extends State<FormTransaction> {
  final _key = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _montant = TextEditingController();
  TypeTransaction _type = TypeTransaction.loyer;
  String? _bienId;
  String? _immeubleId;
  bool _isRecette = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        expand: false,
        builder: (_, ctrl) => Form(
          key: _key,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              const Text('Nouvelle transaction', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _TypeBtn(label: 'Recette', active: _isRecette, color: AppTheme.primary, onTap: () => setState(() => _isRecette = true))),
                const SizedBox(width: 10),
                Expanded(child: _TypeBtn(label: 'Dépense', active: !_isRecette, color: AppTheme.danger, onTap: () => setState(() => _isRecette = false))),
              ]),
              const SizedBox(height: 16),
              TextFormField(
                controller: _label,
                decoration: _deco('Libellé'),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _montant,
                keyboardType: TextInputType.number,
                decoration: _deco('Montant (€)'),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<TypeTransaction>(
                value: _type,
                decoration: _deco('Catégorie'),
                items: TypeTransaction.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                value: _bienId,
                decoration: _deco('Bien concerné (optionnel)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucun')),
                  ...widget.data.biens.map((b) => DropdownMenuItem(value: b.id, child: Text(b.nom))),
                ],
                onChanged: (v) => setState(() { _bienId = v; if (v != null) _immeubleId = null; }),
              ),
              const SizedBox(height: 14),
              if (_bienId == null) DropdownButtonFormField<String?>(
                value: _immeubleId,
                decoration: _deco("Charge commune d'immeuble (optionnel)"),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucun')),
                  ...widget.data.immeubles.map((i) => DropdownMenuItem(value: i.id, child: Text(i.nom))),
                ],
                onChanged: (v) => setState(() => _immeubleId = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecette ? AppTheme.primary : AppTheme.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;

    setState(() => _saving = true);
    final montant = (double.tryParse(_montant.text) ?? 0) * (_isRecette ? 1 : -1);
    await widget.data.ajouterTransaction(widget.data.nouvTransaction(
      label: _label.text, montant: montant, type: _type, bienId: _bienId, immeubleId: _immeubleId,
    ));
    if (mounted) Navigator.pop(context);
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _TypeBtn({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : Colors.grey[300]!),
        ),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w500, color: active ? color : Colors.grey[600])),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// MAINTENANCE
// ═══════════════════════════════════════════════════════════════

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});
  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  String _filtre = 'tous';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final tickets = data.tickets.where((t) {
      if (_filtre == 'ouverts') return t.statut == StatutTicket.ouvert || t.statut == StatutTicket.enCours;
      if (_filtre == 'urgents') return t.priorite == PrioriteTicket.urgent;
      if (_filtre == 'resolus') return t.statut == StatutTicket.resolu;
      return true;
    }).toList();

    return Scaffold(
      body: Column(children: [
        _FilterBar(filtre: _filtre, onChanged: (f) => setState(() => _filtre = f), data: data),
        Expanded(
          child: tickets.isEmpty
              ? const Center(child: Text('Aucun ticket'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tickets.length,
                  itemBuilder: (_, i) => _TicketCard(ticket: tickets[i], data: data),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_maintenance',
        onPressed: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => FormTicket(data: data),
        ),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String filtre;
  final ValueChanged<String> onChanged;
  final DataService data;
  const _FilterBar({required this.filtre, required this.onChanged, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.5)),
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _Chip(label: 'Tous', active: filtre == 'tous', onTap: () => onChanged('tous')),
          const SizedBox(width: 8),
          _Chip(label: 'Ouverts (${data.ticketsOuverts})', active: filtre == 'ouverts', onTap: () => onChanged('ouverts')),
          const SizedBox(width: 8),
          _Chip(label: 'Urgents (${data.ticketsUrgents})', active: filtre == 'urgents', onTap: () => onChanged('urgents')),
          const SizedBox(width: 8),
          _Chip(label: 'Résolus', active: filtre == 'resolus', onTap: () => onChanged('resolus')),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE1F5EE) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppTheme.primary : Colors.grey[300]!, width: 0.5),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
            color: active ? AppTheme.primaryDark : Colors.grey[600])),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  final DataService data;
  const _TicketCard({required this.ticket, required this.data});

  Color get _prioColor {
    switch (ticket.priorite) {
      case PrioriteTicket.urgent: return AppTheme.danger;
      case PrioriteTicket.moyenne: return AppTheme.warning;
      case PrioriteTicket.faible: return AppTheme.primary;
    }
  }

  String get _statutLabel {
    switch (ticket.statut) {
      case StatutTicket.ouvert: return 'Ouvert';
      case StatutTicket.enCours: return 'En cours';
      case StatutTicket.planifie: return 'Planifié';
      case StatutTicket.resolu: return 'Résolu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bien = data.getBienById(ticket.bienId);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: IntrinsicHeight(
        child: Row(children: [
          Container(width: 4, decoration: BoxDecoration(
            color: _prioColor,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
          )),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ticket.titre, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                const SizedBox(height: 3),
                Text('${bien?.nom ?? ticket.bienId} · ${_dateF.format(ticket.dateCreation)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                if (ticket.rapportePar != null) ...[
                  const SizedBox(height: 2),
                  Text('Signalé par ${ticket.rapportePar}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _prioColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(_statutLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _prioColor)),
                ),
                const SizedBox(height: 8),
                PopupMenuButton<StatutTicket>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                  itemBuilder: (_) => StatutTicket.values.map((s) =>
                      PopupMenuItem(value: s, child: Text(s.name))).toList(),
                  onSelected: (s) => data.modifierStatutTicket(ticket.id, s),
                ),
              ]),
            ]),
          )),
        ]),
      ),
    );
  }
}

class FormTicket extends StatefulWidget {
  final DataService data;
  const FormTicket({super.key, required this.data});
  @override
  State<FormTicket> createState() => _FormTicketState();
}

class _FormTicketState extends State<FormTicket> {
  final _key = GlobalKey<FormState>();
  final _titre = TextEditingController();
  final _desc = TextEditingController();
  final _rapporte = TextEditingController();
  String? _bienId;
  PrioriteTicket _priorite = PrioriteTicket.moyenne;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        expand: false,
        builder: (_, ctrl) => Form(
          key: _key,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              const Text('Nouveau ticket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              _TF(_titre, 'Titre du problème'),
              _TF(_desc, 'Description', maxLines: 3),
              _TF(_rapporte, 'Signalé par'),
              DropdownButtonFormField<String>(
                value: _bienId,
                decoration: _deco('Bien concerné'),
                items: widget.data.biens.map((b) => DropdownMenuItem(value: b.id, child: Text(b.nom))).toList(),
                validator: (v) => v == null ? 'Requis' : null,
                onChanged: (v) => setState(() => _bienId = v),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<PrioriteTicket>(
                value: _priorite,
                decoration: _deco('Priorité'),
                items: PrioriteTicket.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (v) => setState(() => _priorite = v!),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : const Text('Créer le ticket'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;

    setState(() => _saving = true);
    await widget.data.ajouterTicket(widget.data.nouvTicket(
      titre: _titre.text, description: _desc.text,
      bienId: _bienId!, priorite: _priorite,
      rapportePar: _rapporte.text.isNotEmpty ? _rapporte.text : null,
    ));
    if (mounted) Navigator.pop(context);
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

class _TF extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final int maxLines;
  const _TF(this.ctrl, this.label, {this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl, maxLines: maxLines,
        decoration: InputDecoration(labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
        validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
      ),
    );
  }
}
