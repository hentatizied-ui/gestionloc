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

class FinancesScreen extends StatelessWidget {
  const FinancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final txs = data.transactions;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPIs
          Row(children: [
            Expanded(child: _KpiCard('Revenus (année)', _euro.format(data.revenusAnnee), AppTheme.primary)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('Charges (année)', _euro.format(data.chargesAnnee), AppTheme.danger)),
            const SizedBox(width: 10),
            Expanded(child: _KpiCard('Net', _euro.format(data.revenusAnnee - data.chargesAnnee), AppTheme.blue)),
          ]),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Transactions', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter'),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => FormTransaction(data: data),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (txs.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Aucune transaction', style: TextStyle(color: Colors.grey)),
            ))
          else
            ...txs.map((tx) => _TxRow(tx: tx, data: data)),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final icon = _icon(tx.type);
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
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx.label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            Text(
              '${bien?.nom ?? ''} · ${_dateF.format(tx.date)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ])),
          Text(
            (tx.isRecette ? '+' : '-') + _euro.format(tx.montant.abs()),
            style: TextStyle(
              fontWeight: FontWeight.w500, fontSize: 14,
              color: tx.isRecette ? AppTheme.primary : AppTheme.danger,
            ),
          ),
        ]),
      ),
    );
  }

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
}

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
                items: TypeTransaction.values.map((t) =>
                    DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _bienId,
                decoration: _deco('Bien concerné (optionnel)'),
                items: widget.data.biens.map((b) =>
                    DropdownMenuItem(value: b.id, child: Text(b.nom))).toList(),
                onChanged: (v) => setState(() => _bienId = v),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecette ? AppTheme.primary : AppTheme.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
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
      label: _label.text, montant: montant, type: _type, bienId: _bienId,
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
        child: Text(label,
            textAlign: TextAlign.center,
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
      body: Column(
        children: [
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "fab_finances",
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
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
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500,
          color: active ? AppTheme.primaryDark : Colors.grey[600],
        )),
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
        child: Row(
          children: [
            Container(width: 4, decoration: BoxDecoration(
              color: _prioColor,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            )),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ticket.titre, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(
                      '${bien?.nom ?? ticket.bienId} · ${_dateF.format(ticket.dateCreation)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    if (ticket.rapportePar != null) ...[
                      const SizedBox(height: 2),
                      Text('Signalé par ${ticket.rapportePar}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _prioColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_statutLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _prioColor)),
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
              ),
            ),
          ],
        ),
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
                items: widget.data.biens.map((b) =>
                    DropdownMenuItem(value: b.id, child: Text(b.nom))).toList(),
                validator: (v) => v == null ? 'Requis' : null,
                onChanged: (v) => setState(() => _bienId = v),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<PrioriteTicket>(
                value: _priorite,
                decoration: _deco('Priorité'),
                items: PrioriteTicket.values.map((p) =>
                    DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (v) => setState(() => _priorite = v!),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
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
      titre: _titre.text,
      description: _desc.text,
      bienId: _bienId!,
      priorite: _priorite,
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
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Champ requis' : null,
      ),
    );
  }
}