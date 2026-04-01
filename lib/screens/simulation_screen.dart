import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sheets_service.dart';
import '../main.dart'; // Pour AppTheme

final _euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});
  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  // ── Acquisition ───────────────────────────────────────────────────────────
  final _prixAchat      = TextEditingController();
  final _honoraires     = TextEditingController();
  final _travaux        = TextEditingController();
  final _fraisBancaires = TextEditingController();
  final _apport         = TextEditingController();

  // ── Recettes & Charges ─────────────────────────────────────────────────────
  String _typeBien = 'independant';
  int _nbApparts = 1;
  List<TextEditingController> _loyers = [TextEditingController()];
  final _assurancePno = TextEditingController();
  final _copropriete  = TextEditingController();
  final _taxeFonciere = TextEditingController();

  // ── Emprunt ───────────────────────────────────────────────────────────────
  final _nbAnnees = TextEditingController();
  final _taux     = TextEditingController();
  final _dateDebut = TextEditingController();

  // ── Résultats Sheets ───────────────────────────────────────────────────────
  double? _echeance;          // échéance mensuelle (D10)
  Map<int, double> _interetsParAnnee = {}; // année → somme des intérêts
  Map<int, double> _capitalParAnnee = {};  // année → somme des capitaux
  List<int> _anneesDisponibles = [];       // liste des années (ordonnée)
  int _anneeSelection = 1;   // année sélectionnée (sera mis à jour après calcul)
  bool   _calculEnCours = false;

  double _parse(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  // ── Getters ───────────────────────────────────────────────────────────────
  double get _prixVal         => _parse(_prixAchat);
  double get _honorairesVal   => _parse(_honoraires);
  double get _fraisNotaire    => _prixVal * 0.08;
  double get _travauxVal      => _parse(_travaux);
  double get _fraisBancVal    => _parse(_fraisBancaires);
  double get _apportVal       => _parse(_apport);
  double get _coutAcquisition => _prixVal + _honorairesVal + _fraisNotaire + _fraisBancVal;
  double get _total           => _coutAcquisition + _travauxVal;
  double get _credit          => (_total - _apportVal).clamp(0, double.infinity);

  int    get _nbAnneesVal     => _parse(_nbAnnees).toInt();
  double get _tauxVal         => _parse(_taux);
  int    get _amortissement   => (_nbAnneesVal * 12);

  // Retourne les intérêts pour l'année sélectionnée (déjà calculés depuis Sheets)
  double _interetsAnnee() {
    return _interetsParAnnee[_anneeSelection] ?? 0;
  }

  // Retourne le capital remboursé pour l'année sélectionnée
  double _capitalAnnee() {
    return _capitalParAnnee[_anneeSelection] ?? 0;
  }

  // ── Méthodes ──────────────────────────────────────────────────────────────
  void _updateNbApparts(int nb) {
    setState(() {
      _nbApparts = nb;
      if (nb > _loyers.length) {
        for (int i = _loyers.length; i < nb; i++) {
          _loyers.add(TextEditingController());
        }
      } else {
        for (int i = nb; i < _loyers.length; i++) {
          _loyers[i].dispose();
        }
        _loyers = _loyers.sublist(0, nb);
      }
    });
  }

  Future<void> _calculerComplet() async {
    if (_prixVal <= 0 || _nbAnneesVal <= 0 || _tauxVal <= 0) return;

    setState(() {
      _calculEnCours = true;
      _echeance = null;
      _interetsParAnnee = {};
      _capitalParAnnee = {};
      _anneesDisponibles = [];
    });

    try {
      final sheets = SheetsService();

      // 1) Écriture des loyers (J2-J10) et charges (J11-J13) dans l'onglet "Emprunt"
      List<Future<bool>> writes = [];
      debugPrint('=== Écriture Loyers dans Emprunt ===');
      // Toujours écrire 9 cellules (J2 à J10) : valeurs saisies ou 0 si non renseigné
      for (int i = 0; i < 9; i++) {
        double val = (i < _loyers.length) ? _parse(_loyers[i]) : 0;
        debugPrint('Loyer Appart ${i + 1}: $val → J${i + 2}');
        writes.add(sheets.writeCell('Emprunt', 'J${i + 2}', val));
      }
      debugPrint('Charges:');
      debugPrint('Assurance PNO: ${_parse(_assurancePno)} → J11');
      writes.add(sheets.writeCell('Emprunt', 'J11', _parse(_assurancePno)));
      debugPrint('Copropriété: ${_parse(_copropriete)} → J12');
      writes.add(sheets.writeCell('Emprunt', 'J12', _parse(_copropriete)));
      debugPrint('Taxe foncière: ${_parse(_taxeFonciere)} → J13');
      writes.add(sheets.writeCell('Emprunt', 'J13', _parse(_taxeFonciere)));

      // 2) Écriture des paramètres emprunt dans l'onglet "Emprunt"
      writes.addAll([
        sheets.writeCell('Emprunt', 'C4', _prixVal),  // Prix d'achat seul
        sheets.writeCell('Emprunt', 'C5', _travauxVal), // Travaux seul
        sheets.writeCell('Emprunt', 'C6', _amortissement.toDouble()),
        sheets.writeCell('Emprunt', 'C7', _nbAnneesVal.toDouble()),
        sheets.writeCell('Emprunt', 'F3', _tauxVal / 100),
        sheets.writeCell('Emprunt', 'B10', _dateDebut.text),
      ]);

      final writeResults = await Future.wait(writes);
      debugPrint('Résultats écriture loyers/charges: $writeResults');

      // 3) Attendre le recalcul Sheets (réduit pour améliorer performance)
      await Future.delayed(const Duration(milliseconds: 1000)); // 1 seconde au lieu de 2

      // 4) Lire les résultats emprunt (D10 = échéance)
      final echeance = await sheets.readCell('Emprunt', 'D10');
      debugPrint('Lecture D10 (échéance): $echeance');

      // 5) Lire tous les capitaux (colonne E) et intérêts (colonne F) pour regroupement par année
      Map<int, double> interetsParAnnee = {};
      Map<int, double> capitalParAnnee = {};
      List<int> anneesDisponibles = [];
      if (_amortissement > 0) {
        debugPrint('Amortissement: $_amortissement mois');
        debugPrint('Date début saisie: ${_dateDebut.text}');

        // Parser la date de début au format "MM-AAAA" ou "MM/AAAA"
        DateTime? dateDebut;
        try {
          String dateStr = _dateDebut.text.trim();
          List<String> parts;
          if (dateStr.contains('/')) {
            parts = dateStr.split('/');
          } else if (dateStr.contains('-')) {
            parts = dateStr.split('-');
          } else {
            parts = [dateStr];
          }
          if (parts.length == 2) {
            final mois = int.parse(parts[0]);
            final annee = int.parse(parts[1]);
            dateDebut = DateTime(annee, mois, 1);
            debugPrint('Date début parsée: $dateDebut');
          } else {
            debugPrint('Format date non reconnu: $dateStr');
          }
        } catch (e) {
          debugPrint('Erreur parsing date début: $e');
        }

        if (dateDebut != null) {
          // Lire TOUTES les données capital/intérêts en UN SEUL appel via readRange
          // Cela évite les quotas Google et réduit le temps de 100s à ~2-3s
          final moisAConsulter = _amortissement.clamp(0, 360);
          if (moisAConsulter == 0) {
            debugPrint('Aucun mois à consulter');
            return;
          }

          debugPrint('Lecture plage E10:F${9 + moisAConsulter} (${moisAConsulter} mois)');

          // Lire la plage complète E10:F[dernière ligne]
          final rangeData = await sheets.readRange('Emprunt', 'E10:F${9 + moisAConsulter}');
          debugPrint('Données lues: ${rangeData.length} lignes');

          if (rangeData.isEmpty) {
            debugPrint('Aucune donnée reçue depuis Sheets');
            return;
          }

          // Extraire les colonnes capital (E) et intérêts (F)
          List<double> capitaux = [];
          List<double> interets = [];

          for (int i = 0; i < rangeData.length && i < moisAConsulter; i++) {
            final row = rangeData[i];
            if (row.length >= 2) {
              final cap = double.tryParse(row[0]?.toString() ?? '');
              final intt = double.tryParse(row[1]?.toString() ?? '');
              capitaux.add(cap ?? 0);
              interets.add(intt ?? 0);
            } else {
              capitaux.add(0);
              interets.add(0);
            }
          }

          debugPrint('Extraction: ${capitaux.length} capitaux, ${interets.length} intérêts');

          // Regrouper par année
          for (int i = 0; i < interets.length; i++) {
            final dateMois = DateTime(dateDebut.year, dateDebut.month + i, 1);
            final annee = dateMois.year;
            if (interets[i] != null) {
              interetsParAnnee[annee] = (interetsParAnnee[annee] ?? 0) + interets[i]!;
            }
            if (capitaux[i] != null) {
              capitalParAnnee[annee] = (capitalParAnnee[annee] ?? 0) + capitaux[i]!;
            }
          }
          anneesDisponibles = interetsParAnnee.keys.toList()..sort();
          debugPrint('Années trouvées: $anneesDisponibles');
          debugPrint('Intérêts par année: $interetsParAnnee');
          debugPrint('Capital par année: $capitalParAnnee');
        } else {
          debugPrint('Date de début invalide ou manquante');
        }
      }

      if (mounted) {
        setState(() {
          _echeance = echeance;
          _interetsParAnnee = interetsParAnnee;
          _capitalParAnnee = capitalParAnnee;
          _anneesDisponibles = anneesDisponibles;
          _anneeSelection = anneesDisponibles.isNotEmpty ? anneesDisponibles.first : 1;
          _calculEnCours = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Erreur calcul complet: $e');
      debugPrint('Stack trace: $stack');
      if (mounted) {
        setState(() {
          _calculEnCours = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Acquisition
    _prixAchat.dispose();
    _honoraires.dispose();
    _travaux.dispose();
    _fraisBancaires.dispose();
    _apport.dispose();
    // Recettes & Charges
    for (final c in _loyers) c.dispose();
    _assurancePno.dispose();
    _copropriete.dispose();
    _taxeFonciere.dispose();
    // Emprunt
    _nbAnnees.dispose();
    _taux.dispose();
    _dateDebut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Simulation d\'acquisition', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),

        // ── Section Acquisition ──────────────────────────────────────────────
        const Text('Acquisition', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _Champ(label: 'Prix d\'achat',       controller: _prixAchat,      onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _Champ(label: 'Honoraires agence',   controller: _honoraires,     onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _LigneCalculee(label: 'Frais de notaire (8%)', valeur: _fraisNotaire, actif: _prixVal > 0),
        const SizedBox(height: 12),
        _Champ(label: 'Frais bancaires',     controller: _fraisBancaires, onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _Champ(label: 'Travaux',             controller: _travaux,        onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        _Champ(label: 'Apport',              controller: _apport,         onChanged: (_) => setState(() {})),
        const SizedBox(height: 16),

        // ── Récapitulatif acquisition ─────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(children: [
            _Ligne('Prix d\'achat',         _prixVal),
            if (_honorairesVal > 0)     _Ligne('Honoraires agence',       _honorairesVal),
            if (_fraisNotaire > 0)      _Ligne('Frais de notaire (8%)',   _fraisNotaire),
            if (_fraisBancVal > 0)      _Ligne('Frais bancaires',         _fraisBancVal),
            if (_travauxVal > 0)        _Ligne('Travaux',                 _travauxVal),
            const Divider(height: 16),
            _Ligne('Coût total',          _total,  gras: true),
            if (_apportVal > 0)          _Ligne('Apport',                  _apportVal),
            if (_apportVal > 0)          _Ligne('Crédit nécessaire',       _credit, gras: true, couleur: const Color(0xFF0D47A1)),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Section Recettes & Charges ────────────────────────────────────────
        _RecettesChargesSection(
          typeBien: _typeBien,
          nbApparts: _nbApparts,
          loyers: _loyers,
          assurancePno: _assurancePno,
          copropriete: _copropriete,
          taxeFonciere: _taxeFonciere,
          onTypeBienChanged: (v) => setState(() { _typeBien = v; if (v == 'independant') _updateNbApparts(1); }),
          onNbAppartsChanged: _updateNbApparts,
        ),

        // ── Section Emprunt ────────────────────────────────────────────────────
        const Text('Paramètres d\'emprunt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        _Champ(label: 'Nombre d\'années', controller: _nbAnnees, onChanged: (_) => setState(() {}), suffix: 'ans'),
        const SizedBox(height: 12),
        _LigneCalculee(
          label: 'Amortissement',
          valeur: _amortissement.toDouble(),
          actif: _nbAnneesVal > 0,
          suffix: 'mois',
        ),
        const SizedBox(height: 12),
        _Champ(label: 'Taux d\'emprunt', controller: _taux, onChanged: (_) => setState(() {}), suffix: '%'),
        const SizedBox(height: 12),
        _Champ(label: 'Date début emprunt (MM-AAAA)', controller: _dateDebut, onChanged: (_) => setState(() {}), suffix: ''),
        const SizedBox(height: 20),

        // ── Bouton calculer ────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _peutCalculer && !_calculEnCours ? _calculerComplet : null,
            icon: _calculEnCours
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.calculate_outlined),
            label: Text(_calculEnCours ? 'Calcul en cours...' : 'Calculer depuis Sheets'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Résultats Emprunt ───────────────────────────────────────────────────
        if (_echeance != null) ...[
          const Text('Résultats emprunt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),

          // Navigation des années (slider centré avec marqueurs)
          if (_anneesDisponibles.length > 1)
            Column(
              children: [
                // Slider horizontal
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: AppTheme.primary,
                    inactiveTrackColor: Colors.grey[700],
                    thumbColor: Colors.white,
                    overlayColor: AppTheme.primary.withValues(alpha: 0.2),
                    tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
                    tickMarkColor: Colors.grey[600],
                    showValueIndicator: ShowValueIndicator.never,
                  ),
                  child: Slider(
                    value: _anneesDisponibles.indexOf(_anneeSelection).toDouble(),
                    min: 0,
                    max: (_anneesDisponibles.length - 1).toDouble(),
                    divisions: _anneesDisponibles.length - 1,
                    onChanged: (value) {
                      setState(() {
                        _anneeSelection = _anneesDisponibles[value.toInt()];
                      });
                    },
                  ),
                ),
                // Marqueurs d'années (labels sous le slider)
                SizedBox(
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ..._anneesDisponibles.map((annee) {
                        // Afficher seulement certaines années si trop nombreuses
                        final shouldShow = _anneesDisponibles.length <= 10 ||
                            annee % 5 == 0 ||
                            annee == _anneesDisponibles.first ||
                            annee == _anneesDisponibles.last;
                        if (!shouldShow) return const SizedBox.shrink();
                        final isSelected = annee == _anneeSelection;
                        return Expanded(
                          child: Text(
                            annee.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? AppTheme.primary : Colors.grey[600],
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                // Label de l'année sélectionnée (centré)
                const SizedBox(height: 8),
                Text(
                  'Année $_anneeSelection',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              _BlocResultat(
                label: 'Intérêts Emprunt annuelle',
                sousTitre: 'Année $_anneeSelection',
                valeur: _interetsAnnee(),
                couleur: const Color(0xFFEF5350),
              ),
              const Divider(color: Colors.white24, height: 28),
              _BlocResultat(
                label: 'Capital remboursé annuel',
                sousTitre: 'Année $_anneeSelection',
                valeur: _capitalAnnee(),
                couleur: const Color(0xFF4CAF50),
              ),
              const Divider(color: Colors.white24, height: 28),
              _BlocResultat(
                label: 'Échéance mensuelle',
                sousTitre: 'Constante sur toute la durée',
                valeur: _echeance ?? 0,
                couleur: Colors.white,
                grand: true,
              ),
            ]),
          ),
          const SizedBox(height: 32),
        ],
      ]),
    );
  }

  bool get _peutCalculer => _prixVal > 0 && _nbAnneesVal > 0 && _tauxVal > 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _Champ extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String suffix;
  const _Champ({required this.label, required this.controller, required this.onChanged, this.suffix = '€'});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _LigneCalculee extends StatelessWidget {
  final String label;
  final double valeur;
  final bool actif;
  final String suffix;
  const _LigneCalculee({required this.label, required this.valeur, required this.actif, this.suffix = '€'});

  @override
  Widget build(BuildContext context) {
    final formatSansDevise = NumberFormat.decimalPattern('fr_FR');
    String displayText;
    if (suffix == '€') {
      displayText = _euro.format(valeur);
    } else {
      displayText = formatSansDevise.format(valeur);
      if (suffix.isNotEmpty) displayText += ' $suffix';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14))),
        Text(
          actif ? displayText : '—',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: actif ? const Color(0xFF1B5E20) : Colors.grey,
          ),
        ),
      ]),
    );
  }
}

class _BlocResultat extends StatelessWidget {
  final String label;
  final String sousTitre;
  final double valeur;
  final Color couleur;
  final bool grand;
  const _BlocResultat({
    required this.label, required this.sousTitre,
    required this.valeur, required this.couleur, this.grand = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.white, fontSize: grand ? 14 : 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(sousTitre, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ])),
      Text(
        _euro.format(valeur),
        style: TextStyle(color: couleur, fontSize: grand ? 20 : 16, fontWeight: FontWeight.w700),
      ),
    ]);
  }
}

class _Ligne extends StatelessWidget {
  final String label;
  final double valeur;
  final bool gras;
  final Color? couleur;
  const _Ligne(this.label, this.valeur, {this.gras = false, this.couleur});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(
          color: couleur ?? Colors.grey[700],
          fontSize: 13,
          fontWeight: gras ? FontWeight.w700 : FontWeight.normal,
        ))),
        Text(_euro.format(valeur), style: TextStyle(
          fontSize: 13,
          fontWeight: gras ? FontWeight.w700 : FontWeight.normal,
          color: couleur,
        )),
      ]),
    );
  }
}

class _SimTypeBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SimTypeBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1565C0).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? const Color(0xFF1565C0) : Colors.grey[300]!),
        ),
        child: Center(child: Text(label, style: TextStyle(
          fontWeight: FontWeight.w500,
          color: active ? const Color(0xFF1565C0) : Colors.grey[600],
        ))),
      ),
    );
  }
}

class _RecettesChargesSection extends StatelessWidget {
  final String typeBien;
  final int nbApparts;
  final List<TextEditingController> loyers;
  final TextEditingController assurancePno;
  final TextEditingController copropriete;
  final TextEditingController taxeFonciere;
  final ValueChanged<String> onTypeBienChanged;
  final ValueChanged<int> onNbAppartsChanged;

  const _RecettesChargesSection({
    required this.typeBien,
    required this.nbApparts,
    required this.loyers,
    required this.assurancePno,
    required this.copropriete,
    required this.taxeFonciere,
    required this.onTypeBienChanged,
    required this.onNbAppartsChanged,
  });

  double _parse(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
  double get _totalLoyers => loyers.fold(0, (s, c) => s + _parse(c));
  double get _totalCharges => (_parse(assurancePno) + _parse(copropriete) + _parse(taxeFonciere)) / 12;
  double get _cashflow => _totalLoyers - _totalCharges;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Recettes & Charges', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 16),

      // ── Type de bien ──
      Row(children: [
        Expanded(child: _SimTypeBtn(
          label: 'Indépendant', active: typeBien == 'independant',
          onTap: () => onTypeBienChanged('independant'),
        )),
        const SizedBox(width: 10),
        Expanded(child: _SimTypeBtn(
          label: 'Immeuble', active: typeBien == 'immeuble',
          onTap: () => onTypeBienChanged('immeuble'),
        )),
      ]),
      const SizedBox(height: 16),

      // ── Nombre d'appartements ──
      if (typeBien == 'immeuble') ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Expanded(child: Text('Nombre d\'appartements', style: TextStyle(fontSize: 14))),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              onPressed: nbApparts > 1 ? () => onNbAppartsChanged(nbApparts - 1) : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('$nbApparts', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              onPressed: () => onNbAppartsChanged(nbApparts + 1),
            ),
          ]),
        ),
        const SizedBox(height: 12),
      ],

      // ── Loyers ──
      for (int i = 0; i < loyers.length; i++) ...[
        _Champ(
          label: typeBien == 'immeuble' ? 'Loyer Appartement ${i + 1}' : 'Loyer mensuel',
          controller: loyers[i],
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
      ],

      // ── Charges annuelles ──
      _Champ(label: 'Assurance PNO (annuelle)',   controller: assurancePno,  onChanged: (_) => {}),
      const SizedBox(height: 12),
      if (typeBien == 'immeuble') ...[
        _Champ(label: 'Copropriété (annuelle)',   controller: copropriete,   onChanged: (_) => {}),
        const SizedBox(height: 12),
      ],
      _Champ(label: 'Taxe foncière (annuelle)',   controller: taxeFonciere,  onChanged: (_) => {}),
      const SizedBox(height: 24),

      // ── Résultats ──
      if (_totalLoyers > 0 || _totalCharges > 0) Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          _BlocResultat(
            label: 'Recettes mensuelles',
            sousTitre: typeBien == 'immeuble' ? '${loyers.length} appartement(s)' : 'Loyer mensuel',
            valeur: _totalLoyers,
            couleur: const Color(0xFF4CAF50),
          ),
          const Divider(color: Colors.white24, height: 28),
          _BlocResultat(
            label: 'Charges mensuelles',
            sousTitre: 'Charges annuelles ÷ 12',
            valeur: _totalCharges,
            couleur: const Color(0xFFEF5350),
          ),
          const Divider(color: Colors.white24, height: 28),
          _BlocResultat(
            label: 'Cash-flow',
            sousTitre: 'Recettes - Charges',
            valeur: _cashflow,
            couleur: Colors.white,
            grand: true,
          ),
        ]),
      ),
      const SizedBox(height: 32),
    ]);
  }
}
