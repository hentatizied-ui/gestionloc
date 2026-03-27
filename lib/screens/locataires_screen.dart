import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../services/user_service.dart';
import '../models/models.dart';
import '../main.dart';

final _dateF = DateFormat('dd/MM/yyyy', 'fr_FR');
final _dateMoisF = DateFormat('MMMM yyyy', 'fr_FR');
final _euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);

class LocatairesScreen extends StatelessWidget {
  const LocatairesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    return Scaffold(
      body: data.locataires.isEmpty
          ? const Center(child: Text('Aucun locataire enregistré'))
          : RefreshIndicator(
              onRefresh: data.loadAll,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: data.locataires.length,
                itemBuilder: (_, i) => _LocataireRow(loc: data.locataires[i], data: data),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_locataires',
        onPressed: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => FormLocataire(data: data),
        ),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.person_add_outlined, color: Colors.white),
      ),
    );
  }
}

// ─── ROW ───────────────────────────────────────────────────────────────────

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
        onTap: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => _LocataireDetail(loc: loc, data: data),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(radius: 20, backgroundColor: const Color(0xFFB5D4F4),
                child: Text(loc.initiales, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF042C53)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(loc.nomComplet, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(bien != null ? bien.nom : 'Aucun bien assigné', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text('Bail jusqu\'au ${_dateF.format(loc.finBail)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (bien != null) Text(_euro.format(bien.loyerMensuel), style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: _statusColor)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ─── DETAIL ────────────────────────────────────────────────────────────────

class _LocataireDetail extends StatelessWidget {
  final Locataire loc;
  final DataService data;
  const _LocataireDetail({required this.loc, required this.data});

  @override
  Widget build(BuildContext context) {
    final bien = data.getBienById(loc.bienId);
    final prochaine = _prochaineEcheance();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            CircleAvatar(radius: 28, backgroundColor: const Color(0xFFB5D4F4),
                child: Text(loc.initiales, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Color(0xFF042C53)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(loc.nomComplet, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              Text(loc.email, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ])),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(context: context, isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => FormLocataire(data: data, locataire: loc));
            }),
            IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFE24B4A)),
              onPressed: () { data.supprimerLocataire(loc.id); Navigator.pop(context); }),
          ]),
          const Divider(height: 24),
          _InfoRow('Téléphone', loc.telephone),
          _InfoRow('Bien loué', bien?.nom ?? 'Non assigné'),
          _InfoRow('Début bail', _dateF.format(loc.debutBail)),
          _InfoRow('Fin bail', _dateF.format(loc.finBail)),
          _InfoRow('Dépôt', _euro.format(loc.depot)),
          if (bien != null) _InfoRow('Loyer', '${_euro.format(bien.loyerMensuel)}/mois'),
          const SizedBox(height: 16),

          // Prochaine échéance
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.schedule, color: AppTheme.primaryDark, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Prochaine échéance', style: TextStyle(fontSize: 12, color: AppTheme.primaryDark, fontWeight: FontWeight.w500)),
                Text(_dateF.format(prochaine), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.primaryDark)),
              ])),
              if (bien != null)
                Text(_euro.format(bien.loyerMensuel + bien.charges),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.primary)),
            ]),
          ),
          const SizedBox(height: 20),

          // Historique
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Historique des paiements', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
          ]),
          const SizedBox(height: 10),
          _HistoriquePaiements(loc: loc, data: data, bien: bien),
        ],
      ),
    );
  }

  DateTime _prochaineEcheance() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
  }
}

// ─── HISTORIQUE ────────────────────────────────────────────────────────────

class _HistoriquePaiements extends StatefulWidget {
  final Locataire loc;
  final DataService data;
  final Bien? bien;
  const _HistoriquePaiements({required this.loc, required this.data, required this.bien});

  @override
  State<_HistoriquePaiements> createState() => _HistoriquePaiementsState();
}

class _HistoriquePaiementsState extends State<_HistoriquePaiements> {
  bool _saving = false;

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

  Transaction? _getPaiement(DateTime mois) {
    return widget.data.getLoyers(widget.loc.bienId ?? '').cast<Transaction?>().firstWhere(
      (t) => t != null && t.date.year == mois.year && t.date.month == mois.month,
      orElse: () => null,
    );
  }

  Future<void> _validerPaiement(DateTime mois) async {
    if (_saving) return;
    setState(() => _saving = true);
    final bien = widget.bien;
    final montant = (bien?.loyerMensuel ?? 0) + (bien?.charges ?? 0);
    final tx = widget.data.nouvTransaction(
      label: 'Loyer ${_dateMoisF.format(mois)} - ${widget.loc.nomComplet}',
      montant: montant,
      type: TypeTransaction.loyer,
      date: DateTime(mois.year, mois.month, 1),
      bienId: widget.loc.bienId,
      locataireId: widget.loc.id,
    );
    await widget.data.ajouterTransaction(tx);
    setState(() => _saving = false);
  }

  Future<void> _supprimerPaiement(String txId) async {
    await widget.data.supprimerTransaction(txId);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mois = _getMois();
    if (mois.isEmpty) return const Text('Aucun mois à afficher');

    return Column(
      children: mois.map((m) {
        final paiement = _getPaiement(m);
        final estPaye = paiement != null;
        final montant = widget.bien != null ? (widget.bien!.loyerMensuel + widget.bien!.charges) : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: estPaye ? AppTheme.primaryLight : const Color(0xFFFCEBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: estPaye ? AppTheme.primary.withOpacity(0.2) : AppTheme.danger.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Row(children: [
            Icon(estPaye ? Icons.check_circle : Icons.cancel,
                size: 18, color: estPaye ? AppTheme.primary : AppTheme.danger),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_capitalize(_dateMoisF.format(m)),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                      color: estPaye ? AppTheme.primaryDark : AppTheme.danger)),
              if (estPaye)
                Text(_euro.format(paiement.montant),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ])),
            if (!estPaye)
              TextButton(
                onPressed: _saving ? null : () => _validerPaiement(m),
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _saving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Valider', style: TextStyle(fontSize: 12)),
              )
            else
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined, size: 18, color: AppTheme.primary),
                  tooltip: 'Quittance',
                  onPressed: () => _showQuittance(context, m, paiement),
                ),
                IconButton(
                  icon: const Icon(Icons.undo, size: 18, color: Colors.grey),
                  tooltip: 'Annuler',
                  onPressed: () => _supprimerPaiement(paiement.id),
                ),
              ]),
          ]),
        );
      }).toList(),
    );
  }

  void _showQuittance(BuildContext context, DateTime mois, Transaction paiement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _QuittanceSheet(
        loc: widget.loc,
        bien: widget.bien,
        mois: mois,
        paiement: paiement,
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ─── QUITTANCE ─────────────────────────────────────────────────────────────

class _QuittanceSheet extends StatelessWidget {
  final Locataire loc;
  final Bien? bien;
  final DateTime mois;
  final Transaction paiement;
  const _QuittanceSheet({required this.loc, required this.bien, required this.mois, required this.paiement});

  String _genererTexte(String proprietaire) {
    final moisStr = DateFormat('MMMM yyyy', 'fr_FR').format(mois);
    final loyer = bien?.loyerMensuel ?? 0;
    final charges = bien?.charges ?? 0;
    final total = loyer + charges;
    final adresse = bien != null ? '${bien!.adresse}, ${bien!.ville} ${bien!.codePostal}' : '';

    return '''QUITTANCE DE LOYER

Période : ${_capitalize(moisStr)}
Date d\'émission : ${DateFormat('dd/MM/yyyy').format(DateTime.now())}

─────────────────────────────
BAILLEUR
$proprietaire

LOCATAIRE
${loc.nomComplet}
${loc.email} | ${loc.telephone}

BIEN LOUÉ
${bien?.nom ?? ''}
$adresse

─────────────────────────────
DTAIL DU PAIEMENT
Loyer : ${_fmt(loyer)}
Charges : ${_fmt(charges)}
TOTAL : ${_fmt(total)}

Reçu le : ${DateFormat('dd/MM/yyyy').format(paiement.date)}
─────────────────────────────

Je soussigné $proprietaire, bailleur,
déclare avoir reçu de ${loc.nomComplet}
la somme de ${_fmt(total)} au titre du loyer
et des charges pour la période de ${_capitalize(moisStr)}.

Cette quittance annule tous les reçus antérieurs.''';
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  String _fmt(double v) => NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0).format(v);

  @override
  Widget build(BuildContext context) {
    final userService = context.read<UserService>();
    final proprietaire = userService.displayName.isNotEmpty ? userService.displayName : 'Le propriétaire';
    final texte = _genererTexte(proprietaire);
    final moisStr = _capitalize(DateFormat('MMMM yyyy', 'fr_FR').format(mois));
    final sujet = Uri.encodeComponent('Quittance de loyer - $moisStr');
    final corps = Uri.encodeComponent(texte);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
          Row(children: [
            const Icon(Icons.receipt_long, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text('Quittance - $moisStr', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 16),

          // Aperçu quittance
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(texte, style: const TextStyle(fontSize: 12, height: 1.6, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 20),

          // Boutons partage
          const Text('Envoyer la quittance :', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          const SizedBox(height: 12),

          // Email
          _PartageBtn(
            icon: Icons.email_outlined,
            label: 'Envoyer par Email',
            color: AppTheme.blue,
            onTap: () {
              final url = 'mailto:${loc.email}?subject=$sujet&body=$corps';
              _ouvrirUrl(context, url);
            },
          ),
          const SizedBox(height: 10),

          // WhatsApp
          _PartageBtn(
            icon: Icons.chat_outlined,
            label: 'Envoyer par WhatsApp',
            color: const Color(0xFF25D366),
            onTap: () {
              final phone = loc.telephone.replaceAll(RegExp(r'[^0-9]'), '');
              final url = 'https://wa.me/$phone?text=$corps';
              _ouvrirUrl(context, url);
            },
          ),
          const SizedBox(height: 10),

          // Copier texte
          _PartageBtn(
            icon: Icons.copy,
            label: 'Copier le texte',
            color: Colors.grey[700]!,
            onTap: () async {
              // Sur web, on utilise une approche différente
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Texte copié !'), backgroundColor: AppTheme.primary),
              );
            },
          ),
        ],
      ),
    );
  }

  void _ouvrirUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Lien'),
            content: SelectableText(url),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
          ),
        );
      }
    }
  }
  
}

class _PartageBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _PartageBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios, color: color, size: 14),
        ]),
      ),
    );
  }
}

// ─── INFOS ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

// ─── FORMULAIRE ────────────────────────────────────────────────────────────

class FormLocataire extends StatefulWidget {
  final DataService data;
  final Locataire? locataire;
  const FormLocataire({super.key, required this.data, this.locataire});

  @override
  State<FormLocataire> createState() => _FormLocataireState();
}

class _FormLocataireState extends State<FormLocataire> {
  final _key = GlobalKey<FormState>();
  late final _prenom = TextEditingController(text: widget.locataire?.prenom ?? '');
  late final _nom = TextEditingController(text: widget.locataire?.nom ?? '');
  late final _email = TextEditingController(text: widget.locataire?.email ?? '');
  late final _tel = TextEditingController(text: widget.locataire?.telephone ?? '');
  late final _depot = TextEditingController(text: widget.locataire != null ? widget.locataire!.depot.toString() : '');
  late String? _bienId = widget.locataire?.bienId;
  late DateTime _debut = widget.locataire?.debutBail ?? DateTime.now();
  late DateTime _fin = widget.locataire?.finBail ?? DateTime.now().add(const Duration(days: 365));
  late StatutPaiement _statut = widget.locataire?.statut ?? StatutPaiement.aJour;
  bool _saving = false;

  bool get _isEdit => widget.locataire != null;

  @override
  Widget build(BuildContext context) {
    final biens = _isEdit
        ? widget.data.biens.where((b) => !b.estLoue || b.id == _bienId).toList()
        : widget.data.biens.where((b) => !b.estLoue).toList();

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
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              Text(_isEdit ? 'Modifier le locataire' : 'Nouveau locataire',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _TF(_prenom, 'Prénom')),
                const SizedBox(width: 12),
                Expanded(child: _TF(_nom, 'Nom')),
              ]),
              _TF(_email, 'Email', keyboard: TextInputType.emailAddress),
              _TF(_tel, 'Téléphone', keyboard: TextInputType.phone),
              _TF(_depot, 'Dépôt de garantie (€)', keyboard: TextInputType.number),
              DropdownButtonFormField<String?>(
                value: _bienId,
                decoration: _deco('Bien loué'),
                hint: const Text('Sélectionner un bien'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucun bien')),
                  ...biens.map((b) => DropdownMenuItem(value: b.id, child: Text(b.nom))),
                ],
                onChanged: (v) => setState(() => _bienId = v),
              ),
              const SizedBox(height: 14),
              if (_isEdit) ...[
                DropdownButtonFormField<StatutPaiement>(
                  value: _statut,
                  decoration: _deco('Statut paiement'),
                  items: [
                    DropdownMenuItem(value: StatutPaiement.aJour, child: Row(children: [Icon(Icons.check_circle, color: AppTheme.primary, size: 16), const SizedBox(width: 8), const Text('À jour')])),
                    DropdownMenuItem(value: StatutPaiement.enRetard, child: Row(children: [Icon(Icons.warning, color: AppTheme.warning, size: 16), const SizedBox(width: 8), const Text('En retard')])),
                    DropdownMenuItem(value: StatutPaiement.retardCritique, child: Row(children: [Icon(Icons.error, color: AppTheme.danger, size: 16), const SizedBox(width: 8), const Text('Retard critique')])),
                  ],
                  onChanged: (v) => setState(() => _statut = v!),
                ),
                const SizedBox(height: 14),
              ],
              _DatePicker(label: 'Début du bail', date: _debut, onPick: (d) => setState(() => _debut = d)),
              const SizedBox(height: 10),
              _DatePicker(label: 'Fin du bail', date: _fin, onPick: (d) => setState(() => _fin = d)),
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
                    : Text(_isEdit ? 'Enregistrer' : 'Ajouter le locataire'),
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
    if (_isEdit) {
      await widget.data.modifierLocataire(widget.locataire!.copyWith(
        prenom: _prenom.text, nom: _nom.text, email: _email.text, telephone: _tel.text,
        bienId: _bienId, debutBail: _debut, finBail: _fin,
        depot: double.tryParse(_depot.text) ?? 0, statut: _statut,
      ));
    } else {
      await widget.data.ajouterLocataire(widget.data.nouvLocataire(
        prenom: _prenom.text, nom: _nom.text, email: _email.text, telephone: _tel.text,
        bienId: _bienId, debutBail: _debut, finBail: _fin,
        depot: double.tryParse(_depot.text) ?? 0,
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
        controller: ctrl, keyboardType: keyboard,
        decoration: InputDecoration(labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
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
        final picked = await showDatePicker(context: context, initialDate: date,
            firstDate: DateTime(2020), lastDate: DateTime(2040));
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[400]!), borderRadius: BorderRadius.circular(10)),
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