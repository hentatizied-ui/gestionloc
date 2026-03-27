import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../models/models.dart';
import '../main.dart';

final _euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);

class BiensScreen extends StatefulWidget {
  const BiensScreen({super.key});
  @override
  State<BiensScreen> createState() => _BiensScreenState();
}

class _BiensScreenState extends State<BiensScreen> {
  String _filtre = 'tous';

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();

    return Scaffold(
      body: Column(
        children: [
          _FilterBar(filtre: _filtre, onChanged: (f) => setState(() => _filtre = f), data: data),
          Expanded(
            child: RefreshIndicator(
              onRefresh: data.loadAll,
              child: _buildList(data),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "fab_biens",
        onPressed: () => _showFormBien(context, data),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildList(DataService data) {
    // Immeubles avec leurs biens
    final items = <Widget>[];

    // Biens groupés par immeuble
    for (final immeuble in data.immeubles) {
      final biensDeLImmeuble = data.getBiensDeLImmeuble(immeuble.id).where((b) {
        if (_filtre == 'loues') return b.estLoue;
        if (_filtre == 'vacants') return !b.estLoue;
        return true;
      }).toList();

      if (biensDeLImmeuble.isEmpty && _filtre != 'tous') continue;

      items.add(_ImmeubleHeader(immeuble: immeuble, nbBiens: biensDeLImmeuble.length));
      for (final bien in biensDeLImmeuble) {
        items.add(_BienCard(bien: bien, data: data, indent: true));
      }
    }

    // Biens sans immeuble
    final biensSansImm = data.biensSansImmeuble.where((b) {
      if (_filtre == 'loues') return b.estLoue;
      if (_filtre == 'vacants') return !b.estLoue;
      return true;
    }).toList();

    if (biensSansImm.isNotEmpty) {
      if (data.immeubles.isNotEmpty) {
        items.add(const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Biens indépendants', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.grey)),
        ));
      }
      for (final bien in biensSansImm) {
        items.add(_BienCard(bien: bien, data: data, indent: false));
      }
    }

    if (items.isEmpty) {
      return const Center(child: Text('Aucun bien trouvé'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: items,
    );
  }

  void _showFormBien(BuildContext context, DataService data, [Bien? bien]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => FormBien(data: data, bien: bien),
    );
  }
}

class _ImmeubleHeader extends StatelessWidget {
  final Immeuble immeuble;
  final int nbBiens;
  const _ImmeubleHeader({required this.immeuble, required this.nbBiens});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.apartment, size: 18, color: AppTheme.primaryDark),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(immeuble.nom, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.primaryDark)),
          Text('${immeuble.adresse}, ${immeuble.ville}', style: const TextStyle(fontSize: 11, color: AppTheme.primaryDark)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20)),
          child: Text('$nbBiens apt.', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
        ),
      ]),
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
      child: Row(children: [
        _Chip(label: 'Tous (${data.biens.length})', active: filtre == 'tous', onTap: () => onChanged('tous')),
        const SizedBox(width: 8),
        _Chip(label: 'Loués (${data.biensLoues})', active: filtre == 'loues', onTap: () => onChanged('loues')),
        const SizedBox(width: 8),
        _Chip(label: 'Vacants (${data.biensVacants})', active: filtre == 'vacants', onTap: () => onChanged('vacants')),
      ]),
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
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: active ? AppTheme.primaryDark : Colors.grey[600])),
      ),
    );
  }
}

class _BienCard extends StatelessWidget {
  final Bien bien;
  final DataService data;
  final bool indent;
  const _BienCard({required this.bien, required this.data, required this.indent});

  @override
  Widget build(BuildContext context) {
    final locataire = data.getLocataireDuBien(bien.id);
    return Container(
      margin: EdgeInsets.only(bottom: 10, left: indent ? 12 : 0),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: bien.estLoue ? const Color(0xFFE1F5EE) : const Color(0xFFFAEEDA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(_emoji(bien.type), style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(bien.nom, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (bien.immeubleId == null || bien.immeubleId!.isEmpty)
                  Text('${bien.adresse}, ${bien.ville}', style: TextStyle(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
                if (locataire != null)
                  Text(locataire.nomComplet, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_euro.format(bien.loyerMensuel), style: const TextStyle(fontWeight: FontWeight.w500, color: AppTheme.primary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: bien.estLoue ? const Color(0xFFE1F5EE) : const Color(0xFFFAEEDA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(bien.estLoue ? 'Loué' : 'Vacant',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: bien.estLoue ? AppTheme.primaryDark : const Color(0xFF633806))),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  String _emoji(String type) {
    switch (type) {
      case 'maison': return '🏡';
      case 'studio': return '🏠';
      case 'loft': return '🏙';
      default: return '🏢';
    }
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BienDetail(bien: bien, data: data),
    );
  }
}

class _BienDetail extends StatelessWidget {
  final Bien bien;
  final DataService data;
  const _BienDetail({required this.bien, required this.data});

  @override
  Widget build(BuildContext context) {
    final immeuble = data.getImmeubleById(bien.immeubleId);
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
            Expanded(child: Text(bien.nom, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(context: context, isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => FormBien(data: data, bien: bien));
            }),
            IconButton(icon: const Icon(Icons.delete_outline, color: Color(0xFFE24B4A)),
              onPressed: () { data.supprimerBien(bien.id); Navigator.pop(context); }),
          ]),
          const Divider(),
          if (immeuble != null) _Row('Immeuble', immeuble.nom),
          _Row('Adresse', '${bien.adresse}, ${bien.ville} ${bien.codePostal}'),
          _Row('Type', bien.type),
          _Row('Surface', '${bien.surface} m²'),
          _Row('Pièces', '${bien.pieces}'),
          if (bien.etage != null && bien.etage!.isNotEmpty) _Row('Étage', bien.etage!),
          if (bien.numero != null && bien.numero!.isNotEmpty) _Row('N°', bien.numero!),
          _Row('Loyer', _euro.format(bien.loyerMensuel)),
          _Row('Charges', _euro.format(bien.charges)),
          _Row('Statut', bien.estLoue ? 'Loué' : 'Vacant'),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

// ─── FORMULAIRE BIEN ───────────────────────────────────────────────────────

class FormBien extends StatefulWidget {
  final DataService data;
  final Bien? bien;
  const FormBien({super.key, required this.data, this.bien});

  @override
  State<FormBien> createState() => _FormBienState();
}

class _FormBienState extends State<FormBien> {
  final _formKey = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.bien?.nom);
  late final _adresse = TextEditingController(text: widget.bien?.adresse);
  late final _ville = TextEditingController(text: widget.bien?.ville);
  late final _codePostal = TextEditingController(text: widget.bien?.codePostal);
  late final _surface = TextEditingController(text: widget.bien?.surface.toString());
  late final _loyer = TextEditingController(text: widget.bien?.loyerMensuel.toString());
  late final _charges = TextEditingController(text: widget.bien?.charges.toString());
  late final _etage = TextEditingController(text: widget.bien?.etage ?? '');
  late final _numero = TextEditingController(text: widget.bien?.numero ?? '');
  late int _pieces = widget.bien?.pieces ?? 2;
  late String _type = widget.bien?.type ?? 'appartement';
  late String? _immeubleId = widget.bien?.immeubleId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final immeubles = widget.data.immeubles;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              Text(widget.bien == null ? 'Ajouter un bien' : 'Modifier le bien',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              // Immeuble optionnel
              DropdownButtonFormField<String?>(
                value: _immeubleId,
                decoration: _deco('Immeuble (optionnel)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Aucun (bien indépendant)')),
                  ...immeubles.map((i) => DropdownMenuItem(value: i.id, child: Text(i.nom))),
                ],
                onChanged: (v) {
                  setState(() => _immeubleId = v);
                  if (v != null) {
                    final imm = widget.data.getImmeubleById(v);
                    if (imm != null) {
                      _adresse.text = imm.adresse;
                      _ville.text = imm.ville;
                      _codePostal.text = imm.codePostal;
                    }
                  } else {
                    _adresse.clear();
                    _ville.clear();
                    _codePostal.clear();
                  }
                },
              ),
              const SizedBox(height: 14),
              _Field(ctrl: _nom, label: 'Nom du bien', hint: 'Ex : Apt 2B'),
              Row(children: [
                Expanded(child: _Field(ctrl: _etage, label: 'Étage', required: false)),
                const SizedBox(width: 12),
                Expanded(child: _Field(ctrl: _numero, label: 'N° appartement', required: false)),
              ]),
              _Field(ctrl: _adresse, label: 'Adresse'),
              Row(children: [
                Expanded(flex: 2, child: _Field(ctrl: _ville, label: 'Ville')),
                const SizedBox(width: 12),
                Expanded(child: _Field(ctrl: _codePostal, label: 'Code postal')),
              ]),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: _deco('Type de bien'),
                items: ['appartement', 'studio', 'maison', 'loft']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _Field(ctrl: _surface, label: 'Surface (m²)', keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Pièces', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(children: [
                    IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() { if (_pieces > 1) _pieces--; })),
                    Text('$_pieces', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _pieces++)),
                  ]),
                ])),
              ]),
              Row(children: [
                Expanded(child: _Field(ctrl: _loyer, label: 'Loyer (€/mois)', keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _Field(ctrl: _charges, label: 'Charges (€)', keyboard: TextInputType.number)),
              ]),
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
                    : Text(widget.bien == null ? 'Ajouter' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    if (widget.bien == null) {
      await widget.data.ajouterBien(widget.data.nouvBien(
        nom: _nom.text, adresse: _adresse.text, ville: _ville.text,
        codePostal: _codePostal.text, type: _type, pieces: _pieces,
        surface: double.tryParse(_surface.text) ?? 0,
        loyer: double.tryParse(_loyer.text) ?? 0,
        charges: double.tryParse(_charges.text) ?? 0,
        immeubleId: _immeubleId,
        etage: _etage.text.isNotEmpty ? _etage.text : null,
        numero: _numero.text.isNotEmpty ? _numero.text : null,
      ));
    } else {
      await widget.data.modifierBien(widget.bien!.copyWith(
        nom: _nom.text, adresse: _adresse.text, ville: _ville.text,
        codePostal: _codePostal.text, type: _type, pieces: _pieces,
        surface: double.tryParse(_surface.text) ?? 0,
        loyerMensuel: double.tryParse(_loyer.text) ?? 0,
        charges: double.tryParse(_charges.text) ?? 0,
        immeubleId: _immeubleId,
        etage: _etage.text.isNotEmpty ? _etage.text : null,
        numero: _numero.text.isNotEmpty ? _numero.text : null,
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

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final TextInputType keyboard;
  final bool required;
  const _Field({required this.ctrl, required this.label, this.hint, this.keyboard = TextInputType.text, this.required = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: required ? (v) => v == null || v.isEmpty ? 'Champ requis' : null : null,
      ),
    );
  }
}