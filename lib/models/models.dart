// ─── BIEN ──────────────────────────────────────────────────────────────────

class Bien {
  final String id;
  final String nom;
  final String adresse;
  final String ville;
  final String type; // appartement, studio, maison, loft
  final int pieces;
  final double surface;
  final double loyerMensuel;
  final double charges;
  final bool estLoue;
  final String? locataireId;
  final String? photoUrl;
  final DateTime dateAjout;

  Bien({
    required this.id,
    required this.nom,
    required this.adresse,
    required this.ville,
    required this.type,
    required this.pieces,
    required this.surface,
    required this.loyerMensuel,
    required this.charges,
    this.estLoue = false,
    this.locataireId,
    this.photoUrl,
    DateTime? dateAjout,
  }) : dateAjout = dateAjout ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'adresse': adresse,
    'ville': ville,
    'type': type,
    'pieces': pieces,
    'surface': surface,
    'loyerMensuel': loyerMensuel,
    'charges': charges,
    'estLoue': estLoue,
    'locataireId': locataireId,
    'photoUrl': photoUrl,
    'dateAjout': dateAjout.toIso8601String(),
  };

  factory Bien.fromJson(Map<String, dynamic> j) => Bien(
    id: j['id'],
    nom: j['nom'],
    adresse: j['adresse'],
    ville: j['ville'],
    type: j['type'],
    pieces: j['pieces'],
    surface: (j['surface'] as num).toDouble(),
    loyerMensuel: (j['loyerMensuel'] as num).toDouble(),
    charges: (j['charges'] as num).toDouble(),
    estLoue: j['estLoue'] ?? false,
    locataireId: j['locataireId'],
    photoUrl: j['photoUrl'],
    dateAjout: DateTime.parse(j['dateAjout']),
  );

  Bien copyWith({
    String? nom, String? adresse, String? ville, String? type,
    int? pieces, double? surface, double? loyerMensuel, double? charges,
    bool? estLoue, String? locataireId, String? photoUrl,
  }) => Bien(
    id: id,
    nom: nom ?? this.nom,
    adresse: adresse ?? this.adresse,
    ville: ville ?? this.ville,
    type: type ?? this.type,
    pieces: pieces ?? this.pieces,
    surface: surface ?? this.surface,
    loyerMensuel: loyerMensuel ?? this.loyerMensuel,
    charges: charges ?? this.charges,
    estLoue: estLoue ?? this.estLoue,
    locataireId: locataireId ?? this.locataireId,
    photoUrl: photoUrl ?? this.photoUrl,
    dateAjout: dateAjout,
  );
}

// ─── LOCATAIRE ─────────────────────────────────────────────────────────────

enum StatutPaiement { aJour, enRetard, retardCritique }

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
  final String? photoUrl;

  Locataire({
    required this.id,
    required this.prenom,
    required this.nom,
    required this.email,
    required this.telephone,
    this.bienId,
    required this.debutBail,
    required this.finBail,
    required this.depot,
    this.statut = StatutPaiement.aJour,
    this.photoUrl,
  });

  String get nomComplet => '$prenom $nom';
  String get initiales => '${prenom[0]}${nom[0]}'.toUpperCase();

  Map<String, dynamic> toJson() => {
    'id': id,
    'prenom': prenom,
    'nom': nom,
    'email': email,
    'telephone': telephone,
    'bienId': bienId,
    'debutBail': debutBail.toIso8601String(),
    'finBail': finBail.toIso8601String(),
    'depot': depot,
    'statut': statut.name,
    'photoUrl': photoUrl,
  };

  factory Locataire.fromJson(Map<String, dynamic> j) => Locataire(
    id: j['id'],
    prenom: j['prenom'],
    nom: j['nom'],
    email: j['email'],
    telephone: j['telephone'],
    bienId: j['bienId'],
    debutBail: DateTime.parse(j['debutBail']),
    finBail: DateTime.parse(j['finBail']),
    depot: (j['depot'] as num).toDouble(),
    statut: StatutPaiement.values.firstWhere(
      (s) => s.name == j['statut'],
      orElse: () => StatutPaiement.aJour,
    ),
    photoUrl: j['photoUrl'],
  );

  Locataire copyWith({
    String? prenom, String? nom, String? email, String? telephone,
    String? bienId, DateTime? debutBail, DateTime? finBail,
    double? depot, StatutPaiement? statut,
  }) => Locataire(
    id: id,
    prenom: prenom ?? this.prenom,
    nom: nom ?? this.nom,
    email: email ?? this.email,
    telephone: telephone ?? this.telephone,
    bienId: bienId ?? this.bienId,
    debutBail: debutBail ?? this.debutBail,
    finBail: finBail ?? this.finBail,
    depot: depot ?? this.depot,
    statut: statut ?? this.statut,
    photoUrl: this.photoUrl,
  );
}

// ─── TRANSACTION ───────────────────────────────────────────────────────────

enum TypeTransaction { loyer, charge, reparation, assurance, taxe, autre }

class Transaction {
  final String id;
  final String label;
  final double montant; // positif = recette, négatif = dépense
  final TypeTransaction type;
  final DateTime date;
  final String? bienId;
  final String? locataireId;
  final String? note;

  Transaction({
    required this.id,
    required this.label,
    required this.montant,
    required this.type,
    required this.date,
    this.bienId,
    this.locataireId,
    this.note,
  });

  bool get isRecette => montant > 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'montant': montant,
    'type': type.name,
    'date': date.toIso8601String(),
    'bienId': bienId,
    'locataireId': locataireId,
    'note': note,
  };

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
    id: j['id'],
    label: j['label'],
    montant: (j['montant'] as num).toDouble(),
    type: TypeTransaction.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => TypeTransaction.autre,
    ),
    date: DateTime.parse(j['date']),
    bienId: j['bienId'],
    locataireId: j['locataireId'],
    note: j['note'],
  );
}

// ─── TICKET MAINTENANCE ────────────────────────────────────────────────────

enum PrioriteTicket { urgent, moyenne, faible }
enum StatutTicket { ouvert, enCours, planifie, resolu }

class Ticket {
  final String id;
  final String titre;
  final String description;
  final String bienId;
  final PrioriteTicket priorite;
  StatutTicket statut;
  final DateTime dateCreation;
  DateTime? dateResolution;
  final String? rapportePar;
  double? coutReparation;

  Ticket({
    required this.id,
    required this.titre,
    required this.description,
    required this.bienId,
    required this.priorite,
    this.statut = StatutTicket.ouvert,
    DateTime? dateCreation,
    this.dateResolution,
    this.rapportePar,
    this.coutReparation,
  }) : dateCreation = dateCreation ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'titre': titre,
    'description': description,
    'bienId': bienId,
    'priorite': priorite.name,
    'statut': statut.name,
    'dateCreation': dateCreation.toIso8601String(),
    'dateResolution': dateResolution?.toIso8601String(),
    'rapportePar': rapportePar,
    'coutReparation': coutReparation,
  };

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
    id: j['id'],
    titre: j['titre'],
    description: j['description'],
    bienId: j['bienId'],
    priorite: PrioriteTicket.values.firstWhere(
      (p) => p.name == j['priorite'],
      orElse: () => PrioriteTicket.moyenne,
    ),
    statut: StatutTicket.values.firstWhere(
      (s) => s.name == j['statut'],
      orElse: () => StatutTicket.ouvert,
    ),
    dateCreation: DateTime.parse(j['dateCreation']),
    dateResolution: j['dateResolution'] != null
        ? DateTime.parse(j['dateResolution'])
        : null,
    rapportePar: j['rapportePar'],
    coutReparation: j['coutReparation'] != null
        ? (j['coutReparation'] as num).toDouble()
        : null,
  );
}
