import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/data_service.dart';
import '../main.dart';

final _euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();

    if (data.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: data.loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _KpiGrid(data: data),
          const SizedBox(height: 16),
          _RevenusChart(data: data),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _OccupationCard(data: data)),
              const SizedBox(width: 12),
              Expanded(child: _AlertesCard(data: data)),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final DataService data;
  const _KpiGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: [
        _KpiCard(
          label: 'Revenus ce mois',
          value: _euro.format(data.revenusMoisCourant),
          sub: '${_euro.format(data.revenusAnnee)} cette année',
          subColor: AppTheme.primary,
        ),
        _KpiCard(
          label: 'Occupation',
          value: '${data.biensLoues} / ${data.biens.length}',
          sub: '${(data.tauxOccupation * 100).toStringAsFixed(0)}% du parc',
          subColor: Colors.grey[600]!,
        ),
        _KpiCard(
          label: 'En attente',
          value: _euro.format(data.montantEnAttente),
          sub: '${data.locatairesEnRetard} locataire(s) en retard',
          subColor: data.locatairesEnRetard > 0 ? AppTheme.danger : Colors.grey[600]!,
        ),
        _KpiCard(
          label: 'Maintenance',
          value: '${data.ticketsOuverts} tickets',
          sub: data.ticketsUrgents > 0 ? '${data.ticketsUrgents} urgent(s) !' : 'Aucun urgent',
          subColor: data.ticketsUrgents > 0 ? AppTheme.warning : Colors.grey[600]!,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final Color subColor;
  const _KpiCard({required this.label, required this.value, required this.sub, required this.subColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 11, color: subColor)),
        ],
      ),
    );
  }
}

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Revenus mensuels', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: BarChart(
                BarChartData(
                  maxY: max == 0 ? 1000 : max * 1.2,
                  barGroups: List.generate(12, (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: mois[i],
                        color: i == currentMonth ? AppTheme.primary : const Color(0xFFE1F5EE),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  )),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text(
                          moisLabels[v.toInt()],
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OccupationCard extends StatelessWidget {
  final DataService data;
  const _OccupationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            _Legend(color: AppTheme.primary, label: 'Loués'),
            const SizedBox(height: 4),
            _Legend(color: AppTheme.warning, label: 'Vacants'),
          ],
        ),
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

class _AlertesCard extends StatelessWidget {
  final DataService data;
  const _AlertesCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final urgents = data.tickets.where((t) =>
      t.priorite.name == 'urgent' && t.statut.name != 'resolu').toList();
    final retards = data.locataires.where((l) => l.statut.name != 'aJour').toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alertes', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
            const SizedBox(height: 10),
            if (urgents.isEmpty && retards.isEmpty)
              const Text('Aucune alerte', style: TextStyle(fontSize: 12, color: Colors.grey))
            else ...[
              ...urgents.map((t) => _AlerteItem(
                icon: Icons.build, color: AppTheme.danger,
                label: t.titre, sub: 'Urgent',
              )),
              ...retards.map((l) => _AlerteItem(
                icon: Icons.warning_amber, color: AppTheme.warning,
                label: l.nomComplet, sub: 'Retard de loyer',
              )),
            ],
          ],
        ),
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
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            Text(sub, style: TextStyle(fontSize: 10, color: color)),
          ],
        )),
      ]),
    );
  }
}
