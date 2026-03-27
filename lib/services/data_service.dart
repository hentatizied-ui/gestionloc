import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'drive_service.dart';

const _uuid = Uuid();

class DataService extends ChangeNotifier {
  DriveService? _drive;

  List<Bien> _biens = [];
  List<Locataire> _locataires = [];
  List<Transaction> _transactions = [];
  List<Ticket> _tickets = [];

  bool _loading = false;
  String? _error;

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
        .map((l) {
          final bien = getBienById(l.bienId);
          return bien?.loyerMensuel ?? 0.0;
        })
        .fold(0.0, (a, b) => a + b);
  }

  /// Revenus par mois pour l'année courante (liste de 12 valeurs)
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

  Bien? getBienById(String? id) =>
      id == null ? null : _biens.cast<Bien?>().firstWhere((b) => b?.id == id, orElse: () => null);

  Locataire? getLocataireById(String? id) =>
      id == null ? null : _locataires.cast<Locataire?>().firstWhere((l) => l?.id == id, orElse: () => null);

  Locataire? getLocataireDuBien(String bienId) =>
      _locataires.cast<Locataire?>().firstWhere((l) => l?.bienId == bienId, orElse: () => null);

  List<Transaction> getTransactionsDuBien(String bienId) =>
      _transactions.where((t) => t.bienId == bienId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<Ticket> getTicketsDuBien(String bienId) =>
      _tickets.where((t) => t.bienId == bienId).toList()
        ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

  // ── Init ───────────────────────────────────────────────────────────────

  void updateDrive(DriveService drive) {
    _drive = drive;
    if (drive.isReady) loadAll();
  }

  Future<void> loadAll() async {
    if (_drive == null || !_drive!.isReady) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _drive!.readJson('biens.json'),
        _drive!.readJson('locataires.json'),
        _drive!.readJson('transactions.json'),
        _drive!.readJson('tickets.json'),
      ]);
      _biens = results[0].map(Bien.fromJson).toList();
      _locataires = results[1].map(Locataire.fromJson).toList();
      _transactions = results[2].map(Transaction.fromJson).toList();
      _tickets = results[3].map(Ticket.fromJson).toList();
    } catch (e) {
      _error = 'Erreur de chargement : $e';
    }
    _loading = false;
    notifyListeners();
  }

  // ── BIENS ──────────────────────────────────────────────────────────────

  Future<void> ajouterBien(Bien bien) async {
    _biens.add(bien);
    await _saveBiens();
    notifyListeners();
  }

  Future<void> modifierBien(Bien bien) async {
    final i = _biens.indexWhere((b) => b.id == bien.id);
    if (i >= 0) _biens[i] = bien;
    await _saveBiens();
    notifyListeners();
  }

  Future<void> supprimerBien(String id) async {
    _biens.removeWhere((b) => b.id == id);
    await _saveBiens();
    notifyListeners();
  }

  Future<void> _saveBiens() async =>
      _drive?.writeJson('biens.json', _biens.map((b) => b.toJson()).toList());

  // ── LOCATAIRES ─────────────────────────────────────────────────────────

  Future<void> ajouterLocataire(Locataire loc) async {
    _locataires.add(loc);
    if (loc.bienId != null) {
      final i = _biens.indexWhere((b) => b.id == loc.bienId);
      if (i >= 0) _biens[i] = _biens[i].copyWith(estLoue: true, locataireId: loc.id);
      await _saveBiens();
    }
    await _saveLocataires();
    notifyListeners();
  }

  Future<void> modifierLocataire(Locataire loc) async {
    final i = _locataires.indexWhere((l) => l.id == loc.id);
    if (i >= 0) _locataires[i] = loc;
    await _saveLocataires();
    notifyListeners();
  }

  Future<void> supprimerLocataire(String id) async {
    final loc = _locataires.firstWhere((l) => l.id == id);
    if (loc.bienId != null) {
      final i = _biens.indexWhere((b) => b.id == loc.bienId);
      if (i >= 0) _biens[i] = _biens[i].copyWith(estLoue: false, locataireId: null);
      await _saveBiens();
    }
    _locataires.removeWhere((l) => l.id == id);
    await _saveLocataires();
    notifyListeners();
  }

  Future<void> _saveLocataires() async =>
      _drive?.writeJson('locataires.json', _locataires.map((l) => l.toJson()).toList());

  // ── TRANSACTIONS ───────────────────────────────────────────────────────

  Future<void> ajouterTransaction(Transaction tx) async {
    _transactions.add(tx);
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    await _saveTransactions();
    notifyListeners();
  }

  Future<void> supprimerTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    await _saveTransactions();
    notifyListeners();
  }

  Future<void> _saveTransactions() async =>
      _drive?.writeJson('transactions.json', _transactions.map((t) => t.toJson()).toList());

  // ── TICKETS ────────────────────────────────────────────────────────────

  Future<void> ajouterTicket(Ticket ticket) async {
    _tickets.add(ticket);
    await _saveTickets();
    notifyListeners();
  }

  Future<void> modifierStatutTicket(String id, StatutTicket statut) async {
    final i = _tickets.indexWhere((t) => t.id == id);
    if (i >= 0) {
      _tickets[i].statut = statut;
      if (statut == StatutTicket.resolu) {
        _tickets[i].dateResolution = DateTime.now();
      }
    }
    await _saveTickets();
    notifyListeners();
  }

  Future<void> supprimerTicket(String id) async {
    _tickets.removeWhere((t) => t.id == id);
    await _saveTickets();
    notifyListeners();
  }

  Future<void> _saveTickets() async =>
      _drive?.writeJson('tickets.json', _tickets.map((t) => t.toJson()).toList());

  // ── Factory helpers ────────────────────────────────────────────────────

  Bien nouvBien({
    required String nom, required String adresse, required String ville,
    required String type, required int pieces, required double surface,
    required double loyer, required double charges,
  }) => Bien(
    id: _uuid.v4(), nom: nom, adresse: adresse, ville: ville,
    type: type, pieces: pieces, surface: surface,
    loyerMensuel: loyer, charges: charges,
  );

  Locataire nouvLocataire({
    required String prenom, required String nom, required String email,
    required String telephone, String? bienId,
    required DateTime debutBail, required DateTime finBail, required double depot,
  }) => Locataire(
    id: _uuid.v4(), prenom: prenom, nom: nom, email: email,
    telephone: telephone, bienId: bienId,
    debutBail: debutBail, finBail: finBail, depot: depot,
  );

  Transaction nouvTransaction({
    required String label, required double montant,
    required TypeTransaction type, DateTime? date,
    String? bienId, String? locataireId, String? note,
  }) => Transaction(
    id: _uuid.v4(), label: label, montant: montant, type: type,
    date: date ?? DateTime.now(),
    bienId: bienId, locataireId: locataireId, note: note,
  );

  Ticket nouvTicket({
    required String titre, required String description,
    required String bienId, required PrioriteTicket priorite, String? rapportePar,
  }) => Ticket(
    id: _uuid.v4(), titre: titre, description: description,
    bienId: bienId, priorite: priorite, rapportePar: rapportePar,
  );
}
