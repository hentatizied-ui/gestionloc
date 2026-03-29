import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/data_service.dart';
import '../models/models.dart';
import '../main.dart';

final _euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);
final _dateF = DateFormat('dd/MM/yyyy', 'fr_FR');

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();

    if (data.loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: data.loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _KpiGrid(data: data),
          const SizedBox(height: 16),
          _AlertesBails(data: data),
          const SizedBox(height: 16),
          _LoyersMoisCard(data: data),
          const SizedBox(height: 16),
          _RevenusChart(data: data),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _OccupationCard(data: data)),
            const SizedBox(width: 12),
            Expanded(child: _AlertesCard(data: data)),
          ]),
        ],
      ),
    );
  }
}

// ─── KPI GRID ──────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final DataService data;
  const _KpiGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    // Calcul loyers à encaisser ce mois
    final now = DateTime.now();
    final locatairesActifs = data.locataires.where((l) => l.bienId != null && l.bienId!.isNotEmpty).toList();
    final nonPayesMois = locatairesActifs.where((l) {
      final loyers = data.getLoyers(l.bienId!);
      return !loyers.any((t) => t.date.year == now.year && t.date.month == now.month);
    }).toList();
    final montantAEncaisser = nonPayesMois.fold<double>(0, (s, l) {
      final bien = data.getBienById(l.bienId);
      return s + (bien?.loyerMensuel ?? 0) + (bien?.charges ?? 0);
    });

    // Bails expirants < 3 mois
    final limite = DateTime(now.year, now.month + 3, now.day);
    final bailsExpirants = data.locataires.where((l) => l.finBail.isBefore(limite) && l.finBail.isAfter(now)).length;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _KpiCard(
          icon: Icons.euro,
          iconColor: AppTheme.primary,
          label: 'Revenus ce mois',
          value: _euro.format(data.revenusMoisCourant),
          sub: '${_euro.format(data.revenusAnnee)} cette année',
          subColor: AppTheme.primary,
        ),
        _KpiCard(
          icon: Icons.home_work_outlined,
          iconColor: const Color(0xFF378ADD),
          label: 'Occupation',
          value: '${data.biensLoues} / ${data.biens.length}',
          sub: '${(data.tauxOccupation * 100).toStringAsFixed(0)}% du parc',
          subColor: Colors.grey[600]!,
        ),
        _KpiCard(
          icon: Icons.pending_actions,
          iconColor: AppTheme.warning,
          label: 'À encaisser',
          value: _euro.format(montantAEncaisser),
          sub: '${nonPayesMois.length} loyer(s) en attente',
          subColor: nonPayesMois.isNotEmpty ? AppTheme.warning : Colors.grey[600]!,
        ),
        _KpiCard(
          icon: Icons.event_busy,
          iconColor: bailsExpirants > 0 ? AppTheme.danger : Colors.grey[600]!,
          label: 'Bails expirants',
          value: '$bailsExpirants bail(s)',
          sub: bailsExpirants > 0 ? 'Dans moins de 3 mois' : 'Aucun à venir',
          subColor: bailsExpirants > 0 ? AppTheme.danger : Colors.grey[600]!,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final Color subColor, iconColor;
  final IconData icon;
  const _KpiCard({required this.label, required this.value, required this.sub, required this.subColor, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 10, color: subColor), overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ─── ALERTES BAILS ─────────────────────────────────────────────────────────

class _AlertesBails extends StatelessWidget {
  final DataService data;
  const _AlertesBails({required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final limite3 = DateTime(now.year, now.month + 3, now.day);
    final limite1 = DateTime(now.year, now.month + 1, now.day);

    final expirants = data.locataires
        .where((l) => l.finBail.isAfter(now) && l.finBail.isBefore(limite3))
        .toList()
      ..sort((a, b) => a.finBail.compareTo(b.finBail));

    if (expirants.isEmpty) return const SizedBox.shrink();

    return Card(
      color: const Color(0xFFFFF3CD),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.event_busy, size: 16, color: Color(0xFF856404)),
            SizedBox(width: 6),
            Text('Bails expirants', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Color(0xFF856404))),
          ]),
          const SizedBox(height: 10),
          ...expirants.map((l) {
            final bien = data.getBienById(l.bienId);
            final jours = l.finBail.difference(now).inDays;
            final critique = l.finBail.isBefore(limite1);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Container(width: 4, height: 36,
                  decoration: BoxDecoration(
                    color: critique ? AppTheme.danger : AppTheme.warning,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.nomComplet, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  Text(
                    '${bien?.nom ?? "Bien inconnu"} — expire le ${_dateF.format(l.finBail)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: critique ? AppTheme.danger.withOpacity(0.15) : AppTheme.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'J-$jours',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: critique ? AppTheme.danger : AppTheme.warning),
                  ),
                ),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

// ─── LOYERS CE MOIS ────────────────────────────────────────────────────────

class _LoyersMoisCard extends StatelessWidget {
  final DataService data;
  const _LoyersMoisCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final moisStr = DateFormat('MMMM yyyy', 'fr_FR').format(now);

    final locatairesActifs = data.locataires
        .where((l) => l.bienId != null && l.bienId!.isNotEmpty)
        .toList();

    if (locatairesActifs.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Loyers ${_capitalize(moisStr)}',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            Text(
              '${locatairesActifs.where((l) { final loyers = data.getLoyers(l.bienId!); return loyers.any((t) => t.date.year == now.year && t.date.month == now.month); }).length}/${locatairesActifs.length} encaissés',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ]),
          const SizedBox(height: 12),
          ...locatairesActifs.map((l) {
            final bien = data.getBienById(l.bienId);
            final loyers = data.getLoyers(l.bienId!);
            final paye = loyers.any((t) => t.date.year == now.year && t.date.month == now.month);
            final montant = (bien?.loyerMensuel ?? 0) + (bien?.charges ?? 0);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: paye ? AppTheme.primaryLight : const Color(0xFFFCEBEB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => showModalBottomSheet(
                  context: context, isScrollControlled: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => _LocataireDetailDash(loc: l, data: data),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    Icon(paye ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16, color: paye ? AppTheme.primary : Colors.grey[400]),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.nomComplet, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text(bien?.nom ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ])),
                    Text(
                      _euro.format(montant),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                          color: paye ? AppTheme.primary : AppTheme.danger),
                    ),
                    const SizedBox(width: 8),
                    // Bouton valider rapide si non payé
                    if (!paye)
                      _ValiderBtn(loc: l, bien: bien, mois: now, data: data)
                    else
                      const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                  ]),
                ),
              ),
            );
          }),
        ]),
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── VALIDER BTN ───────────────────────────────────────────────────────────

class _ValiderBtn extends StatefulWidget {
  final Locataire loc;
  final Bien? bien;
  final DateTime mois;
  final DataService data;
  const _ValiderBtn({required this.loc, required this.bien, required this.mois, required this.data});

  @override
  State<_ValiderBtn> createState() => _ValiderBtnState();
}

class _ValiderBtnState extends State<_ValiderBtn> {
  bool _loading = false;

  Future<void> _valider() async {
    setState(() => _loading = true);
    final montant = (widget.bien?.loyerMensuel ?? 0) + (widget.bien?.charges ?? 0);
    final tx = widget.data.nouvTransaction(
      label: 'Loyer ${DateFormat('MMMM yyyy', 'fr_FR').format(widget.mois)} - ${widget.loc.nomComplet}',
      montant: montant,
      type: TypeTransaction.loyer,
      date: DateTime(widget.mois.year, widget.mois.month, 1),
      bienId: widget.loc.bienId,
      locataireId: widget.loc.id,
    );
    await widget.data.ajouterTransaction(tx);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : _valider,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _loading
            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Valider', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ─── DETAIL LOCATAIRE (depuis dashboard) ───────────────────────────────────
// Réutilise le BottomSheet de locataires_screen via FormLocataire

class _LocataireDetailDash extends StatelessWidget {
  final Locataire loc;
  final DataService data;
  const _LocataireDetailDash({required this.loc, required this.data});

  @override
  Widget build(BuildContext context) {
    final bien = data.getBienById(loc.bienId);
    final now = DateTime.now();
    final moisCourant = DateTime(now.year, now.month, 1);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            CircleAvatar(radius: 22, backgroundColor: const Color(0xFFB5D4F4),
                child: Text(loc.initiales, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF042C53)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(loc.nomComplet, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              Text(bien?.nom ?? 'Aucun bien', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
          ]),
          const Divider(height: 24),
          // Mois courant
          const Text('Paiement ce mois', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 10),
          _MoisPaiementRow(loc: loc, bien: bien, mois: moisCourant, data: data),
          const SizedBox(height: 16),
          // Voir fiche complète
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Voir la fiche complète'),
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context, isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => _LocataireFullDetail(loc: loc, data: data),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoisPaiementRow extends StatefulWidget {
  final Locataire loc;
  final Bien? bien;
  final DateTime mois;
  final DataService data;
  const _MoisPaiementRow({required this.loc, required this.bien, required this.mois, required this.data});

  @override
  State<_MoisPaiementRow> createState() => _MoisPaiementRowState();
}

class _MoisPaiementRowState extends State<_MoisPaiementRow> {
  bool _saving = false;

  Transaction? get _paiement {
    if (widget.loc.bienId == null) return null;
    return widget.data.getLoyers(widget.loc.bienId!).cast<Transaction?>().firstWhere(
      (t) => t != null && t.date.year == widget.mois.year && t.date.month == widget.mois.month,
      orElse: () => null,
    );
  }

  Future<void> _valider() async {
    setState(() => _saving = true);
    final montant = (widget.bien?.loyerMensuel ?? 0) + (widget.bien?.charges ?? 0);
    final moisStr = DateFormat('MMMM yyyy', 'fr_FR').format(widget.mois);
    final tx = widget.data.nouvTransaction(
      label: 'Loyer $moisStr - ${widget.loc.nomComplet}',
      montant: montant,
      type: TypeTransaction.loyer,
      date: DateTime(widget.mois.year, widget.mois.month, 1),
      bienId: widget.loc.bienId,
      locataireId: widget.loc.id,
    );
    await widget.data.ajouterTransaction(tx);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _annuler(String txId) async {
    await widget.data.supprimerTransaction(txId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final paiement = _paiement;
    final estPaye = paiement != null;
    final montant = (widget.bien?.loyerMensuel ?? 0) + (widget.bien?.charges ?? 0);
    final moisStr = DateFormat('MMMM yyyy', 'fr_FR').format(widget.mois);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: estPaye ? AppTheme.primaryLight : const Color(0xFFFCEBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: estPaye ? AppTheme.primary.withOpacity(0.2) : AppTheme.danger.withOpacity(0.2),
        ),
      ),
      child: Row(children: [
        Icon(estPaye ? Icons.check_circle : Icons.cancel,
            size: 20, color: estPaye ? AppTheme.primary : AppTheme.danger),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(moisStr[0].toUpperCase() + moisStr.substring(1),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(_euro.format(montant), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ])),
        if (!estPaye)
          TextButton(
            onPressed: _saving ? null : _valider,
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _saving
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Valider', style: TextStyle(fontSize: 13)),
          )
        else
          IconButton(
            icon: const Icon(Icons.undo, size: 18, color: Colors.grey),
            tooltip: 'Annuler',
            onPressed: () => _annuler(paiement.id),
          ),
      ]),
    );
  }
}

class _LocataireFullDetail extends StatelessWidget {
  final Locataire loc;
  final DataService data;
  const _LocataireFullDetail({required this.loc, required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        Expanded(child: DefaultTabController(
          length: 1,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(loc.nomComplet, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(data.getBienById(loc.bienId)?.nom ?? '', style: TextStyle(color: Colors.grey[600])),
                const Divider(height: 24),
                const Text('Historique des paiements', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Expanded(child: _PaiementsListDash(loc: loc, data: data)),
              ]),
            ),
          ),
        )),
      ]),
    );
  }
}

class _PaiementsListDash extends StatefulWidget {
  final Locataire loc;
  final DataService data;
  const _PaiementsListDash({required this.loc, required this.data});

  @override
  State<_PaiementsListDash> createState() => _PaiementsListDashState();
}

class _PaiementsListDashState extends State<_PaiementsListDash> {
  List<DateTime> _getMois() {
    final now = DateTime.now();
    final debut = widget.loc.debutBail;
    final liste = <DateTime>[];
    DateTime cursor = DateTime(debut.year, debut.month, 1);
    final limite = DateTime(now.year, now.month, 1);
    while (!cursor.isAfter(limite)) {
      liste.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return liste.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final mois = _getMois();
    final bien = widget.data.getBienById(widget.loc.bienId);
    return ListView.builder(
      itemCount: mois.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _MoisPaiementRow(loc: widget.loc, bien: bien, mois: mois[i], data: widget.data),
      ),
    );
  }
}

// ─── CHART ─────────────────────────────────────────────────────────────────

class _RevenusChart extends StatelessWidget {
  final DataService data;
  const _RevenusChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final mois = data.revenusParMois;
    final moisLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    final max = mois.reduce((a, b) => a > b ? a : b);
    final currentMonth = DateTime.now().month - 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Revenus mensuels', style: TextStyle(fontWeight: FontWeight.w500)),
            Text(_euro.format(data.revenusAnnee),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.primary)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: BarChart(BarChartData(
              maxY: max == 0 ? 1000 : max * 1.2,
              barGroups: List.generate(12, (i) => BarChartGroupData(
                x: i,
                barRods: [BarChartRodData(
                  toY: mois[i],
                  color: i == currentMonth ? AppTheme.primary : const Color(0xFFE1F5EE),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                )],
              )),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Text(moisLabels[v.toInt()],
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                )),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
            )),
          ),
        ]),
      ),
    );
  }
}

// ─── OCCUPATION ────────────────────────────────────────────────────────────

class _OccupationCard extends StatelessWidget {
  final DataService data;
  const _OccupationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Occupation', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: PieChart(PieChartData(
              sections: [
                PieChartSectionData(
                  value: data.biensLoues.toDouble(),
                  color: AppTheme.primary,
                  title: '${data.biensLoues}',
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                  radius: 40,
                ),
                PieChartSectionData(
                  value: data.biensVacants.toDouble(),
                  color: const Color(0xFFEF9F27),
                  title: '${data.biensVacants}',
                  titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                  radius: 40,
                ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 20,
            )),
          ),
          const SizedBox(height: 8),
          const _Legend(color: AppTheme.primary, label: 'Loués'),
          const SizedBox(height: 4),
          const _Legend(color: AppTheme.warning, label: 'Vacants'),
        ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ]);
  }
}

// ─── ALERTES ───────────────────────────────────────────────────────────────

class _AlertesCard extends StatelessWidget {
  final DataService data;
  const _AlertesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final urgents = data.tickets.where((t) =>
        t.priorite.name == 'urgent' && t.statut.name != 'resolu').toList();
    final retards = data.locataires.where((l) =>
        data.getStatutLocataire(l) != StatutPaiement.aJour).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Alertes', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 10),
          if (urgents.isEmpty && retards.isEmpty)
            const Text('Aucune alerte', style: TextStyle(fontSize: 12, color: Colors.grey))
          else ...[
            ...urgents.map((t) => _AlerteItem(
              icon: Icons.build, color: AppTheme.danger,
              label: t.titre, sub: 'Ticket urgent',
            )),
            ...retards.map((l) => _AlerteItem(
              icon: Icons.warning_amber, color: AppTheme.warning,
              label: l.nomComplet, sub: 'Retard de loyer',
            )),
          ],
        ]),
      ),
    );
  }
}

class _AlerteItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, sub;
  const _AlerteItem({required this.icon, required this.color, required this.label, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          Text(sub, style: TextStyle(fontSize: 10, color: color)),
        ])),
      ]),
    );
  }
}
