import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'sheets_service.dart';

const _uuid = Uuid();

class DataService extends ChangeNotifier {
  SheetsService? _sheets;

  List<Immeuble> _immeubles = [];
  List<Bien> _biens = [];
  List<Locataire> _locataires = [];
  List<Transaction> _transactions = [];
  List<Ticket> _tickets = [];

  bool _loading = false;
  String? _error;

  List<Immeuble> get immeubles => List.unmodifiable(_immeubles);
  List<Bien> get biens => List.unmodifiable(_biens);
  List<Locataire> get locataires => List.unmodifiable(_locataires);
  List<Transaction> get transactions => List.unmodifiable(_transactions);
  List<Ticket> get tickets => List.unmodifiable(_tickets);
  bool get loading => _loading;
  String? get error => _error;

  // ── Stats ──────────────────────────────────────────────────────────────

  int get biensLoues => _biens.where((b) => b.estLoue).length;
  int get biensVacants => _biens.where((b) => !b.estLoue).length;
  double get tauxOccupation => _biens.isEmpty ? 0 : biensLoues / _biens.length;

  double get revenusMoisCourant {
    final now = DateTime.now();
    return _transactions
        .where((t) => t.isRecette && t.date.month == now.month && t.date.year == now.year)
        .fold(0.0, (s, t) => s + t.montant);
  }

  double get revenusAnnee {
    final now = DateTime.now();
    return _transactions
        .where((t) => t.isRecette && t.date.year == now.year)
        .fold(0.0, (s, t) => s + t.montant);
  }

  double get chargesAnnee {
    final now = DateTime.now();
    return _transactions
        .where((t) => !t.isRecette && t.date.year == now.year)
        .fold(0.0, (s, t) => s + t.montant.abs());
  }

  int get ticketsOuverts =>
      _tickets.where((t) => t.statut == StatutTicket.ouvert || t.statut == StatutTicket.enCours).length;

  int get ticketsUrgents =>
      _tickets.where((t) => t.priorite == PrioriteTicket.urgent && t.statut != StatutTicket.resolu).length;

  int get locatairesEnRetard =>
      _locataires.where((l) => l.statut != StatutPaiement.aJour).length;

  double get montantEnAttente {
    return _locataires
        .where((l) => l.statut != StatutPaiement.aJour)
        .map((l) { final bien = getBienById(l.bienId); return bien?.loyerMensuel ?? 0.0; })
        .fold(0.0, (a, b) => a + b);
  }

  List<double> get revenusParMois {
    final now = DateTime.now();
    final result = List<double>.filled(12, 0);
    for (final t in _transactions) {
      if (t.isRecette && t.date.year == now.year) {
        result[t.date.month - 1] += t.montant;
      }
    }
    return result;
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Immeuble? getImmeubleById(String? id) =>
      id == null || id.isEmpty ? null : _immeubles.cast<Immeuble?>().firstWhere((i) => i?.id == id, orElse: () => null);

  Bien? getBienById(String? id) =>
      id == null || id.isEmpty ? null : _biens.cast<Bien?>().firstWhere((b) => b?.id == id, orElse: () => null);

  Locataire? getLocataireById(String? id) =>
      id == null || id.isEmpty ? null : _locataires.cast<Locataire?>().firstWhere((l) => l?.id == id, orElse: () => null);

  Locataire? getLocataireDuBien(String bienId) =>
      _locataires.cast<Locataire?>().firstWhere((l) => l?.bienId == bienId, orElse: () => null);

  List<Bien> getBiensDeLImmeuble(String immeubleId) =>
      _biens.where((b) => b.immeubleId == immeubleId).toList();

  List<Bien> get biensSansImmeuble =>
      _biens.where((b) => b.immeubleId == null || b.immeubleId!.isEmpty).toList();

  List<Transaction> getTransactionsDuBien(String bienId) =>
      _transactions.where((t) => t.bienId == bienId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Transaction> getLoyers(String bienId) =>
      _transactions.where((t) => t.bienId == bienId && t.type == TypeTransaction.loyer && t.isRecette).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Ticket> getTicketsDuBien(String bienId) =>
      _tickets.where((t) => t.bienId == bienId).toList()
        ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

  // ── Init ───────────────────────────────────────────────────────────────

  void updateSheets(SheetsService sheets) {
    _sheets = sheets;
    if (sheets.isReady) loadAll();
  }

  Future<void> loadAll() async {
    if (_sheets == null || !_sheets!.isReady) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _sheets!.readSheetAsMap('Immeubles'),
        _sheets!.readSheetAsMap('Biens'),
        _sheets!.readSheetAsMap('Locataires'),
        _sheets!.readSheetAsMap('Transactions'),
        _sheets!.readSheetAsMap('Tickets'),
      ]);
      _immeubles = results[0].map(Immeuble.fromMap).toList();
      _biens = results[1].map(Bien.fromMap).toList();
      _locataires = results[2].map(Locataire.fromMap).toList();
      _transactions = results[3].map(Transaction.fromMap).toList();
      _tickets = results[4].map(Ticket.fromMap).toList();
      _transactions.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      _error = 'Erreur de chargement : $e';
    }
    _loading = false;
    notifyListeners();
  }

  // ── IMMEUBLES ──────────────────────────────────────────────────────────

  Future<void> ajouterImmeuble(Immeuble immeuble) async {
    _immeubles.add(immeuble);
    await _sheets?.appendRow('Immeubles', immeuble.toRow());
    notifyListeners();
  }

  Future<void> modifierImmeuble(Immeuble immeuble) async {
    final i = _immeubles.indexWhere((b) => b.id == immeuble.id);
    if (i >= 0) _immeubles[i] = immeuble;
    await _sheets?.updateRow('Immeubles', immeuble.id, immeuble.toRow());
    notifyListeners();
  }

  Future<void> supprimerImmeuble(String id) async {
    _immeubles.removeWhere((b) => b.id == id);
    await _sheets?.deleteRow('Immeubles', id);
    notifyListeners();
  }

  // ── BIENS ──────────────────────────────────────────────────────────────

  Future<void> ajouterBien(Bien bien) async {
    _biens.add(bien);
    await _sheets?.appendRow('Biens', bien.toRow());
    notifyListeners();
  }

  Future<void> modifierBien(Bien bien) async {
    final i = _biens.indexWhere((b) => b.id == bien.id);
    if (i >= 0) _biens[i] = bien;
    await _sheets?.updateRow('Biens', bien.id, bien.toRow());
    notifyListeners();
  }

  Future<void> supprimerBien(String id) async {
    _biens.removeWhere((b) => b.id == id);
    await _sheets?.deleteRow('Biens', id);
    notifyListeners();
  }

  // ── LOCATAIRES ─────────────────────────────────────────────────────────

  Future<void> ajouterLocataire(Locataire loc) async {
    _locataires.add(loc);
    if (loc.bienId != null && loc.bienId!.isNotEmpty) {
      await _setBienLoue(loc.bienId!, true, loc.id);
    }
    await _sheets?.appendRow('Locataires', loc.toRow());
    notifyListeners();
  }

  Future<void> modifierLocataire(Locataire loc) async {
    final ancienLoc = _locataires.firstWhere((l) => l.id == loc.id);
    final ancienBienId = ancienLoc.bienId;
    final nouveauBienId = loc.bienId;

    // Mettre à jour le locataire en local
    final i = _locataires.indexWhere((l) => l.id == loc.id);
    if (i >= 0) _locataires[i] = loc;

    // Si le bien a changé
    if (ancienBienId != nouveauBienId) {
      // Libérer l'ancien bien
      if (ancienBienId != null && ancienBienId.isNotEmpty) {
        await _setBienLoue(ancienBienId, false, '');
      }
      // Occuper le nouveau bien
      if (nouveauBienId != null && nouveauBienId.isNotEmpty) {
        await _setBienLoue(nouveauBienId, true, loc.id);
      }
    }

    await _sheets?.updateRow('Locataires', loc.id, loc.toRow());
    notifyListeners();
  }

  Future<void> supprimerLocataire(String id) async {
    final loc = _locataires.firstWhere((l) => l.id == id);
    if (loc.bienId != null && loc.bienId!.isNotEmpty) {
      await _setBienLoue(loc.bienId!, false, '');
    }
    _locataires.removeWhere((l) => l.id == id);
    await _sheets?.deleteRow('Locataires', id);
    notifyListeners();
  }

  Future<void> _setBienLoue(String bienId, bool estLoue, String locataireId) async {
    final i = _biens.indexWhere((b) => b.id == bienId);
    if (i >= 0) {
      _biens[i] = _biens[i].copyWith(estLoue: estLoue, locataireId: locataireId);
      await _sheets?.updateRow('Biens', _biens[i].id, _biens[i].toRow());
    }
  }

  // ── TRANSACTIONS ───────────────────────────────────────────────────────

  Future<void> ajouterTransaction(Transaction tx) async {
    _transactions.insert(0, tx);
    await _sheets?.appendRow('Transactions', tx.toRow());
    notifyListeners();
  }

  Future<void> supprimerTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await _sheets?.deleteRow('Transactions', id);
    notifyListeners();
  }

  // ── TICKETS ────────────────────────────────────────────────────────────

  Future<void> ajouterTicket(Ticket ticket) async {
    _tickets.add(ticket);
    await _sheets?.appendRow('Tickets', ticket.toRow());
    notifyListeners();
  }

  Future<void> modifierStatutTicket(String id, StatutTicket statut) async {
    final i = _tickets.indexWhere((t) => t.id == id);
    if (i >= 0) {
      _tickets[i].statut = statut;
      if (statut == StatutTicket.resolu) _tickets[i].dateResolution = DateTime.now();
      await _sheets?.updateRow('Tickets', id, _tickets[i].toRow());
    }
    notifyListeners();
  }

  Future<void> supprimerTicket(String id) async {
    _tickets.removeWhere((t) => t.id == id);
    await _sheets?.deleteRow('Tickets', id);
    notifyListeners();
  }

  // ── Factories ──────────────────────────────────────────────────────────

  Immeuble nouvImmeuble({required String nom, required String adresse, required String ville, required String codePostal, required int nbEtages}) =>
      Immeuble(id: 'imm_${_uuid.v4().substring(0, 8)}', nom: nom, adresse: adresse, ville: ville, codePostal: codePostal, nbEtages: nbEtages);

  Bien nouvBien({required String nom, required String adresse, required String ville, required String codePostal, required String type, required int pieces, required double surface, required double loyer, required double charges, String? immeubleId, String? etage, String? numero}) =>
      Bien(id: 'bien_${_uuid.v4().substring(0, 8)}', nom: nom, adresse: adresse, ville: ville, codePostal: codePostal, type: type, pieces: pieces, surface: surface, loyerMensuel: loyer, charges: charges, immeubleId: immeubleId, etage: etage, numero: numero);

  Locataire nouvLocataire({required String prenom, required String nom, required String email, required String telephone, String? bienId, required DateTime debutBail, required DateTime finBail, required double depot}) =>
      Locataire(id: 'loc_${_uuid.v4().substring(0, 8)}', prenom: prenom, nom: nom, email: email, telephone: telephone, bienId: bienId, debutBail: debutBail, finBail: finBail, depot: depot);

  Transaction nouvTransaction({required String label, required double montant, required TypeTransaction type, DateTime? date, String? bienId, String? immeubleId, String? locataireId, String? note}) =>
      Transaction(id: 'tx_${_uuid.v4().substring(0, 8)}', label: label, montant: montant, type: type, date: date ?? DateTime.now(), bienId: bienId, immeubleId: immeubleId, locataireId: locataireId, note: note);

  Ticket nouvTicket({required String titre, required String description, required String bienId, String? immeubleId, required PrioriteTicket priorite, String? rapportePar}) =>
      Ticket(id: 'tkt_${_uuid.v4().substring(0, 8)}', titre: titre, description: description, bienId: bienId, immeubleId: immeubleId, priorite: priorite, rapportePar: rapportePar);
}
