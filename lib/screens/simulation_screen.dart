import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import '../services/sheets_service.dart';
import '../services/pdf_service.dart';
import '../services/simulation_save_service.dart';
import '../main.dart' show AppTheme;

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

  // Date de début d'emprunt parsée
  DateTime? _dateDebutEmprunt;

  // ── Recettes & Charges ─────────────────────────────────────────────────────
  String _typeBien = 'independant';
  int _nbApparts = 1;
  List<TextEditingController> _loyers = [TextEditingController()];
  final _assurancePno = TextEditingController();
  final _copropriete  = TextEditingController();
  final _taxeFonciere = TextEditingController();

  // ── Emprunt ───────────────────────────────────────────────────────────────
  final _nbAnnees  = TextEditingController();
  final _taux      = TextEditingController();
  final _dateDebut = TextEditingController();

  // ── Simulation Rapide ────────────────────────────────────────────────────
  final _rPrix        = TextEditingController();
  final _rTravaux     = TextEditingController();
  final _rLoyer       = TextEditingController();
  final _rTaxe        = TextEditingController();

  double _rParse(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  // ── Résultats Sheets ───────────────────────────────────────────────────────
  double? _echeance;                          // échéance mensuelle (D10)
  bool _calculEnCours = false;

  // ── Tableau résultats par année ────────────────────────────────────────────
  List<int> _anneesTable  = [];   // 10 premières années (affichage)
  List<int> _toutesAnnees = [];   // toutes les années (PDF)
  Map<String, List<double>> _resultatsTable = {};

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

  // --- Getters pour cash-flow ---
  double get _totalLoyers {
    double sum = 0;
    for (final c in _loyers) {
      sum += double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
    }
    return sum;
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
      _anneesTable = [];
      _resultatsTable = {};
    });

    try {
      final sheets = SheetsService();

      // 1) Écriture initiale en 4 writeRange parallèles
      final List<List<dynamic>> loyerRows = [
        ...List.generate(9, (i) => [(i < _loyers.length) ? _parse(_loyers[i]) : 0.0]),
        [_parse(_assurancePno)], [_parse(_copropriete)], [_parse(_taxeFonciere)],
      ];
      await Future.wait([
        sheets.writeRange('Emprunt', 'J2:J13', loyerRows),
        sheets.writeRange('Emprunt', 'C2:C5', [[_prixVal], [_travauxVal], [0], [_fraisNotaire]]),
        sheets.writeRange('Emprunt', 'F2:F6', [[_fraisBancVal], [0], [_tauxVal / 100], [_amortissement], [_nbAnneesVal]]),
        sheets.writeCell('Emprunt', 'B10', _dateDebut.text),
      ]);

      // 3) Attendre le recalcul Sheets
      await Future.delayed(const Duration(milliseconds: 500));

      // 4) Lire les résultats emprunt (D10 = échéance)
      final echeance = await sheets.readCell('Emprunt', 'D10');
      debugPrint('Lecture D10 (échéance): $echeance');

      // 5) Parser la date de début et calculer les années + lire E10:F{n}
      List<int> anneesDisponibles = [];
      DateTime? dateDebut;
      if (_amortissement > 0) {
        try {
          String dateStr = _dateDebut.text.trim();
          List<String> parts = dateStr.contains('/') ? dateStr.split('/') : dateStr.split('-');
          if (parts.length == 2) {
            dateDebut = DateTime(int.parse(parts[1]), int.parse(parts[0]), 1);
            _dateDebutEmprunt = dateDebut;
            // Calculer directement les années depuis date début + amortissement
            final Set<int> anneesSet = {};
            for (int i = 0; i < _amortissement; i++) {
              anneesSet.add(DateTime(dateDebut.year, dateDebut.month + i, 1).year);
            }
            anneesDisponibles = anneesSet.toList()..sort();
            debugPrint('Années calculées: $anneesDisponibles');
          }
        } catch (e) {
          debugPrint('Erreur parsing date début: $e');
        }

      }

      if (mounted) {
        setState(() {
          _echeance = echeance;
        });

        // Écrire le tableau récapitulatif dans l'onglet Emprunt (disposition horizontale)
        if (anneesDisponibles.isNotEmpty && _dateDebutEmprunt != null) {
          final int nbAnsSheet   = anneesDisponibles.length;        // toutes les années → sheet
          final int nbAns        = min(10, nbAnsSheet);              // 10 max → affichage
          final String eCol      = _colLetter(nbAnsSheet + 1);       // dernière colonne sheet

          // Toujours écrire jusqu'à la colonne AH (34 cols = label + 33 ans max)
          // Les colonnes au-delà de nbAnsSheet sont remplies de '' → écrase les résidus
          const int maxCols = 33; // max années supportées (colonne AH)
          List<dynamic> rowPad(String label, List<dynamic> vals) => [
            label,
            ...vals,
            ...List.filled(max(0, maxCols - vals.length), ''),
          ];

          // Précalcul des listes (réutilisées dans writes ET tableData)
          final loyerSans = List.generate(nbAnsSheet, (i) {
            final m = _calculerMoisActifsAnnee(anneesDisponibles[i], _dateDebutEmprunt!, _amortissement);
            return _totalLoyers * m;
          });
          final loyerAvec = List.generate(nbAnsSheet, (i) {
            final annee = anneesDisponibles[i];
            final m = _calculerMoisActifsAnnee(annee, _dateDebutEmprunt!, _amortissement);
            return _totalLoyers * m * pow(1.03, (annee - _dateDebutEmprunt!.year) ~/ 6);
          });

          // ── Batch 1 (parallèle) — range fixe A:AH écrase les résidus ──────────
          await Future.wait([
            sheets.writeRange('Emprunt', 'A314:AH314', [rowPad('Année',
              List.generate(nbAnsSheet, (i) => anneesDisponibles[i]))]),
            sheets.writeRange('Emprunt', 'A315:A318', [
              ['Intérêts par année'], ['Capital emprunt'], ['Échéance'], ['Capital remboursé'],
            ]),
            sheets.writeRange('Emprunt', 'A321:AH321', [rowPad('Loyer annuel sans augmentation', loyerSans)]),
            sheets.writeRange('Emprunt', 'A322:AH322', [rowPad('Loyer annuel avec augmentation', loyerAvec)]),
          ]);
          await Future.delayed(const Duration(milliseconds: 250));

          // ── Batch 2 (parallèle) — range fixe A:AH écrase les résidus ──────────
          await Future.wait([
            sheets.writeCell('Emprunt', 'A323', 'Résultat d\'exploitation'),
            sheets.writeRange('Emprunt', 'A324:AH324', [rowPad('Frais bancaire',
              List.generate(nbAnsSheet, (i) => anneesDisponibles[i] - _dateDebutEmprunt!.year == 0 ? _fraisBancVal : 0.0))]),
            sheets.writeRange('Emprunt', 'A325:AH325', [rowPad('Frais de notaire',
              List.generate(nbAnsSheet, (i) => anneesDisponibles[i] - _dateDebutEmprunt!.year == 0 ? _fraisNotaire : 0.0))]),
            sheets.writeRange('Emprunt', 'A326:AH326', [rowPad('Assurance PNO',
              List.generate(nbAnsSheet, (i) {
                final annee = anneesDisponibles[i];
                final m = _calculerMoisActifsAnnee(annee, _dateDebutEmprunt!, _amortissement);
                return _parse(_assurancePno) * pow(1.02, annee - _dateDebutEmprunt!.year) * (m / 12);
              }))]),
            sheets.writeRange('Emprunt', 'A327:AH327', [rowPad('Taxe Foncière',
              List.generate(nbAnsSheet, (i) {
                final annee = anneesDisponibles[i];
                final m = _calculerMoisActifsAnnee(annee, _dateDebutEmprunt!, _amortissement);
                return _parse(_taxeFonciere) * pow(1.02, annee - _dateDebutEmprunt!.year) * (m / 12);
              }))]),
            sheets.writeRange('Emprunt', 'A328:AH328', [rowPad('Travaux',
              List.generate(nbAnsSheet, (i) => anneesDisponibles[i] - _dateDebutEmprunt!.year == 0 ? _travauxVal : 0.0))]),
            sheets.writeRange('Emprunt', 'A329:A338', [
              ['Résultat d\'exploitation net'],
              ['Déficit Reportable (Imput. 1ère année)'],
              ['Résultat Fiscal'],
              ['Prélèvements Sociaux (17,2%)'],
              ['Impôts (TMI 30%)'],
              ['CAF (Hors travaux)'],
              ['CAF Nette (CAF-Capital emprunt)'],
              ['Taux de Rentabilité Brut'],
              ['Taux de Rentabilité Nette'],
              ['Impact capacité d\'emprunt'],
            ]),
          ]);

          debugPrint('Tableau récapitulatif envoyé (range fixe A:AH, résidus écrasés)');

          // Attendre que Sheets recalcule les formules
          await Future.delayed(const Duration(milliseconds: 1000));

          // Lire B315:{eCol}338 — toutes les années (pas seulement les 10 premières)
          final readData = await sheets.readRange('Emprunt', 'B315:${eCol}338');
          debugPrint('Données tableau résultats: ${readData.length} lignes, ${readData.isNotEmpty ? readData[0].length : 0} colonnes lues');

          // Helper : extraire une ligne de readData (index 0 = ligne 315)
          List<double> parseRow(int rowIdx) {
            if (rowIdx >= readData.length) return List.filled(nbAnsSheet, 0.0);
            final row = readData[rowIdx];
            return List.generate(nbAnsSheet, (i) {
              if (i >= row.length) return 0.0;
              return double.tryParse(row[i]?.toString() ?? '') ?? 0.0;
            });
          }

          // Indices dans readData (B315:K338): index = numéro de ligne - 315
          final Map<String, List<double>> tableData = {
            'interets'            : parseRow(0),   // ligne 315
            'capitalEmprunt'      : parseRow(1),   // ligne 316
            'echeance'            : parseRow(2),   // ligne 317
            'capitalRembourse'    : parseRow(3),   // ligne 318
            'loyer'               : loyerAvec.map((v) => v.toDouble()).toList(),
            'resultatExploitation': parseRow(8),   // ligne 323
            'fraisBancaire'       : List.generate(nbAnsSheet, (i) => anneesDisponibles[i] - _dateDebutEmprunt!.year == 0 ? _fraisBancVal : 0.0),
            'fraisNotaire'        : List.generate(nbAnsSheet, (i) => anneesDisponibles[i] - _dateDebutEmprunt!.year == 0 ? _fraisNotaire : 0.0),
            'assurancePno'        : List.generate(nbAnsSheet, (i) {
              final annee = anneesDisponibles[i];
              final m = _calculerMoisActifsAnnee(annee, _dateDebutEmprunt!, _amortissement);
              return _parse(_assurancePno) * pow(1.02, annee - _dateDebutEmprunt!.year) * (m / 12);
            }),
            'taxeFonciere'        : List.generate(nbAnsSheet, (i) {
              final annee = anneesDisponibles[i];
              final m = _calculerMoisActifsAnnee(annee, _dateDebutEmprunt!, _amortissement);
              return _parse(_taxeFonciere) * pow(1.02, annee - _dateDebutEmprunt!.year) * (m / 12);
            }),
            'travaux'             : List.generate(nbAnsSheet, (i) => anneesDisponibles[i] - _dateDebutEmprunt!.year == 0 ? _travauxVal : 0.0),
            'resultatNet'         : parseRow(14),  // ligne 329
            'deficitReportable'   : parseRow(15),  // ligne 330
            'resultatFiscal'      : parseRow(16),  // ligne 331
            'prelevementsSociaux' : parseRow(17),  // ligne 332
            'impots'              : parseRow(18),  // ligne 333
            'cafHorsTravaux'      : parseRow(19),  // ligne 334
            'cafNette'            : parseRow(20),  // ligne 335
            'tauxRentaBrut'       : parseRow(21),  // ligne 336
            'tauxRentaNet'        : parseRow(22),  // ligne 337
            'impactCapacite'      : parseRow(23),  // ligne 338
          };

          if (mounted) {
            setState(() {
              _anneesTable    = anneesDisponibles.take(nbAns).toList();
              _toutesAnnees   = anneesDisponibles;
              _resultatsTable = tableData;
              _calculEnCours  = false;
            });
          }
        } else {
          if (mounted) setState(() { _calculEnCours = false; });
        }
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

  void _reinitialiserFormulaire() {
    setState(() {
      // Champs de saisie
      for (final c in [_prixAchat, _honoraires, _travaux, _fraisBancaires, _apport,
                        _assurancePno, _copropriete, _taxeFonciere,
                        _nbAnnees, _taux, _dateDebut]) {
        c.clear();
      }
      for (final c in _loyers) c.clear();
      // Type de bien
      _typeBien = 'independant';
      _updateNbApparts(1);
      // Résultats
      _echeance       = null;
      _anneesTable    = [];
      _toutesAnnees   = [];
      _resultatsTable = {};
    });
  }

  // Formate un double en string sans décimales inutiles
  String _fmtNum(dynamic v) {
    final d = (v as num).toDouble();
    return d == d.truncateToDouble() ? d.toInt().toString() : d.toString();
  }

  Future<void> _sauvegarderSimulation() async {
    if (_toutesAnnees.isEmpty || _resultatsTable.isEmpty) return;

    final nomCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sauvegarder la simulation'),
        content: TextField(
          controller: nomCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nom de la simulation',
            hintText: 'Ex: Appart Lyon Centre',
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sauvegarder')),
        ],
      ),
    );

    if (confirmed != true || nomCtrl.text.trim().isEmpty) return;

    try {
      await SimulationSaveService.sauvegarder(
        nom: nomCtrl.text.trim(),
        params: {
          'prixAchat': _prixVal, 'honoraires': _honorairesVal,
          'travaux': _travauxVal, 'fraisBancaires': _fraisBancVal,
          'apport': _apportVal, 'typeBien': _typeBien,
          'nbApparts': _nbApparts,
          'loyers': _loyers.map(_parse).toList(),
          'assurancePno': _parse(_assurancePno), 'copropriete': _parse(_copropriete),
          'taxeFonciere': _parse(_taxeFonciere), 'nbAnnees': _nbAnneesVal,
          'taux': _tauxVal, 'dateDebut': _dateDebut.text,
        },
        echeance:  _echeance ?? 0,
        annees:    _toutesAnnees,
        resultats: _resultatsTable,
      );
      if (mounted) {
        _reinitialiserFormulaire();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Simulation sauvegardée — formulaire réinitialisé'),
          backgroundColor: Color(0xFF2E7D32),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _ouvrirMesSimulations() async {
    // Charger local immédiatement
    final sims = await SimulationSaveService.lister();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _MesSimulationsSheet(
        simulations: sims,
        onCharger: (sim) { Navigator.pop(ctx); _chargerSimulation(sim); },
        onSupprimer: SimulationSaveService.supprimer,
      ),
    );

    // Sync Drive en arrière-plan (met à jour si le sheet se rouvre)
    SimulationSaveService.syncFromDrive();
  }

  void _chargerSimulation(SimulationComplete sim) {
    final p = sim.params;
    final nb = (p['nbApparts'] as num).toInt();
    _updateNbApparts(nb);
    final loys = (p['loyers'] as List).map((e) => (e as num).toDouble()).toList();
    setState(() {
      _prixAchat.text      = _fmtNum(p['prixAchat']);
      _honoraires.text     = _fmtNum(p['honoraires']);
      _travaux.text        = _fmtNum(p['travaux']);
      _fraisBancaires.text = _fmtNum(p['fraisBancaires']);
      _apport.text         = _fmtNum(p['apport']);
      _typeBien            = p['typeBien'] as String;
      for (int i = 0; i < _loyers.length && i < loys.length; i++) {
        _loyers[i].text = _fmtNum(loys[i]);
      }
      _assurancePno.text   = _fmtNum(p['assurancePno']);
      _copropriete.text    = _fmtNum(p['copropriete']);
      _taxeFonciere.text   = _fmtNum(p['taxeFonciere']);
      _nbAnnees.text       = (p['nbAnnees'] as num).toInt().toString();
      _taux.text           = _fmtNum(p['taux']);
      _dateDebut.text      = p['dateDebut'] as String;
      _echeance            = sim.echeance;
      _toutesAnnees        = sim.annees;
      _anneesTable         = sim.annees.take(10).toList();
      _resultatsTable      = sim.resultats;
    });
  }

  Future<void> _exporterPdf() async {
    if (_toutesAnnees.isEmpty || _resultatsTable.isEmpty) return;
    try {
      final bytes = await PdfService.genererSimulation(
        prixAchat       : _prixVal,
        honoraires      : _honorairesVal,
        travaux         : _travauxVal,
        fraisBancaires  : _fraisBancVal,
        apport          : _apportVal,
        fraisNotaire    : _fraisNotaire,
        coutAcquisition : _coutAcquisition,
        montantEmprunt  : _credit,
        typeBien        : _typeBien,
        nbApparts       : _nbApparts,
        loyers          : _loyers.map(_parse).toList(),
        assurancePno    : _parse(_assurancePno),
        copropriete     : _parse(_copropriete),
        taxeFonciere    : _parse(_taxeFonciere),
        nbAnnees        : _nbAnneesVal,
        taux            : _tauxVal,
        dateDebut       : _dateDebut.text,
        amortissement   : _amortissement,
        echeance        : _echeance ?? 0,
        annees          : _toutesAnnees,
        resultats       : _resultatsTable,
      );
      await Printing.sharePdf(bytes: bytes, filename: 'Simulation_${DateTime.now().year}.pdf');
    } catch (e) {
      debugPrint('Erreur export PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Calcule le nombre de mois actifs pour une année donnée
  int _calculerMoisActifsAnnee(int annee, DateTime dateDebut, int totalMois) {
    final moisDebut = dateDebut.month;
    final anneeDebut = dateDebut.year;
    final int moisFin = moisDebut + totalMois - 1;
    int anneeFin = anneeDebut + (moisFin ~/ 12);
    int moisFinAjuste = moisFin % 12;
    if (moisFinAjuste == 0) {
      moisFinAjuste = 12;
      anneeFin--;
    }
    if (annee < anneeDebut || annee > anneeFin) return 0;
    int debutMoisDansAnnee = (annee == anneeDebut) ? moisDebut : 1;
    int finMoisDansAnnee   = (annee == anneeFin)   ? moisFinAjuste : 12;
    return finMoisDansAnnee - debutMoisDansAnnee + 1;
  }

  // Convertit un index de colonne (1=A, 2=B, 27=AA, …) en lettre Excel
  String _colLetter(int col) {
    String result = '';
    while (col > 0) {
      col--;
      result = String.fromCharCode('A'.codeUnitAt(0) + (col % 26)) + result;
      col ~/= 26;
    }
    return result;
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
    // Simulation Rapide
    _rPrix.dispose();
    _rTravaux.dispose();
    _rLoyer.dispose();
    _rTaxe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Simulation Rapide'),
              Tab(text: 'Simulation Détaillée'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSimulationRapide(),
                _buildContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationRapide() {
    final prix          = _rParse(_rPrix);
    final travaux       = _rParse(_rTravaux);
    final loyer         = _rParse(_rLoyer);
    final taxe          = _rParse(_rTaxe);
    final fraisNotaire  = prix * 0.08;
    final coutAcq       = prix + fraisNotaire + travaux;
    final loyerAnnuel   = loyer * 12;
    final rentBrute     = coutAcq > 0 ? (loyerAnnuel / coutAcq) * 100 : 0.0;
    final rentNette     = coutAcq > 0 ? ((loyerAnnuel - taxe) / coutAcq) * 100 : 0.0;

    final cs = Theme.of(context).colorScheme;

    Widget champRapide(String label, TextEditingController ctrl, {String suffix = '€'}) =>
      _Champ(
        label: label,
        controller: ctrl,
        onChanged: (_) => setState(() {}),
        suffix: suffix,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
      );

    Widget ligneAuto(String label, double valeur, {bool gras = false, Color? couleur}) {
      final formatted = valeur > 0 ? _euro.format(valeur) : '—';
      final textColor = couleur ?? (valeur > 0 ? cs.onSurface : cs.onSurfaceVariant);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))),
          Text(formatted, style: TextStyle(fontSize: 13, fontWeight: gras ? FontWeight.w700 : FontWeight.w500, color: textColor)),
        ]),
      );
    }

    Widget kpiRentabilite(String label, double valeur, Color couleur) {
      final affiche = valeur > 0 ? '${valeur.toStringAsFixed(2)} %' : '—';
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: couleur.withValues(alpha: 0.3)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(affiche, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: couleur)),
          ]),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Champs de saisie ─────────────────────────────────────────────────
        const Text('Acquisition', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        champRapide('Prix d\'achat', _rPrix),
        const SizedBox(height: 12),
        champRapide('Travaux', _rTravaux),
        const SizedBox(height: 24),

        const Text('Recettes & Charges', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        champRapide('Loyer mensuel', _rLoyer),
        const SizedBox(height: 12),
        champRapide('Taxe foncière', _rTaxe),
        const SizedBox(height: 24),

        // ── Rentabilités ─────────────────────────────────────────────────────
        const Text('Rentabilité', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            kpiRentabilite('Brute', rentBrute, AppTheme.primary),
            const SizedBox(width: 12),
            kpiRentabilite('Nette (hors emprunt)', rentNette, AppTheme.blue),
          ]),
        ),
        const SizedBox(height: 24),

        // ── Récapitulatif ────────────────────────────────────────────────────
        const Text('Récapitulatif', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(children: [
            ligneAuto('Prix d\'achat',         prix),
            ligneAuto('Frais de notaire (8%)', fraisNotaire),
            ligneAuto('Travaux',               travaux),
            const Divider(height: 20),
            ligneAuto('Coût d\'acquisition',   coutAcq, gras: true),
            const Divider(height: 20),
            ligneAuto('Loyer annuel',          loyerAnnuel),
            ligneAuto('Taxe foncière',         taxe),
          ]),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Mes simulations (tout en haut) ────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _ouvrirMesSimulations,
            icon: const Icon(Icons.history),
            label: const Text('Mes simulations sauvegardées'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),

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
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(children: [
            _Ligne('Prix d\'achat',         _prixVal),
            if (_honorairesVal > 0)     _Ligne('Honoraires agence',       _honorairesVal),
            if (_fraisNotaire > 0)      _Ligne('Frais de notaire (8%)',   _fraisNotaire),
            if (_fraisBancVal > 0)      _Ligne('Frais bancaires',         _fraisBancVal),
            if (_travauxVal > 0)        _Ligne('Travaux',                 _travauxVal),
            const Divider(height: 16),
            _Ligne('Coût total',          _total,  gras: true),
            if (_apportVal > 0)         _Ligne('Apport',                  _apportVal),
            if (_apportVal > 0)         _Ligne('Crédit nécessaire',       _credit, gras: true, couleur: const Color(0xFF0D47A1)),
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
        _Champ(
          label: 'Nombre d\'années',
          controller: _nbAnnees,
          onChanged: (v) {
            final val = int.tryParse(v) ?? 0;
            if (val > 25) {
              _nbAnnees.text = '25';
              _nbAnnees.selection = const TextSelection.collapsed(offset: 2);
            }
            setState(() {});
          },
          suffix: 'ans',
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
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
        _Champ(
          label: 'Date début emprunt (MM-AAAA)',
          controller: _dateDebut,
          onChanged: (_) => setState(() {}),
          suffix: '',
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            DateEmpruntInputFormatter(),
          ],
        ),
        const SizedBox(height: 20),

        // ── Bouton calculer ────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _peutCalculer && !_calculEnCours ? _calculerComplet : null,
            icon: _calculEnCours
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.calculate_outlined),
            label: Text(_calculEnCours ? 'Simulation en cours...' : 'Simulation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Résultats ───────────────────────────────────────────────────────────
        if (_echeance != null) ...[
          // Échéance mensuelle card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text(
                    'Échéance mensuelle',
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Constante sur toute la durée',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10),
                  ),
                ]),
              ),
              Text(
                _euro.format(_echeance ?? 0),
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ],

        // Tableau résultats par année
        if (_anneesTable.isNotEmpty && _resultatsTable.isNotEmpty) ...[
          const Text('Résultats du simulation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _TableauSimulation(
            annees: _anneesTable,
            resultats: _resultatsTable,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sauvegarderSimulation,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Sauvegarder'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _exporterPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Exporter en PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ]),
    );
  } // fin _buildContent

  bool get _peutCalculer => _prixVal > 0 && _nbAnneesVal > 0 && _tauxVal > 0;
}

// ═══════════════════════════════════════════════════════════════════════════
// TABLEAU SIMULATION
// ═══════════════════════════════════════════════════════════════════════════

class _TableauSimulation extends StatelessWidget {
  final List<int> annees;
  final Map<String, List<double>> resultats;

  const _TableauSimulation({required this.annees, required this.resultats});

  static const _metriques = [
    ('Intérêts par année',             'interets', false),         // 0
    ('Capital emprunt',                'capitalEmprunt', false),   // 1
    ('Échéance',                       'echeance', false),         // 2
    ('Capital remboursé',              'capitalRembourse', false), // 3
    // separator at index 4
    ('Loyer annuel avec augmentation', 'loyer', false),            // 4
    ('Résultat d\'exploitation',       'resultatExploitation', false), // 5
    ('Frais bancaire',                 'fraisBancaire', false),    // 6
    ('Frais de notaire',               'fraisNotaire', false),     // 7
    ('Assurance PNO',                  'assurancePno', false),     // 8
    ('Taxe Foncière',                  'taxeFonciere', false),     // 9
    ('Travaux',                        'travaux', false),          // 10
    // separator at index 11
    ('Résultat net',                   'resultatNet', false),      // 11
    ('Déficit Reportable',             'deficitReportable', false),
    ('Résultat Fiscal',                'resultatFiscal', false),
    ('Prél. Sociaux (17,2%)',          'prelevementsSociaux', false),
    ('Impôts (TMI 30%)',               'impots', false),
    ('CAF (Hors travaux)',             'cafHorsTravaux', false),
    ('CAF Nette',                      'cafNette', false),
    ('Taux Renta Brut',                'tauxRentaBrut', true),
    ('Taux Renta Net',                 'tauxRentaNet', true),
    ('Impact capacité emprunt',        'impactCapacite', false),
  ];

  static const _financialKeys = {
    'resultatExploitation',
    'resultatNet',
    'resultatFiscal',
    'cafHorsTravaux',
    'cafNette',
  };

  static const _chargeKeys = {
    'fraisBancaire',
    'fraisNotaire',
    'assurancePno',
    'taxeFonciere',
    'travaux',
  };

  static const _tauxKeys = {
    'tauxRentaBrut',
    'tauxRentaNet',
  };

  Color _valueColor(String key, double value, BuildContext context) {
    if (_financialKeys.contains(key)) {
      return value >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFEF5350);
    }
    if (_chargeKeys.contains(key)) return Theme.of(context).colorScheme.onSurfaceVariant;
    if (_tauxKeys.contains(key))   return const Color(0xFF1565C0);
    if (key == 'loyer')            return const Color(0xFF1565C0);
    return Theme.of(context).colorScheme.onSurface;
  }

  String _format(String key, bool isPercent, double value) {
    if (isPercent) return '${(value * 100).toStringAsFixed(2)}%';
    return _euro.format(value);
  }

  @override
  Widget build(BuildContext context) {
    const double labelWidth = 160;
    const double colWidth   = 88;
    const double rowHeight  = 36;
    const double headerH    = 36;

    // Build data rows
    List<Widget> labelRows = [];

    // header label cell
    labelRows.add(Container(
      height: headerH,
      width: labelWidth,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFE3F2FD),
      child: const Text('Métrique', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1565C0))),
    ));

    // data header cells are handled by headerYearCols above

    for (int rowIdx = 0; rowIdx < _metriques.length; rowIdx++) {
      final (label, key, isPercent) = _metriques[rowIdx];
      final isEven = rowIdx % 2 == 0;
      final bg = isEven ? Colors.white : Colors.grey[50]!;

      // Séparateurs : entre capital remboursé (3) et loyer (4), entre travaux (10) et résultat net (11)
      if (rowIdx == 4 || rowIdx == 11) {
        labelRows.add(Container(height: 2, width: labelWidth, color: Theme.of(context).colorScheme.outlineVariant));
      }

      labelRows.add(Container(
        height: rowHeight,
        width: labelWidth,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        color: bg,
        child: Text(
          label,
          style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface),
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }

    // Build column widgets for each year
    List<Widget> yearColumnWidgets = List.generate(annees.length, (ci) {
      List<Widget> cells = [];

      // header cell
      cells.add(Container(
        height: headerH,
        width: colWidth,
        alignment: Alignment.center,
        color: const Color(0xFFE3F2FD),
        child: Text(
          '${annees[ci]}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF1565C0)),
        ),
      ));

      for (int rowIdx = 0; rowIdx < _metriques.length; rowIdx++) {
        final (_, key, isPercent) = _metriques[rowIdx];
        final isEven = rowIdx % 2 == 0;
        final bg     = isEven ? Colors.white : Colors.grey[50]!;
        final vals   = resultats[key] ?? [];
        final value  = ci < vals.length ? vals[ci] : 0.0;
        final color  = _valueColor(key, value, context);

        if (rowIdx == 4 || rowIdx == 11) {
          cells.add(Container(height: 2, width: colWidth, color: Theme.of(context).colorScheme.outlineVariant));
        }

        cells.add(Container(
          height: rowHeight,
          width: colWidth,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 8),
          color: bg,
          child: Text(
            _format(key, isPercent, value),
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ));
      }

      return Column(children: cells);
    });

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sticky left column (labels)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: labelRows,
            ),
            // Scrollable year columns
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: yearColumnWidgets,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _Champ extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String suffix;
  final List<TextInputFormatter>? inputFormatters;
  const _Champ({required this.label, required this.controller, required this.onChanged, this.suffix = '€', this.inputFormatters});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: inputFormatters,
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
  final Color? couleur;
  const _LigneCalculee({required this.label, required this.valeur, required this.actif, this.suffix = '€', this.couleur});

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
    final textColor = couleur ?? (actif ? const Color(0xFF1B5E20) : Theme.of(context).colorScheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: textColor, fontSize: 14))),
        Text(
          actif ? displayText : '—',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: textColor,
          ),
        ),
      ]),
    );
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
          color: couleur ?? Theme.of(context).colorScheme.onSurface,
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
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
              onPressed: nbApparts < 9 ? () => onNbAppartsChanged(nbApparts + 1) : null,
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

      const SizedBox(height: 32),
    ]);
  }
}


// ── Formatter pour date emprunt (MM-AAAA) ─────────────────────────────────────
class DateEmpruntInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Garder uniquement les chiffres
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limiter à 6 chiffres (MM + AAAA)
    if (digits.length > 6) digits = digits.substring(0, 6);

    // Valider et corriger le mois dès que 2 chiffres sont saisis
    if (digits.length >= 2) {
      int mm = int.parse(digits.substring(0, 2));
      if (mm == 0) mm = 1;
      if (mm > 12) mm = 12;
      digits = mm.toString().padLeft(2, '0') + digits.substring(2);
    } else if (digits.length == 1) {
      // Si le premier chiffre > 1, impossible d'avoir un mois valide à 2 chiffres → préfixer 0
      final d = int.parse(digits);
      if (d > 1) digits = '0$d';
    }

    // Formater avec tiret après le mois
    String formatted = digits;
    if (digits.length > 2) {
      formatted = '${digits.substring(0, 2)}-${digits.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MES SIMULATIONS (bottom sheet)
// ═══════════════════════════════════════════════════════════════════════════

class _MesSimulationsSheet extends StatefulWidget {
  final List<SimulationComplete> simulations;
  final void Function(SimulationComplete) onCharger;
  final Future<void> Function(String) onSupprimer;

  const _MesSimulationsSheet({
    required this.simulations,
    required this.onCharger,
    required this.onSupprimer,
  });

  @override
  State<_MesSimulationsSheet> createState() => _MesSimulationsSheetState();
}

class _MesSimulationsSheetState extends State<_MesSimulationsSheet> {
  late List<SimulationComplete> _sims;

  @override
  void initState() {
    super.initState();
    _sims = widget.simulations;
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(children: [
        // Poignée
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
        ),

        // Titre
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            const Icon(Icons.history, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Mes simulations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Text('${_sims.length}', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
          ]),
        ),
        const Divider(height: 1),

        // Liste
        Expanded(
          child: _sims.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Theme.of(ctx).colorScheme.outlineVariant),
                  const SizedBox(height: 8),
                  Text('Aucune simulation sauvegardée', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                ]),
              )
            : ListView.separated(
                controller: scrollCtrl,
                itemCount: _sims.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                itemBuilder: (ctx, i) {
                  final s = _sims[i];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE3F2FD),
                      child: Icon(Icons.home_work_outlined, color: Color(0xFF1565C0), size: 20),
                    ),
                    title: Text(s.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${dateFmt.format(s.date)}  ·  ${s.annees.length} ans',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        await widget.onSupprimer(s.id);
                        setState(() => _sims.removeWhere((x) => x.id == s.id));
                      },
                    ),
                    onTap: () => widget.onCharger(s),
                  );
                },
              ),
        ),

        const SizedBox(height: 16),
      ]),
    );
  }
}
