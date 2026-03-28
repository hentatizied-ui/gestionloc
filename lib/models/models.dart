// ─── IMMEUBLE ──────────────────────────────────────────────────────────────

class Immeuble {
  final String id;
  final String nom;
  final String adresse;
  final String ville;
  final String codePostal;
  final int nbEtages;
  final String? note;

  Immeuble({required this.id, required this.nom, required this.adresse, required this.ville, required this.codePostal, required this.nbEtages, this.note});

  factory Immeuble.fromMap(Map<String, String> m) => Immeuble(
    id: m['id'] ?? '',
    nom: m['nom'] ?? '',
    adresse: m['adresse'] ?? '',
    ville: m['ville'] ?? '',
    codePostal: m['codePostal'] ?? '',
    nbEtages: int.tryParse(m['nbEtages'] ?? '0') ?? 0,
    note: m['note'],
  );

  List<String> toRow() => [id, nom, adresse, ville, codePostal, nbEtages.toString(), '', '', note ?? ''];

  Immeuble copyWith({String? nom, String? adresse, String? ville, String? codePostal, int? nbEtages, String? note}) =>
      Immeuble(id: id, nom: nom ?? this.nom, adresse: adresse ?? this.adresse, ville: ville ?? this.ville, codePostal: codePostal ?? this.codePostal, nbEtages: nbEtages ?? this.nbEtages, note: note ?? this.note);
}

// ─── BIEN ──────────────────────────────────────────────────────────────────

class Bien {
  final String id;
  final String? immeubleId;
  final String nom;
  final String type;
  final String adresse;
  final String ville;
  final String codePostal;
  final String? etage;
  final String? numero;
  final double surface;
  final int pieces;
  final double loyerMensuel;
  final double charges;
  final bool estLoue;
  final String? locataireId;
  final DateTime dateAjout;
  final String? note;

  Bien({required this.id, this.immeubleId, required this.nom, required this.type, required this.adresse, required this.ville, required this.codePostal, this.etage, this.numero, required this.surface, required this.pieces, required this.loyerMensuel, required this.charges, this.estLoue = false, this.locataireId, DateTime? dateAjout, this.note}) : dateAjout = dateAjout ?? DateTime.now();

  factory Bien.fromMap(Map<String, String> m) => Bien(
    id: m['id'] ?? '',
    immeubleId: m['immeubleId'],
    nom: m['nom'] ?? '',
    type: m['type'] ?? 'appartement',
    adresse: m['adresse'] ?? '',
    ville: m['ville'] ?? '',
    codePostal: m['codePostal'] ?? '',
    etage: m['etage'],
    numero: m['numero'],
    surface: double.tryParse(m['surface'] ?? '0') ?? 0,
    pieces: int.tryParse(m['pieces'] ?? '0') ?? 0,
    loyerMensuel: double.tryParse(m['loyerMensuel'] ?? '0') ?? 0,
    charges: double.tryParse(m['charges'] ?? '0') ?? 0,
    estLoue: m['estLoue'] == 'OUI',
    locataireId: m['locataireId'],
    dateAjout: DateTime.tryParse(m['dateAjout'] ?? '') ?? DateTime.now(),
    note: m['note'],
  );

  List<String> toRow() => [
    id, immeubleId ?? '', nom, type, adresse, ville, codePostal,
    etage ?? '', numero ?? '', surface.toString(), pieces.toString(),
    loyerMensuel.toString(), charges.toString(),
    estLoue ? 'OUI' : 'NON', locataireId ?? '',
    dateAjout.toIso8601String().substring(0, 10), note ?? '',
  ];

  Bien copyWith({String? nom, String? immeubleId, String? adresse, String? ville, String? codePostal, String? type, int? pieces, double? surface, double? loyerMensuel, double? charges, bool? estLoue, String? locataireId, String? etage, String? numero}) =>
      Bien(id: id, immeubleId: immeubleId ?? this.immeubleId, nom: nom ?? this.nom, type: type ?? this.type, adresse: adresse ?? this.adresse, ville: ville ?? this.ville, codePostal: codePostal ?? this.codePostal, etage: etage ?? this.etage, numero: numero ?? this.numero, surface: surface ?? this.surface, pieces: pieces ?? this.pieces, loyerMensuel: loyerMensuel ?? this.loyerMensuel, charges: charges ?? this.charges, estLoue: estLoue ?? this.estLoue, locataireId: locataireId ?? this.locataireId, dateAjout: dateAjout, note: this.note);
}

// ─── LOCATAIRE ─────────────────────────────────────────────────────────────

enum StatutPaiement { aJour, enRetard, retardCritique }
enum TypeLocataire { particulier, entreprise, sousTutelle }

class Locataire {
  final String id;
  final String prenom;
  final String nom;
  final String email;
  final String telephone;
  final String? bienId;
  final DateTime debutBail;
  final DateTime finBail;
  final double depot;
  final StatutPaiement statut;
  final TypeLocataire typeLocataire;
  // Pour entreprise : raison sociale
  // Pour sous tutelle : nom de l'organisme tuteur
  final String? raisonSociale;
  final String? note;

  Locataire({
    required this.id, required this.prenom, required this.nom,
    required this.email, required this.telephone, this.bienId,
    required this.debutBail, required this.finBail, required this.depot,
    this.statut = StatutPaiement.aJour,
    this.typeLocataire = TypeLocataire.particulier,
    this.raisonSociale, this.note,
  });

  // Nom affiché dans l'app
  String get nomComplet {
    switch (typeLocataire) {
      case TypeLocataire.entreprise:
        return raisonSociale?.isNotEmpty == true ? raisonSociale! : prenom + ' ' + nom;
      case TypeLocataire.sousTutelle:
        return prenom + ' ' + nom;
      case TypeLocataire.particulier:
        return prenom + ' ' + nom;
    }
  }

  // Nom pour la quittance (texte légal complet)
  String get nomQuittance {
    switch (typeLocataire) {
      case TypeLocataire.entreprise:
        return raisonSociale?.isNotEmpty == true ? raisonSociale! : prenom + ' ' + nom;
      case TypeLocataire.sousTutelle:
        final org = raisonSociale?.isNotEmpty == true ? raisonSociale! : '';
        final benef = prenom + ' ' + nom;
        return org + ', (tuteur legal de ' + benef + ') representant legalement ce dernier dans le cadre de sa tutelle';
      case TypeLocataire.particulier:
        return prenom + ' ' + nom;
    }
  }

  String get initiales => (prenom.isNotEmpty ? prenom[0] : '') + (nom.isNotEmpty ? nom[0] : '').toUpperCase();

  factory Locataire.fromMap(Map<String, String> m) => Locataire(
    id: m['id'] ?? '',
    prenom: m['prenom'] ?? '',
    nom: m['nom'] ?? '',
    email: m['email'] ?? '',
    telephone: m['telephone'] ?? '',
    bienId: m['bienId'],
    debutBail: DateTime.tryParse(m['debutBail'] ?? '') ?? DateTime.now(),
    finBail: DateTime.tryParse(m['finBail'] ?? '') ?? DateTime.now(),
    depot: double.tryParse(m['depot'] ?? '0') ?? 0,
    statut: StatutPaiement.values.firstWhere((s) => s.name == m['statut'], orElse: () => StatutPaiement.aJour),
    typeLocataire: TypeLocataire.values.firstWhere((t) => t.name == m['typeLocataire'], orElse: () => TypeLocataire.particulier),
    raisonSociale: m['raisonSociale'],
    note: m['note'],
  );

  List<String> toRow() => [
    id, bienId ?? '', prenom, nom, email, telephone,
    debutBail.toIso8601String().substring(0, 10),
    finBail.toIso8601String().substring(0, 10),
    depot.toString(), statut.name,
    typeLocataire.name, raisonSociale ?? '',
    note ?? '',
  ];

  Locataire copyWith({
    String? prenom, String? nom, String? email, String? telephone,
    String? bienId, DateTime? debutBail, DateTime? finBail,
    double? depot, StatutPaiement? statut,
    TypeLocataire? typeLocataire, String? raisonSociale,
  }) => Locataire(
    id: id, prenom: prenom ?? this.prenom, nom: nom ?? this.nom,
    email: email ?? this.email, telephone: telephone ?? this.telephone,
    bienId: bienId ?? this.bienId,
    debutBail: debutBail ?? this.debutBail, finBail: finBail ?? this.finBail,
    depot: depot ?? this.depot, statut: statut ?? this.statut,
    typeLocataire: typeLocataire ?? this.typeLocataire,
    raisonSociale: raisonSociale ?? this.raisonSociale,
    note: this.note,
  );
}

// ─── TRANSACTION ───────────────────────────────────────────────────────────

enum TypeTransaction { loyer, charge, reparation, assurance, taxe, autre }

class Transaction {
  final String id;
  final String? bienId;
  final String? immeubleId;
  final String label;
  final double montant;
  final TypeTransaction type;
  final DateTime date;
  final String? locataireId;
  final String? note;

  Transaction({required this.id, this.bienId, this.immeubleId, required this.label, required this.montant, required this.type, required this.date, this.locataireId, this.note});

  bool get isRecette => montant > 0;

  factory Transaction.fromMap(Map<String, String> m) => Transaction(
    id: m['id'] ?? '',
    bienId: m['bienId'],
    immeubleId: m['immeubleId'],
    label: m['label'] ?? '',
    montant: double.tryParse(m['montant'] ?? '0') ?? 0,
    type: TypeTransaction.values.firstWhere((t) => t.name == m['type'], orElse: () => TypeTransaction.autre),
    date: DateTime.tryParse(m['date'] ?? '') ?? DateTime.now(),
    locataireId: m['locataireId'],
    note: m['note'],
  );

  List<String> toRow() => [id, bienId ?? '', immeubleId ?? '', label, montant.toString(), type.name, date.toIso8601String().substring(0, 10), locataireId ?? '', note ?? ''];
}

// ─── TICKET ────────────────────────────────────────────────────────────────

enum PrioriteTicket { urgent, moyenne, faible }
enum StatutTicket { ouvert, enCours, planifie, resolu }

class Ticket {
  final String id;
  final String bienId;
  final String? immeubleId;
  final String titre;
  final String description;
  final PrioriteTicket priorite;
  StatutTicket statut;
  final DateTime dateCreation;
  DateTime? dateResolution;
  final String? rapportePar;
  double? coutReparation;

  Ticket({required this.id, required this.bienId, this.immeubleId, required this.titre, required this.description, required this.priorite, this.statut = StatutTicket.ouvert, DateTime? dateCreation, this.dateResolution, this.rapportePar, this.coutReparation}) : dateCreation = dateCreation ?? DateTime.now();

  factory Ticket.fromMap(Map<String, String> m) => Ticket(
    id: m['id'] ?? '',
    bienId: m['bienId'] ?? '',
    immeubleId: m['immeubleId'],
    titre: m['titre'] ?? '',
    description: m['description'] ?? '',
    priorite: PrioriteTicket.values.firstWhere((p) => p.name == m['priorite'], orElse: () => PrioriteTicket.moyenne),
    statut: StatutTicket.values.firstWhere((s) => s.name == m['statut'], orElse: () => StatutTicket.ouvert),
    dateCreation: DateTime.tryParse(m['dateCreation'] ?? '') ?? DateTime.now(),
    dateResolution: m['dateResolution'] != null && m['dateResolution']!.isNotEmpty ? DateTime.tryParse(m['dateResolution']!) : null,
    rapportePar: m['rapportePar'],
    coutReparation: double.tryParse(m['coutReparation'] ?? ''),
  );

  List<String> toRow() => [id, bienId, immeubleId ?? '', titre, description, priorite.name, statut.name, dateCreation.toIso8601String().substring(0, 10), dateResolution?.toIso8601String().substring(0, 10) ?? '', rapportePar ?? '', coutReparation?.toString() ?? ''];
}
