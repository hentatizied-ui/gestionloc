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
  final Set<String> _collapsed = {};
  bool _fabOpen = false;

  void _toggleImmeuble(String id) {
    setState(() {
      if (_collapsed.contains(id)) _collapsed.remove(id);
      else _collapsed.add(id);
    });
  }

  void _toggleFab() => setState(() => _fabOpen = !_fabOpen);
  void _closeFab() => setState(() => _fabOpen = false);

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();

    return Scaffold(
      body: Stack(
        children: [
          Column(
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
          // Overlay transparent pour fermer le FAB au tap extérieur
          if (_fabOpen)
            GestureDetector(
              onTap: _closeFab,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_fabOpen) ...[
            // Option : Ajouter immeuble
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                ),
                child: const Text('Ajouter un immeuble', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF378ADD))),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                heroTag: 'fab_immeuble',
                onPressed: () { _closeFab(); _showFormImmeuble(context, data); },
                backgroundColor: const Color(0xFF378ADD),
                child: const Icon(Icons.apartment, color: Colors.white, size: 18),
              ),
            ]),
            const SizedBox(height: 10),
            // Option : Ajouter bien
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                ),
                child: const Text('Ajouter un bien', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.primary)),
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                heroTag: 'fab_bien',
                onPressed: () { _closeFab(); _showFormBien(context, data); },
                backgroundColor: AppTheme.primary,
                child: const Icon(Icons.home_work_outlined, color: Colors.white, size: 18),
              ),
            ]),
            const SizedBox(height: 10),
          ],
          // Bouton principal +
          FloatingActionButton(
            heroTag: 'fab_main',
            onPressed: _toggleFab,
            backgroundColor: _fabOpen ? Colors.grey[700] : AppTheme.primary,
            child: AnimatedRotation(
              turns: _fabOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
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

      final isCollapsed = _collapsed.contains(immeuble.id);
      items.add(_ImmeubleHeader(
        immeuble: immeuble,
        nbBiens: biensDeLImmeuble.length,
        data: data,
        isCollapsed: isCollapsed,
        onToggle: () => _toggleImmeuble(immeuble.id),
      ));
      if (!isCollapsed) {
        for (final bien in biensDeLImmeuble) {
          items.add(_BienCard(bien: bien, data: data, indent: true));
        }
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

  void _showFormImmeuble(BuildContext context, DataService data, [Immeuble? immeuble]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => FormImmeuble(data: data, immeuble: immeuble),
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
  final DataService data;
  final bool isCollapsed;
  final VoidCallback onToggle;
  const _ImmeubleHeader({required this.immeuble, required this.nbBiens, required this.data, required this.isCollapsed, required this.onToggle});

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
          Text('${immeuble.adresse}, ${immeuble.ville} ${immeuble.codePostal}', style: const TextStyle(fontSize: 11, color: AppTheme.primaryDark)),
          Text('${immeuble.nbEtages} étage(s)', style: const TextStyle(fontSize: 10, color: AppTheme.primaryDark)),
        ])),
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$nbBiens apt.', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Icon(isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, size: 14, color: Colors.white),
            ]),
          ),
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => showModalBottomSheet(
            context: context, isScrollControlled: true,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => FormImmeuble(data: data, immeuble: immeuble),
          ),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.edit_outlined, size: 16, color: AppTheme.primaryDark),
          ),
        ),
        InkWell(
          onTap: () => showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Supprimer l'immeuble"),
              content: Text('Supprimer "${immeuble.nom}" ? Les biens associes ne seront pas supprimes.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                TextButton(
                  onPressed: () { data.supprimerImmeuble(immeuble.id); Navigator.pop(context); },
                  child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.delete_outline, size: 16, color: Colors.red),
          ),
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
  late final _prixAchat = TextEditingController(text: widget.bien != null && widget.bien!.prixAchat > 0 ? widget.bien!.prixAchat.toString() : '');
  late final _taxeFonciere = TextEditingController(text: widget.bien != null && widget.bien!.taxeFonciere > 0 ? widget.bien!.taxeFonciere.toString() : '');
  late final _numero = TextEditingController(text: widget.bien?.numero ?? '');
  late int _pieces = widget.bien?.pieces ?? 2;
  late String _type = widget.bien?.type ?? 'appartement';
  late String? _immeubleId = widget.bien?.immeubleId;
  late String? _etageVal = _etageCodeToLabel(widget.bien?.etage);

  static String? _etageCodeToLabel(String? code) {
    if (code == null || code.isEmpty) return null;
    const etages = ['RDC', '1er Étage', '2ème Étage', '3ème Étage', '4ème Étage',
      '5ème Étage', '6ème Étage', '7ème Étage', '8ème Étage', '9ème Étage', '10ème Étage'];
    final idx = int.tryParse(code);
    if (idx == null) return null;
    if (idx < etages.length) return etages[idx];
    return null;
  }
  bool _saving = false;

  // Liste des étages
  static const List<String> _etages = [
    'RDC', '1er Étage', '2ème Étage', '3ème Étage', '4ème Étage',
    '5ème Étage', '6ème Étage', '7ème Étage', '8ème Étage', '9ème Étage', '10ème Étage',
  ];

  // Etage code (0 pour RDC, 1 pour 1er, etc.)
  String _etageCode(String? etageLabel) {
    if (etageLabel == null) return '';
    if (etageLabel == 'RDC') return '0';
    final idx = _etages.indexOf(etageLabel);
    return idx > 0 ? idx.toString() : '';
  }

  // Génère le nom automatiquement
  void _autoNom() {
    if (widget.bien != null) return;
    final code = _etageCode(_etageVal);
    final numero = _numero.text.trim();
    if (code.isEmpty && numero.isEmpty) return;

    // Préfixe selon le type
    final prefix = _type == 'appartement' ? 'Apt' : _capitalize(_type);

    if (code.isNotEmpty && numero.isNotEmpty) {
      _nom.text = prefix + code + '-' + numero;
    } else if (code.isNotEmpty) {
      _nom.text = prefix + code;
    } else {
      _nom.text = prefix + '-' + numero;
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
              // 2. Type de bien
              DropdownButtonFormField<String>(
                value: _type,
                decoration: _deco('Type de bien'),
                items: ['appartement', 'studio', 'maison', 'loft', 'local commercial']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) {
                  setState(() {
                    _type = v!;
                    if (_type == 'maison') {
                      _etageVal = null;
                      _numero.clear();
                      _nom.text = 'Maison';
                    } else {
                      _autoNom();
                    }
                  });
                },
              ),
              const SizedBox(height: 14),
              // Étage + N° (grisés si maison)
              Row(children: [
                Expanded(
                  child: Opacity(
                    opacity: _type == 'maison' ? 0.4 : 1.0,
                    child: IgnorePointer(
                      ignoring: _type == 'maison',
                      child: DropdownButtonFormField<String?>(
                        value: _type == 'maison' ? null : _etageVal,
                        decoration: _deco('Étage'),
                        hint: const Text('Sélectionner'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('—')),
                          ..._etages.map((e) => DropdownMenuItem(value: e, child: Text(e))),
                        ],
                        onChanged: (v) { setState(() => _etageVal = v); _autoNom(); },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Opacity(
                    opacity: _type == 'maison' ? 0.4 : 1.0,
                    child: IgnorePointer(
                      ignoring: _type == 'maison',
                      child: _Field(
                        ctrl: _numero,
                        label: 'N° appartement',
                        required: false,
                        onChanged: (_) => _autoNom(),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              // Nom auto-généré (modifiable)
              _Field(ctrl: _nom, label: 'Nom du bien', hint: 'Ex : Apt 2B'),
              _Field(ctrl: _adresse, label: 'Adresse'),
              Row(children: [
                Expanded(flex: 2, child: _Field(ctrl: _ville, label: 'Ville')),
                const SizedBox(width: 12),
                Expanded(child: _Field(ctrl: _codePostal, label: 'Code postal')),
              ]),
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
              const Divider(height: 24),
              const Text('Données financières', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _Field(ctrl: _prixAchat, label: "Prix d'achat (€)", keyboard: TextInputType.number, required: false)),
                const SizedBox(width: 12),
                Expanded(child: _Field(ctrl: _taxeFonciere, label: 'Taxe foncière/an (€)', keyboard: TextInputType.number, required: false)),
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
        etage: _etageCode(_etageVal).isNotEmpty ? _etageCode(_etageVal) : null,
        numero: _numero.text.isNotEmpty ? _numero.text : null,
      ));
    } else {
      await widget.data.modifierBien(widget.bien!.copyWith(
        nom: _nom.text, adresse: _adresse.text, ville: _ville.text,
        codePostal: _codePostal.text, type: _type, pieces: _pieces,
        surface: double.tryParse(_surface.text) ?? 0,
        loyerMensuel: double.tryParse(_loyer.text) ?? 0,
        charges: double.tryParse(_charges.text) ?? 0,
        prixAchat: double.tryParse(_prixAchat.text) ?? 0,
        taxeFonciere: double.tryParse(_taxeFonciere.text) ?? 0,
        immeubleId: _immeubleId,
        etage: _etageCode(_etageVal).isNotEmpty ? _etageCode(_etageVal) : null,
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
  final ValueChanged<String>? onChanged;
  const _Field({required this.ctrl, required this.label, this.hint, this.keyboard = TextInputType.text, this.required = true, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        onChanged: onChanged,
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


// ─── FORMULAIRE IMMEUBLE ───────────────────────────────────────────────────

class FormImmeuble extends StatefulWidget {
  final DataService data;
  final Immeuble? immeuble;
  const FormImmeuble({super.key, required this.data, this.immeuble});

  @override
  State<FormImmeuble> createState() => _FormImmeubleState();
}

class _FormImmeubleState extends State<FormImmeuble> {
  final _formKey = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.immeuble?.nom ?? '');
  late final _adresse = TextEditingController(text: widget.immeuble?.adresse ?? '');
  late final _ville = TextEditingController(text: widget.immeuble?.ville ?? '');
  late final _codePostal = TextEditingController(text: widget.immeuble?.codePostal ?? '');
  late int _nbEtages = widget.immeuble?.nbEtages ?? 1;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        expand: false,
        builder: (_, ctrl) => Form(
          key: _formKey,
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              Row(children: [
                const Icon(Icons.apartment, color: AppTheme.blue),
                const SizedBox(width: 8),
                Text(widget.immeuble == null ? 'Ajouter un immeuble' : "Modifier l'immeuble",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 20),
              _Field(ctrl: _nom, label: "Nom de l'immeuble", hint: "Ex : Résidence Les Pins"),
              _Field(ctrl: _adresse, label: 'Adresse'),
              Row(children: [
                Expanded(flex: 2, child: _Field(ctrl: _ville, label: 'Ville')),
                const SizedBox(width: 12),
                Expanded(child: _Field(ctrl: _codePostal, label: 'Code postal')),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Nombre d'étages", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() { if (_nbEtages > 1) _nbEtages--; }),
                  ),
                  Text('$_nbEtages', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _nbEtages++),
                  ),
                ]),
              ]),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.blue, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text(widget.immeuble == null ? 'Ajouter' : 'Enregistrer'),
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
    if (widget.immeuble == null) {
      await widget.data.ajouterImmeuble(widget.data.nouvImmeuble(
        nom: _nom.text, adresse: _adresse.text, ville: _ville.text,
        codePostal: _codePostal.text, nbEtages: _nbEtages,
      ));
    } else {
      await widget.data.modifierImmeuble(widget.immeuble!.copyWith(
        nom: _nom.text, adresse: _adresse.text, ville: _ville.text,
        codePostal: _codePostal.text, nbEtages: _nbEtages,
      ));
    }
    if (mounted) Navigator.pop(context);
  }
}