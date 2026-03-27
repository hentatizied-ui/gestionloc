import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../models/models.dart';
import '../main.dart';

final _dateF = DateFormat('dd/MM/yyyy', 'fr_FR');
final _euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);

class LocatairesScreen extends StatelessWidget {
  const LocatairesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final locataires = data.locataires;

    return Scaffold(
      body: locataires.isEmpty
          ? const Center(child: Text('Aucun locataire enregistré'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: locataires.length,
              itemBuilder: (_, i) => _LocataireRow(loc: locataires[i], data: data),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => FormLocataire(data: data),
        ),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.person_add_outlined, color: Colors.white),
      ),
    );
  }
}

class _LocataireRow extends StatelessWidget {
  final Locataire loc;
  final DataService data;
  const _LocataireRow({required this.loc, required this.data});

  Color get _statusColor {
    switch (loc.statut) {
      case StatutPaiement.aJour: return AppTheme.primary;
      case StatutPaiement.enRetard: return AppTheme.warning;
      case StatutPaiement.retardCritique: return AppTheme.danger;
    }
  }

  String get _statusLabel {
    switch (loc.statut) {
      case StatutPaiement.aJour: return 'À jour';
      case StatutPaiement.enRetard: return 'En retard';
      case StatutPaiement.retardCritique: return 'Retard critique';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bien = data.getBienById(loc.bienId);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFB5D4F4),
                child: Text(loc.initiales,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF042C53))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc.nomComplet, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      bien != null ? bien.nom : 'Aucun bien assigné',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bail jusqu\'au ${_dateF.format(loc.finBail)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (bien != null)
                    Text(_euro.format(bien.loyerMensuel),
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_statusLabel,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _statusColor)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _LocataireDetail(loc: loc, data: data),
    );
  }
}

class _LocataireDetail extends StatelessWidget {
  final Locataire loc;
  final DataService data;
  const _LocataireDetail({required this.loc, required this.data});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            CircleAvatar(
              radius: 28, backgroundColor: const Color(0xFFB5D4F4),
              child: Text(loc.initiales, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF042C53))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.nomComplet, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                Text(loc.email, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            )),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFE24B4A)),
              onPressed: () { data.supprimerLocataire(loc.id); Navigator.pop(context); },
            ),
          ]),
          const Divider(height: 24),
          _Row('Téléphone', loc.telephone),
          _Row('Début bail', _dateF.format(loc.debutBail)),
          _Row('Fin bail', _dateF.format(loc.finBail)),
          _Row('Dépôt', _euro.format(loc.depot)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _ActionBtn(
              icon: Icons.phone, label: 'Appeler', color: AppTheme.primary,
              onTap: () {},
            )),
            const SizedBox(width: 10),
            Expanded(child: _ActionBtn(
              icon: Icons.email_outlined, label: 'Email', color: AppTheme.blue,
              onTap: () {},
            )),
          ]),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─── FORMULAIRE ────────────────────────────────────────────────────────────

class FormLocataire extends StatefulWidget {
  final DataService data;
  const FormLocataire({super.key, required this.data});

  @override
  State<FormLocataire> createState() => _FormLocataireState();
}

class _FormLocataireState extends State<FormLocataire> {
  final _key = GlobalKey<FormState>();
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _tel = TextEditingController();
  final _depot = TextEditingController();
  String? _bienId;
  DateTime _debut = DateTime.now();
  DateTime _fin = DateTime.now().add(const Duration(days: 365));
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final biens = widget.data.biens.where((b) => !b.estLoue).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Form(
          key: _key,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              const Text('Nouveau locataire', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _TF(_prenom, 'Prénom')),
                const SizedBox(width: 12),
                Expanded(child: _TF(_nom, 'Nom')),
              ]),
              _TF(_email, 'Email', keyboard: TextInputType.emailAddress),
              _TF(_tel, 'Téléphone', keyboard: TextInputType.phone),
              _TF(_depot, 'Dépôt de garantie (€)', keyboard: TextInputType.number),
              DropdownButtonFormField<String>(
                value: _bienId,
                decoration: _deco('Bien loué'),
                hint: const Text('Sélectionner un bien vacant'),
                items: biens.map((b) => DropdownMenuItem(value: b.id, child: Text(b.nom))).toList(),
                onChanged: (v) => setState(() => _bienId = v),
              ),
              const SizedBox(height: 14),
              _DatePicker(
                label: 'Début du bail',
                date: _debut,
                onPick: (d) => setState(() => _debut = d),
              ),
              const SizedBox(height: 10),
              _DatePicker(
                label: 'Fin du bail',
                date: _fin,
                onPick: (d) => setState(() => _fin = d),
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
                    : const Text('Ajouter le locataire'),
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
    final loc = widget.data.nouvLocataire(
      prenom: _prenom.text, nom: _nom.text,
      email: _email.text, telephone: _tel.text,
      bienId: _bienId,
      debutBail: _debut, finBail: _fin,
      depot: double.tryParse(_depot.text) ?? 0,
    );
    await widget.data.ajouterLocataire(loc);
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
  final TextInputType keyboard;
  const _TF(this.ctrl, this.label, {this.keyboard = TextInputType.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
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

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  const _DatePicker({required this.label, required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2040),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const Spacer(),
          Text(_dateF.format(date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
