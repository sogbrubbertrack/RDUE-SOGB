import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static Database? _db;

  // Constantes pour les IDs de questions critiques
  static const String Q_LITIGE = '11';
  static const String Q_PRODUITS_CHIMIQUES = '9';
  static const String Q_TRAVAILLEURS_MINEURS = '37';
  static const String Q_CONSENTEMENT = '29';
  static const String Q_DOCUMENTS_ETRANGERS = '40';
  static const String Q_FRAIS_ETRANGERS = '41';
  static const String Q_PRESENCE_16_17 = '16';
  static const String Q_PRESENCE_13_15 = '20';
  static const String Q_PRESENCE_MOINS_13 = '25';

  static const String CODE_OUI = 'A';
  static const String CODE_NON = 'Z';
  static const String CODE_OUI_16_17 = 'B';
  static const String CODE_OUI_13_15 = 'C';
  static const String CODE_OUI_MOINS_13 = 'D';
  static const String CODE_NON_CONFORME = 'C';

  // Types de signatures
  static const String SIGNATURE_AGENT = 'agent';
  static const String SIGNATURE_PLANTEUR = 'planteur';

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, "rubberway.db");

    return await openDatabase(
      path,
      version: 12,
      onCreate: (db, version) async {
        await _createAllTables(db);
        await _insertZones(db);
        await _insertEnqueteurs(db);
        await _insertAllQuestions(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 7) {
          // Migration vers version 7 avec contrainte UNIQUE
          await _upgradeToVersion7(db);
        }
        if (oldVersion < 8) {
          // Migration vers version 8 avec index
          await _upgradeToVersion8(db);
        }
        if (oldVersion < 9) {
          // Migration vers version 9 avec table signatures
          await _upgradeToVersion9(db);
        }
        if (oldVersion < 10) {
          await _upgradeToVersion10(db);
        }
        if (oldVersion < 11) {
          await _upgradeToVersion11(db);
        }
        if (oldVersion < 12) {
          await _upgradeToVersion12(db);
        }
      },
    );
  }

  static Future<void> _createAllTables(Database db) async {
    // === TABLE PRODUCTEURS ===
    await db.execute('''
      CREATE TABLE producteurs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code_phi TEXT,
        nom TEXT,
        contact TEXT,
        village TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_code_phi ON producteurs(code_phi)');
    await db.execute('CREATE INDEX idx_nom ON producteurs(nom)');

    // === TABLE ENQUETEURS ===
    await db.execute('''
      CREATE TABLE enqueteurs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code_enqueteur TEXT UNIQUE NOT NULL,
        nom TEXT NOT NULL,
        prenom TEXT NOT NULL,
        telephone TEXT,
        date_creation TEXT NOT NULL
      )
    ''');

    // === TABLE ZONES ===
    await db.execute('''
      CREATE TABLE zones(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code_zone TEXT UNIQUE NOT NULL,
        nom_zone TEXT NOT NULL
      )
    ''');

    // === TABLE ENQUETES ===
    await db.execute('''
      CREATE TABLE enquetes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code_enquete TEXT UNIQUE NOT NULL,
        producteur_id INTEGER NOT NULL,
        enqueteur_id INTEGER NOT NULL,
        zone_id INTEGER NOT NULL,
        date_debut TEXT NOT NULL,
        date_fin TEXT,
        statut TEXT DEFAULT 'en_cours',
        pdf_path TEXT,
        FOREIGN KEY (producteur_id) REFERENCES producteurs (id),
        FOREIGN KEY (enqueteur_id) REFERENCES enqueteurs (id),
        FOREIGN KEY (zone_id) REFERENCES zones (id)
      )
    ''');

    // === TABLE QUESTIONS ===
    await db.execute('''
      CREATE TABLE questions(
        id TEXT PRIMARY KEY,
        theme TEXT NOT NULL,
        numero INTEGER NOT NULL,
        libelle TEXT NOT NULL,
        type TEXT NOT NULL,
        options_json TEXT
      )
    ''');

    // === TABLE REPONSES AVEC CONTRAINTE UNIQUE ===
    await db.execute('''
      CREATE TABLE reponses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        enquete_id INTEGER NOT NULL,
        question_id TEXT NOT NULL,
        code_reponse TEXT,
        valeur TEXT,
        precision_text TEXT,
        date_reponse TEXT NOT NULL,
        UNIQUE(enquete_id, question_id),
        FOREIGN KEY (enquete_id) REFERENCES enquetes (id),
        FOREIGN KEY (question_id) REFERENCES questions (id)
      )
    ''');

    // === TABLE PHOTOS ===
    await db.execute('''
      CREATE TABLE photos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reponse_id INTEGER NOT NULL,
        chemin TEXT NOT NULL,
        date_prise TEXT NOT NULL,
        FOREIGN KEY (reponse_id) REFERENCES reponses (id)
      )
    ''');

    // === TABLE SIGNATURES (NOUVELLE) ===
    await db.execute('''
      CREATE TABLE signatures(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        enquete_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        chemin_fichier TEXT NOT NULL,
        date_signature TEXT NOT NULL,
        UNIQUE(enquete_id, type),
        FOREIGN KEY(enquete_id) REFERENCES enquetes(id) ON DELETE CASCADE
      )
    ''');

    // === INDEX POUR OPTIMISATION ===
    await _createIndexes(db);
    await _createFormationTable(db);
  }

  static Future<void> _createIndexes(Database db) async {
    // Index pour les performances des rapports
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reponses_enquete ON reponses(enquete_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reponses_question ON reponses(question_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reponses_date ON reponses(date_reponse)',
    );

    // Index pour les signatures
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_signatures_enquete ON signatures(enquete_id)',
    );

    // Index pour éviter deux enquêtes ouvertes pour un même producteur
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_enquete_unique_active 
      ON enquetes(producteur_id) 
      WHERE statut IN ('en_cours', 'en_attente_pdf')
    ''');
  }

  static Future<void> _upgradeToVersion7(Database db) async {
    // Migration préservant les données (pas de DROP TABLE)

    // 1. Sauvegarder les données existantes dans des tables temporaires
    await db.execute('ALTER TABLE reponses RENAME TO reponses_old');
    await db.execute('ALTER TABLE photos RENAME TO photos_old');
    await db.execute('ALTER TABLE questions RENAME TO questions_old');

    // 2. Créer les nouvelles tables
    await db.execute('''
      CREATE TABLE questions(
        id TEXT PRIMARY KEY,
        theme TEXT NOT NULL,
        numero INTEGER NOT NULL,
        libelle TEXT NOT NULL,
        type TEXT NOT NULL,
        options_json TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE reponses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        enquete_id INTEGER NOT NULL,
        question_id TEXT NOT NULL,
        code_reponse TEXT,
        valeur TEXT,
        precision_text TEXT,
        date_reponse TEXT NOT NULL,
        UNIQUE(enquete_id, question_id),
        FOREIGN KEY (enquete_id) REFERENCES enquetes (id),
        FOREIGN KEY (question_id) REFERENCES questions (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE photos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reponse_id INTEGER NOT NULL,
        chemin TEXT NOT NULL,
        date_prise TEXT NOT NULL,
        FOREIGN KEY (reponse_id) REFERENCES reponses (id)
      )
    ''');

    // 3. Réinsérer les données (gestion des conflits UNIQUE)
    await db.execute('''
      INSERT OR IGNORE INTO questions(id, theme, numero, libelle, type, options_json)
      SELECT id, theme, numero, libelle, type, options_json FROM questions_old
    ''');

    await db.execute('''
      INSERT OR REPLACE INTO reponses(id, enquete_id, question_id, code_reponse, valeur, precision_text, date_reponse)
      SELECT id, enquete_id, question_id, code_reponse, valeur, precision_text, date_reponse FROM reponses_old
    ''');

    await db.execute('''
      INSERT OR IGNORE INTO photos(id, reponse_id, chemin, date_prise)
      SELECT id, reponse_id, chemin, date_prise FROM photos_old
    ''');

    // 4. Supprimer les tables temporaires
    await db.execute('DROP TABLE IF EXISTS reponses_old');
    await db.execute('DROP TABLE IF EXISTS photos_old');
    await db.execute('DROP TABLE IF EXISTS questions_old');
  }

  static Future<void> _upgradeToVersion8(Database db) async {
    await _createIndexes(db);
    await _createFormationTable(db);
  }

  static Future<void> _upgradeToVersion9(Database db) async {
    // Migration pour ajouter la table signatures
    await db.execute('''
      CREATE TABLE signatures(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        enquete_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        chemin_fichier TEXT NOT NULL,
        date_signature TEXT NOT NULL,
        UNIQUE(enquete_id, type),
        FOREIGN KEY(enquete_id) REFERENCES enquetes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_signatures_enquete ON signatures(enquete_id)',
    );
  }

  static Future<void> _upgradeToVersion10(Database db) async {
    await db.execute('ALTER TABLE enquetes ADD COLUMN pdf_path TEXT');
    await db.execute('DROP INDEX IF EXISTS idx_enquete_unique_active');
    await db.execute(
      "CREATE UNIQUE INDEX idx_enquete_unique_active ON enquetes(producteur_id) WHERE statut IN ('en_cours', 'en_attente_pdf')",
    );
    await _createFormationTable(db);
  }

  static Future<void> _upgradeToVersion11(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(formations)');
    final dateFormationRequired = columns.any(
      (column) => column['name'] == 'date_formation' && column['notnull'] == 1,
    );
    final hasScheduledDate = columns.any(
      (column) => column['name'] == 'date_programmee',
    );

    if (dateFormationRequired) {
      await db.execute('ALTER TABLE formations RENAME TO formations_v10');
      await _createFormationTable(db);
      await db.execute('''
        INSERT INTO formations(
          id, enquete_id, date_programmee, date_formation, formateur, remarques
        )
        SELECT id, enquete_id, date_formation, date_formation, formateur, remarques
        FROM formations_v10
      ''');
      await db.execute('DROP TABLE formations_v10');
    } else if (!hasScheduledDate) {
      await db.execute(
        'ALTER TABLE formations ADD COLUMN date_programmee TEXT',
      );
    }
    await db.execute(
      'UPDATE formations SET date_programmee = date_formation WHERE date_programmee IS NULL AND date_formation IS NOT NULL',
    );
  }

  static Future<void> _upgradeToVersion12(Database db) async {
    // Retire la liste importee, tout en conservant les planteurs rattaches
    // a une enquete deja enregistree sur le telephone.
    await db.execute('''
      DELETE FROM producteurs
      WHERE id NOT IN (SELECT DISTINCT producteur_id FROM enquetes)
    ''');
  }

  static Future<void> _createFormationTable(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS formations(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      enquete_id INTEGER NOT NULL UNIQUE,
      date_programmee TEXT,
      date_formation TEXT,
      formateur TEXT,
      remarques TEXT,
      FOREIGN KEY(enquete_id) REFERENCES enquetes(id) ON DELETE CASCADE
    )''');
  }
  // ===============================
  // INSERTION DES DONNÉES DE BASE
  // ===============================

  static Future<void> _insertZones(Database db) async {
    await db.insert('zones', {'code_zone': 'ZN001', 'nom_zone': 'Zone Nord'});
    await db.insert('zones', {'code_zone': 'ZS001', 'nom_zone': 'Zone Sud'});
  }

  static Future<void> _insertEnqueteurs(Database db) async {
    await db.insert('enqueteurs', {
      'code_enqueteur': 'ENQ001',
      'nom': 'Dupont',
      'prenom': 'Jean',
      'telephone': '0708091011',
      'date_creation': DateTime.now().toIso8601String(),
    });
  }

  // ===============================
  // INSERTION DE TOUTES LES QUESTIONS (1 à 43 - SANS LE Q)
  // ===============================

  static Future<void> _insertAllQuestions(Database db) async {
    // === DROITS FONCIERS (1 à 8) ===
    await db.insert('questions', {
      'id': '1',
      'theme': 'DROITS FONCIERS',
      'numero': 1,
      'libelle': "Type d'autorisation pour utiliser le terrain :",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Documentation foncière"},
        {"code": "B", "libelle": "L'Utilisation est reconnue sans document"},
        {"code": "C", "libelle": "Utilisation non autorisée du terrain"},
      ]),
    });

    await db.insert('questions', {
      'id': '2',
      'theme': 'DROITS FONCIERS',
      'numero': 2,
      'libelle': 'Type de documentation :',
      'type': 'single_choice_with_precision',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Certificat foncier"},
        {"code": "B", "libelle": "Attestation coutumière"},
        {"code": "C", "libelle": "Contrat de location ou de métayage"},
        {
          "code": "D",
          "libelle": "Autres (veuillez préciser dans les remarques)",
        },
      ]),
    });

    await db.insert('questions', {
      'id': '3',
      'theme': 'DROITS FONCIERS',
      'numero': 3,
      'libelle': 'Numéro de référence de la documentation ?',
      'type': 'text',
    });

    await db.insert('questions', {
      'id': '4',
      'theme': 'DROITS FONCIERS',
      'numero': 4,
      'libelle': 'Image de la documentation',
      'type': 'image',
    });

    await db.insert('questions', {
      'id': '5',
      'theme': 'DROITS FONCIERS',
      'numero': 5,
      'libelle': "Comment l'utilisation du terrain est-elle reconnue ?",
      'type': 'single_choice_with_precision',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Démarcation physique coutumière"},
        {"code": "B", "libelle": "Occupation de longue durée"},
        {"code": "C", "libelle": "Autres (veuillez préciser)"},
      ]),
    });

    await db.insert('questions', {
      'id': '6',
      'theme': 'DROITS FONCIERS',
      'numero': 6,
      'libelle':
          "Téléchargez une image pour montrer comment l'utilisation des terres est reconnue ?",
      'type': 'image',
    });

    await db.insert('questions', {
      'id': '7',
      'theme': 'DROITS FONCIERS',
      'numero': 7,
      'libelle':
          "Pour une occupation de longue durée, en quelle année la plantation a-t-elle été établie ?",
      'type': 'year',
    });

    await db.insert('questions', {
      'id': '8',
      'theme': 'DROITS FONCIERS',
      'numero': 8,
      'libelle':
          "Veuillez préciser comment l'utilisation des terres est reconnue :",
      'type': 'text',
    });

    // === ENVIRONNEMENT (9 à 10) ===
    await db.insert('questions', {
      'id': '9',
      'theme': 'ENVIRONNEMENT',
      'numero': 9,
      'libelle':
          "Parmi les Produits chimiques suivants, lesquels sont utilisés sur le terrain (plusieurs options possibles) ?",
      'type': 'multiple_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Paraquat"},
        {"code": "B", "libelle": "Glyphosate (Roundup)"},
        {"code": "C", "libelle": "2-4D"},
        {"code": "D", "libelle": "Autres (veuillez préciser)"},
      ]),
    });

    await db.insert('questions', {
      'id': '10',
      'theme': 'ENVIRONNEMENT',
      'numero': 10,
      'libelle':
          "J'ai pris Connaissance de la liste des engrais et pesticides autorisés en Côte d'Ivoire ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "OUI"},
        {"code": "B", "libelle": "NON"},
      ]),
    });

    // === DROITS DES TIERS (11 à 12) ===
    await db.insert('questions', {
      'id': '11',
      'theme': 'DROITS DES TIERS',
      'numero': 11,
      'libelle':
          "Existe-t-il actuellement des litiges fonciers non résolus avec des groupes indigènes ou autochtones ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "OUI"},
        {"code": "B", "libelle": "NON"},
      ]),
    });

    await db.insert('questions', {
      'id': '12',
      'theme': 'DROITS DES TIERS',
      'numero': 12,
      'libelle': "Veuillez donner des précisions sur le litige foncier :",
      'type': 'text',
    });

    // === MÉNAGES (13 à 27) ===
    await db.insert('questions', {
      'id': '13',
      'theme': 'MÉNAGES',
      'numero': 13,
      'libelle':
          "Outre le planteur, y a-t-il d'autres membres du ménage qui séjournent sur la plantation ou dans ses environs ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "OUI"},
        {"code": "B", "libelle": "NON"},
      ]),
    });

    await db.insert('questions', {
      'id': '14',
      'theme': 'MÉNAGES',
      'numero': 14,
      'libelle': "Y a-t-il des membres du ménage âgés de plus de 18 ans ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "OUI"},
        {"code": "Z", "libelle": "NON"},
      ]),
    });

    await db.insert('questions', {
      'id': '15',
      'theme': 'MÉNAGES',
      'numero': 15,
      'libelle': "Nombre de membres du ménage âgés de plus de 18 ans",
      'type': 'number',
    });

    await db.insert('questions', {
      'id': '16',
      'theme': 'MÉNAGES',
      'numero': 16,
      'libelle': "Y a-t-il des membres du ménage âgés de 16 à 17 ans ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "B", "libelle": "OUI"},
        {"code": "Z", "libelle": "NON"},
      ]),
    });

    await db.insert('questions', {
      'id': '17',
      'theme': 'MÉNAGES',
      'numero': 17,
      'libelle': "Nombre de membres du ménage âgés de 16 à 17 ans",
      'type': 'number',
    });

    await db.insert('questions', {
      'id': '18',
      'theme': 'MÉNAGES',
      'numero': 18,
      'libelle':
          "Parmi les jeunes âgés de 16 à 17 ans, certains travaillent-ils sur la plantation ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "OUI"},
        {"code": "B", "libelle": "NON"},
      ]),
    });

    await db.insert('questions', {
      'id': '19',
      'theme': 'MÉNAGES',
      'numero': 19,
      'libelle':
          "Pour les personnes âgées de 16 à 17 ans, quelles activités leur sont confiées ? (Plusieurs options possibles)",
      'type': 'multiple_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Effectuer la saignée"},
        {"code": "B", "libelle": "Collecte du latex dans les tasses"},
        {"code": "C", "libelle": "Faire le Rabattage"},
        {"code": "D", "libelle": "Ramasser les graines d'hévéa"},
        {"code": "E", "libelle": "Semer les graines d'hévéa"},
        {"code": "F", "libelle": "Effectuer le trouaison"},
        {
          "code": "G",
          "libelle": "Pulvérisation de produits chimiques (herbicides, etc)",
        },
        {"code": "H", "libelle": "Aider au piquetage"},
        {
          "code": "I",
          "libelle": "Couvrir le caoutchouc stocké avec des bâches",
        },
        {"code": "J", "libelle": "Défrichage"},
        {"code": "K", "libelle": "Brûlage des parcelles"},
        {"code": "L", "libelle": "Autres (à préciser dans les remarques)"},
      ]),
    });

    await db.insert('questions', {
      'id': '20',
      'theme': 'MÉNAGES',
      'numero': 20,
      'libelle': "Y a-t-il des membres du ménage âgés de 13 à 15 ans ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "C", "libelle": "OUI"},
        {"code": "Z", "libelle": "NON"},
      ]),
    });

    await db.insert('questions', {
      'id': '21',
      'theme': 'MÉNAGES',
      'numero': 21,
      'libelle': "Nombre de membres du ménage âgés de 13 à 15 ans :",
      'type': 'number',
    });

    await db.insert('questions', {
      'id': '22',
      'theme': 'MÉNAGES',
      'numero': 22,
      'libelle':
          "Parmi les jeunes âgés de 13-15 ans, certains travaillent-ils sur la plantation ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "OUI"},
        {"code": "B", "libelle": "NON"},
      ]),
    });

    await db.insert('questions', {
      'id': '23',
      'theme': 'MÉNAGES',
      'numero': 23,
      'libelle':
          "Pour les personnes âgées de 13 à 15 ans, quelles activités leur sont confiées ? (Plusieurs options possibles)",
      'type': 'multiple_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Effectuer la saignée"},
        {"code": "B", "libelle": "Collecte du latex dans les tasses"},
        {"code": "C", "libelle": "Faire le rabattage"},
        {"code": "D", "libelle": "Ramasser les graines d'hévéa"},
        {"code": "E", "libelle": "Semer les graines d'hévéa"},
        {"code": "F", "libelle": "Effectuer la trouaison"},
        {
          "code": "G",
          "libelle": "Pulvérisation de produits chimiques (herbicides, etc.)",
        },
        {"code": "H", "libelle": "Aider au piquetage"},
        {
          "code": "I",
          "libelle": "Couvrir le caoutchouc stocké avec des bâches",
        },
        {"code": "J", "libelle": "Défrichage"},
        {"code": "K", "libelle": "Brûlage des parcelles"},
        {"code": "L", "libelle": "Autres (à préciser dans les remarques)"},
      ]),
    });

    await db.insert('questions', {
      'id': '24',
      'theme': 'MÉNAGES',
      'numero': 24,
      'libelle':
          "Pour les personnes âgées de 13 à 15 ans, quel est le nombre moyen d'heures de travail par jour ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Moins de 3 heures"},
        {"code": "B", "libelle": "Plus de 3 heures"},
      ]),
    });

    await db.insert('questions', {
      'id': '25',
      'theme': 'MÉNAGES',
      'numero': 25,
      'libelle': "Y a-t-il des membres du ménage âgés de moins de 13 ans ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "D", "libelle": "OUI"},
        {"code": "Z", "libelle": "NON"},
      ]),
    });

    await db.insert('questions', {
      'id': '26',
      'theme': 'MÉNAGES',
      'numero': 26,
      'libelle': "Nombre de membres du ménage âgés de moins de 13 ans",
      'type': 'number',
    });

    await db.insert('questions', {
      'id': '27',
      'theme': 'MÉNAGES',
      'numero': 27,
      'libelle':
          "Les personnes âgées de moins de 13 ans travaillent-elles sur la plantation ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "OUI"},
        {"code": "B", "libelle": "NON"},
      ]),
    });

    // === TRAVAILLEURS (28 à 41) ===
    await db.insert('questions', {
      'id': '28',
      'theme': 'TRAVAILLEURS',
      'numero': 28,
      'libelle': "Y a-t-il des travailleurs dans l'exploitation ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Oui (travailleurs réguliers/occasionnels)"},
        {"code": "B", "libelle": "Pas de travailleurs"},
      ]),
    });

    await db.insert('questions', {
      'id': '29',
      'theme': 'TRAVAILLEURS',
      'numero': 29,
      'libelle': "Type de consentement accordé par les travailleurs :",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Consentement écrit"},
        {"code": "B", "libelle": "Consentement verbal"},
        {"code": "C", "libelle": "Absence de consentement"},
      ]),
    });

    await db.insert('questions', {
      'id': '30',
      'theme': 'TRAVAILLEURS',
      'numero': 30,
      'libelle': "Comment le salaire des travailleurs est-il calculé ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Participation aux bénéfices"},
        {"code": "B", "libelle": "Volume"},
        {"code": "C", "libelle": "Jour"},
        {"code": "D", "libelle": "Tâche"},
        {"code": "E", "libelle": "Fixe mensuel"},
      ]),
    });

    await db.insert('questions', {
      'id': '31',
      'theme': 'TRAVAILLEURS',
      'numero': 31,
      'libelle': "Revenu mensuel des travailleurs (FCFA) ?",
      'type': 'number',
    });

    await db.insert('questions', {
      'id': '32',
      'theme': 'TRAVAILLEURS',
      'numero': 32,
      'libelle': "Temps de travail hebdomadaire moyen des travailleurs ?",
      'type': 'number',
    });

    await db.insert('questions', {
      'id': '33',
      'theme': 'TRAVAILLEURS',
      'numero': 33,
      'libelle': "Y a-t-il des travailleurs âgés de 18 ans et plus ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "OUI"},
        {"code": "Z", "libelle": "NON"},
      ]),
    });

    await db.insert('questions', {
      'id': '34',
      'theme': 'TRAVAILLEURS',
      'numero': 34,
      'libelle': "Nombre de travailleurs âgés de 18 ans et plus",
      'type': 'number',
    });

    await db.insert('questions', {
      'id': '35',
      'theme': 'TRAVAILLEURS',
      'numero': 35,
      'libelle': "Y a-t-il des travailleurs âgés de 16 à 17 ans ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "B", "libelle": "Oui"},
        {"code": "Z", "libelle": "Non"},
      ]),
    });

    await db.insert('questions', {
      'id': '36',
      'theme': 'TRAVAILLEURS',
      'numero': 36,
      'libelle': "Nombre de travailleurs entre 16-17 ans",
      'type': 'number',
    });

    await db.insert('questions', {
      'id': '37',
      'theme': 'TRAVAILLEURS',
      'numero': 37,
      'libelle':
          "Pour les personnes âgées de 13 à 15 ans, quelles activités leur sont confiées ? (Plusieurs options possibles)",
      'type': 'multiple_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Effectuer la saignée"},
        {"code": "B", "libelle": "Collecte du latex dans les tasses"},
        {"code": "C", "libelle": "Faire le rabattage"},
        {"code": "D", "libelle": "Ramasser les graines"},
        {"code": "E", "libelle": "Semer les graines"},
        {"code": "F", "libelle": "Effectuer la Trouaison"},
        {
          "code": "G",
          "libelle": "Pulvérisation de produits chimiques (herbicides, etc.)",
        },
        {"code": "H", "libelle": "Aider au piquetage"},
        {
          "code": "I",
          "libelle": "Couvrir le caoutchouc stocké avec des bâches",
        },
        {"code": "J", "libelle": "Défrichage"},
        {"code": "K", "libelle": "Brûlage des parcelles"},
        {"code": "L", "libelle": "Autres (à préciser dans les remarques)"},
      ]),
    });

    await db.insert('questions', {
      'id': '38',
      'theme': 'TRAVAILLEURS',
      'numero': 38,
      'libelle': "Y a-t-il des travailleurs de moins de 16 ans ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "C", "libelle": "OUI"},
        {"code": "Z", "libelle": "NON"},
      ]),
    });

    await db.insert('questions', {
      'id': '39',
      'theme': 'TRAVAILLEURS',
      'numero': 39,
      'libelle':
          "Y a-t-il des Travailleurs étrangers ? (En provenance d'un autre pays)",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Oui, au moins un travailleur étranger"},
        {"code": "B", "libelle": "Non, seulement les travailleurs locaux"},
      ]),
    });

    await db.insert('questions', {
      'id': '40',
      'theme': 'TRAVAILLEURS',
      'numero': 40,
      'libelle':
          "Les documents d'identité originaux des travailleurs étrangers sont-ils conservés ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "OUI"},
        {"code": "B", "libelle": "NON"},
      ]),
    });

    await db.insert('questions', {
      'id': '41',
      'theme': 'TRAVAILLEURS',
      'numero': 41,
      'libelle':
          "Les travailleurs étrangers doivent-ils verser des droits pour obtenir un travail sur la ferme ?",
      'type': 'single_choice',
      'options_json': jsonEncode([
        {"code": "A", "libelle": "Dépôt de garantie (financier, bien ou)"},
        {
          "code": "B",
          "libelle": "Frais de recrutement remboursés au travailleur",
        },
        {
          "code": "C",
          "libelle": "Frais de recrutement non remboursés au travailleur",
        },
        {"code": "D", "libelle": "Ne payent rien"},
      ]),
    });

    // === REVENU EXPLOITANT (42 à 43) ===
    await db.insert('questions', {
      'id': '42',
      'theme': 'REVENU EXPLOITANT',
      'numero': 42,
      'libelle': "Quel est le revenu mensuel moyen du fermier (FCFA) ?",
      'type': 'number',
    });

    await db.insert('questions', {
      'id': '43',
      'theme': 'REVENU EXPLOITANT',
      'numero': 43,
      'libelle':
          "Quel pourcentage du revenu mensuel du fermier est généré par les activités liées au caoutchouc ?",
      'type': 'percentage',
    });
  }

  // ===============================
  // MÉTHODES UTILITAIRES
  // ===============================

  static String fixPhone(String phone) {
    phone = phone.trim();
    phone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.isEmpty) return "";
    while (phone.length < 10) {
      phone = "0$phone";
    }
    return phone;
  }

  // ===============================
  // GARANTIR L’IMPORT DES PRODUCTEURS
  static Future<List<Map<String, dynamic>>> searchByCode(String code) async {
    final db = await database;
    String queryCode = code.trim().toUpperCase();
    final allowedVillages = await assignedVillages;
    if (allowedVillages.isEmpty) return [];

    return await db.rawQuery(
      '''
      SELECT * FROM producteurs
      WHERE UPPER(code_phi) = ?
        AND lower(trim(village)) IN (${List.filled(allowedVillages.length, '?').join(',')})
      LIMIT 1
    ''',
      [queryCode, ...allowedVillages.map((village) => village.trim().toLowerCase())],
    );
  }

  static Future<List<String>> get assignedVillages async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('rubberway.agent.section.villages') ?? [];
  }

  static Future<List<Map<String, dynamic>>> searchGlobal(String value) async {
    final db = await database;
    String queryValue = value.trim().toUpperCase();
    final allowedVillages = await assignedVillages;
    if (allowedVillages.isEmpty) return [];

    return await db.rawQuery(
      '''
      SELECT * FROM producteurs
      WHERE (UPPER(code_phi) LIKE ? OR UPPER(nom) LIKE ?)
        AND lower(trim(village)) IN (${List.filled(allowedVillages.length, '?').join(',')})
      ORDER BY nom ASC
      LIMIT 50
    ''',
      ['%$queryValue%', '%$queryValue%', ...allowedVillages.map((village) => village.trim().toLowerCase())],
    );
  }

  static Future<void> cacheAssignedProducers(List<Map<String, dynamic>> producers) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var start = 0; start < producers.length; start += 400) {
        final chunk = producers.skip(start).take(400).toList();
        final valid = chunk.where((producer) => (producer['code_phi'] ?? '').toString().trim().isNotEmpty).toList();
        if (valid.isEmpty) continue;
        final codes = valid.map((producer) => (producer['code_phi'] ?? '').toString().trim().toUpperCase()).toSet().toList();
        final existingRows = await txn.rawQuery(
          'SELECT id, UPPER(code_phi) AS normalized_code FROM producteurs WHERE UPPER(code_phi) IN (${List.filled(codes.length, '?').join(',')})',
          codes,
        );
        final existingIds = <String, Object?>{};
        for (final row in existingRows) {
          existingIds.putIfAbsent(row['normalized_code'].toString(), () => row['id']);
        }
        final batch = txn.batch();
        for (final producer in valid) {
          final code = (producer['code_phi'] ?? '').toString().trim();
          final values = {
            'code_phi': code,
            'nom': (producer['nom'] ?? '').toString(),
            'contact': (producer['contact'] ?? '').toString(),
            'village': (producer['village'] ?? '').toString(),
          };
          final id = existingIds[code.toUpperCase()];
          if (id == null) {
            batch.insert('producteurs', values);
          } else {
            batch.update('producteurs', values, where: 'id = ?', whereArgs: [id]);
          }
        }
        await batch.commit(noResult: true);
      }
    });
  }

  // ===============================
  // MÉTHODES POUR ENQUETEURS
  // ===============================

  static Future<int> saveEnqueteur({
    required String codeEnqueteur,
    required String nom,
    required String prenom,
    String? telephone,
  }) async {
    final db = await database;
    return await db.insert('enqueteurs', {
      'code_enqueteur': codeEnqueteur,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone ?? '',
      'date_creation': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>?> getEnqueteurByNom(String nom) async {
    final db = await database;
    final results = await db.query(
      'enqueteurs',
      where: 'nom = ?',
      whereArgs: [nom],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  // ===============================
  // MÉTHODES POUR ZONES
  // ===============================

  static Future<int> getOrCreateZone(String nomZone) async {
    final db = await database;

    final results = await db.query(
      'zones',
      where: 'nom_zone = ?',
      whereArgs: [nomZone],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first['id'] as int;
    }

    return await db.insert('zones', {
      'code_zone': 'Z${DateTime.now().millisecondsSinceEpoch}',
      'nom_zone': nomZone,
    });
  }

  // ===============================
  // MÉTHODES POUR ENQUETES
  // ===============================

  static Future<int?> createEnquete({
    required int producteurId,
    required int enqueteurId,
    required int zoneId,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now();
      final year = now.year.toString();

      return await db.transaction((txn) async {
        final active = await txn.query(
          'enquetes',
          where: 'producteur_id = ? AND statut IN (?, ?)',
          whereArgs: [producteurId, 'en_cours', 'en_attente_pdf'],
          limit: 1,
        );
        if (active.isNotEmpty) return active.first['id'] as int;

        final sameYear = await txn.query(
          'enquetes',
          where: 'producteur_id = ? AND substr(date_debut, 1, 4) = ?',
          whereArgs: [producteurId, year],
          orderBy: 'date_debut ASC',
        );

        if (sameYear.isNotEmpty) {
          if (sameYear.length >= 2) {
            throw StateError(
              'La reprise annuelle a déjà été utilisée pour ce planteur.',
            );
          }

          final firstSurvey = sameYear.first;
          if (firstSurvey['statut'] != 'termine' ||
              firstSurvey['pdf_path'] == null) {
            throw StateError(
              'Une enquête existe déjà pour ce planteur cette année.',
            );
          }

          final firstId = firstSurvey['id'] as int;
          if (!await _hasNonConformity(txn, firstId)) {
            throw StateError(
              'Une enquête conforme existe déjà pour ce planteur cette année.',
            );
          }

          final completedTraining = await txn.query(
            'formations',
            columns: ['id'],
            where:
                'enquete_id = ? AND date_programmee IS NOT NULL AND date_formation IS NOT NULL',
            whereArgs: [firstId],
            limit: 1,
          );
          if (completedTraining.isEmpty) {
            throw StateError(
              'La reprise est autorisée après la réalisation de la formation du planteur.',
            );
          }
        }

        return await txn.insert('enquetes', {
          'code_enquete': 'ENQ${now.millisecondsSinceEpoch}',
          'producteur_id': producteurId,
          'enqueteur_id': enqueteurId,
          'zone_id': zoneId,
          'date_debut': now.toIso8601String(),
          'statut': 'en_cours',
        });
      });
    } on StateError {
      rethrow;
    } catch (e) {
      debugPrint('Erreur création enquête: $e');
      return null;
    }
  }

  static Future<bool> _hasNonConformity(
    DatabaseExecutor db,
    int enqueteId,
  ) async {
    final answers = await db.query(
      'reponses',
      columns: ['question_id', 'code_reponse'],
      where: 'enquete_id = ?',
      whereArgs: [enqueteId],
    );
    final byQuestion = <String, List<String>>{};
    for (final answer in answers) {
      byQuestion
          .putIfAbsent('${answer['question_id']}', () => [])
          .add('${answer['code_reponse'] ?? ''}');
    }
    String code(String question) => byQuestion[question]?.first ?? '';
    bool selected(String question, String option) =>
        (byQuestion[question] ?? []).any(
          (value) =>
              value.split(',').map((part) => part.trim()).contains(option),
        );

    const dangerousActivities = ['A', 'C', 'F', 'G', 'J', 'K'];
    return code('1') == 'C' ||
        selected('9', 'A') ||
        selected('9', 'C') ||
        code('11') == 'A' ||
        ['19', '23', '37'].any(
          (question) =>
              dangerousActivities.any((option) => selected(question, option)),
        ) ||
        code('24') == 'B' ||
        code('27') == 'A' ||
        code('29') == 'C' ||
        code('40') == 'A' ||
        ['A', 'B', 'C'].any((option) => selected('41', option));
  }

  static Future<void> terminerEnquete(int enqueteId) async {
    final db = await database;
    await db.update(
      'enquetes',
      {
        'date_fin': DateTime.now().toIso8601String(),
        'statut': 'en_attente_pdf',
      },
      where: 'id = ?',
      whereArgs: [enqueteId],
    );
  }

  // ===============================
  // MÉTHODES POUR PRODUCTEURS
  // ===============================

  static Future<int> getNombreEnquetesAvecPdf() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM enquetes WHERE statut = 'termine' AND pdf_path IS NOT NULL AND pdf_path IS NOT NULL",
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  static Future<void> marquerEnqueteAvecPdf(
    int enqueteId,
    String cheminPdf,
  ) async {
    final db = await database;
    final updated = await db.update(
      'enquetes',
      {
        'date_fin': DateTime.now().toIso8601String(),
        'statut': 'termine',
        'pdf_path': cheminPdf,
      },
      where: 'id = ?',
      whereArgs: [enqueteId],
    );
    if (updated == 0) {
      throw StateError(
        'Enquête introuvable dans la base de données (ID $enqueteId).',
      );
    }
  }

  static Future<List<Map<String, dynamic>>> getEnquetesPourFormation() async {
    final db = await database;
    await _createFormationTable(db);
    final rows = await db.rawQuery('''
      SELECT e.id, e.producteur_id, e.enqueteur_id, e.code_enquete, e.date_debut, e.date_fin,
             e.pdf_path, e.zone_id, p.code_phi, p.nom AS nom_producteur,
             p.village, z.nom_zone, f.date_programmee, f.date_formation,
             f.formateur, f.remarques,
             (SELECT COUNT(*) FROM enquetes e2
              WHERE e2.producteur_id = e.producteur_id
                AND substr(e2.date_debut, 1, 4) = substr(e.date_debut, 1, 4)
             ) AS nombre_enquetes_annee
      FROM enquetes e
      JOIN producteurs p ON p.id = e.producteur_id
      LEFT JOIN zones z ON z.id = e.zone_id
      LEFT JOIN formations f ON f.enquete_id = e.id
      WHERE e.statut = 'termine' AND e.pdf_path IS NOT NULL
      ORDER BY e.date_fin ASC
    ''');

    final result = <Map<String, dynamic>>[];
    final processedProducerYears = <String>{};
    for (final row in rows) {
      final answers = await getReponsesByEnquete(row['id'] as int);
      final byQuestion = <String, List<String>>{};
      for (final answer in answers) {
        byQuestion
            .putIfAbsent('${answer['question_id']}', () => [])
            .add('${answer['code_reponse'] ?? ''}');
      }
      String code(String id) => byQuestion[id]?.first ?? '';
      bool selected(String id, String option) => (byQuestion[id] ?? []).any(
        (value) => value.split(',').map((part) => part.trim()).contains(option),
      );

      const dangerousActivities = ['A', 'C', 'F', 'G', 'J', 'K'];
      final criteria = <String>[];
      if (code('1') == 'C')
        criteria.add('Q1 - Utilisation non autorisée du terrain');
      if (selected('9', 'A') || selected('9', 'C')) {
        criteria.add('Q9 - Produits chimiques signalés');
      }
      if (code('11') == 'A') criteria.add('Q11 - Litige foncier non résolu');
      if (['19', '23', '37'].any(
        (question) =>
            dangerousActivities.any((option) => selected(question, option)),
      )) {
        criteria.add(
          'Q19/Q23/Q37 - Activité dangereuse impliquant des mineurs',
        );
      }
      if (code('24') == 'B')
        criteria.add('Q24 - Durée de travail non conforme');
      if (code('27') == 'A')
        criteria.add('Q27 - Travail déclaré pour les moins de 13 ans');
      if (code('29') == 'C') criteria.add('Q29 - Consentement non conforme');
      if (code('40') == 'A')
        criteria.add(
          'Q40 - Documents des travailleurs étrangers non conservés',
        );
      if (['A', 'B', 'C'].contains(code('41'))) {
        criteria.add('Q41 - Frais exigés aux travailleurs étrangers');
      }

      if (criteria.isEmpty) continue;
      final year =
          DateTime.tryParse('${row['date_debut']}')?.year.toString() ?? '';
      final key = '${row['producteur_id']}_$year';
      if (processedProducerYears.add(key)) {
        result.add({...row, 'criteres_non_conformes': criteria});
      }
    }
    return result;
  }

  static Future<void> planifierFormation({
    required int enqueteId,
    required DateTime dateProgrammee,
  }) async {
    final db = await database;
    await _createFormationTable(db);
    final existing = await db.query(
      'formations',
      columns: ['date_formation'],
      where: 'enquete_id = ?',
      whereArgs: [enqueteId],
      limit: 1,
    );
    if (existing.isNotEmpty && existing.first['date_formation'] != null) {
      throw StateError('Cette formation est déjà marquée comme réalisée.');
    }
    await db.insert('formations', {
      'enquete_id': enqueteId,
      'date_programmee': dateProgrammee.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> enregistrerFormation({
    required int enqueteId,
    required String formateur,
    required String remarques,
  }) async {
    final db = await database;
    await _createFormationTable(db);
    final scheduled = await db.query(
      'formations',
      columns: ['date_programmee', 'date_formation'],
      where: 'enquete_id = ?',
      whereArgs: [enqueteId],
      limit: 1,
    );
    if (scheduled.isEmpty || scheduled.first['date_programmee'] == null) {
      throw StateError(
        'Planifiez la formation avant de l’enregistrer comme réalisée.',
      );
    }
    if (scheduled.first['date_formation'] != null) {
      throw StateError('Cette formation est déjà enregistrée comme réalisée.');
    }
    final plannedDate = DateTime.tryParse(
      '${scheduled.first['date_programmee'] ?? ''}',
    );
    if (plannedDate == null || plannedDate.isAfter(DateTime.now())) {
      throw StateError('La date prévue de formation n’est pas encore arrivée.');
    }
    await db.update(
      'formations',
      {
        'date_formation': DateTime.now().toIso8601String(),
        'formateur': formateur,
        'remarques': remarques,
      },
      where: 'enquete_id = ?',
      whereArgs: [enqueteId],
    );
  }

  static Future<Map<String, int>> getStatistiquesActivite({
    required DateTime debut,
    required DateTime fin,
    int? zoneId,
    int? enqueteurId,
  }) async {
    final db = await database;
    final from = DateFormat('yyyy-MM-dd').format(debut);
    final to = DateFormat(
      'yyyy-MM-dd',
    ).format(fin.add(const Duration(days: 1)));
    final zoneClause = zoneId == null ? '' : ' AND zone_id = ?';
    final agentClause = enqueteurId == null ? '' : ' AND enqueteur_id = ?';
    final args = <Object?>[
      from,
      to,
      if (zoneId != null) zoneId,
      if (enqueteurId != null) enqueteurId,
    ];
    Future<int> count(String condition) async {
      final rows = await db.rawQuery(
        "SELECT COUNT(*) AS total FROM enquetes WHERE $condition AND date_debut >= ? AND date_debut < ?$zoneClause$agentClause",
        args,
      );
      return (rows.first['total'] as num?)?.toInt() ?? 0;
    }

    final total = await count('1=1');
    final realRows = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM enquetes WHERE statut = 'termine' AND pdf_path IS NOT NULL AND date_fin >= ? AND date_fin < ?$zoneClause$agentClause",
      args,
    );
    final realisees = (realRows.first['total'] as num?)?.toInt() ?? 0;
    final enCours = await count("statut IN ('en_cours', 'en_attente_pdf')");
    final refusees = await count("statut = 'refuse'");
    final nonConformes = (await getEnquetesPourFormation()).where((e) {
      final date = DateTime.tryParse('${e['date_fin'] ?? ''}');
      return date != null &&
          !date.isBefore(debut) &&
          date.isBefore(fin.add(const Duration(days: 1))) &&
          (zoneId == null || e['zone_id'] == zoneId) &&
          (enqueteurId == null || e['enqueteur_id'] == enqueteurId);
    }).length;
    await _createFormationTable(db);
    final formations = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM formations f JOIN enquetes e ON e.id=f.enquete_id WHERE e.date_fin >= ? AND e.date_fin < ?${zoneId == null ? '' : ' AND e.zone_id = ?'}${enqueteurId == null ? '' : ' AND e.enqueteur_id = ?'}",
      [from, to, if (zoneId != null) zoneId, if (enqueteurId != null) enqueteurId],
    );
    final formationsPlanifiees = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM formations f JOIN enquetes e ON e.id=f.enquete_id WHERE f.date_programmee >= ? AND f.date_programmee < ?${zoneId == null ? '' : ' AND e.zone_id = ?'}${enqueteurId == null ? '' : ' AND e.enqueteur_id = ?'}",
      [from, to, if (zoneId != null) zoneId, if (enqueteurId != null) enqueteurId],
    );
    final formationsRealisees = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM formations f JOIN enquetes e ON e.id=f.enquete_id WHERE f.date_formation >= ? AND f.date_formation < ?${zoneId == null ? '' : ' AND e.zone_id = ?'}${enqueteurId == null ? '' : ' AND e.enqueteur_id = ?'}",
      [from, to, if (zoneId != null) zoneId, if (enqueteurId != null) enqueteurId],
    );
    return {
      'total': total,
      'realisees': realisees,
      'en_cours': enCours,
      'refusees': refusees,
      'non_conformes': nonConformes,
      'formations': (formations.first['total'] as num?)?.toInt() ?? 0,
      'formations_planifiees':
          (formationsPlanifiees.first['total'] as num?)?.toInt() ?? 0,
      'formations_realisees':
          (formationsRealisees.first['total'] as num?)?.toInt() ?? 0,
    };
  }

  static Future<List<Map<String, dynamic>>> getDetailsStatistiquesActivite({
    required DateTime debut,
    required DateTime fin,
    int? zoneId,
    int? enqueteurId,
  }) async {
    final db = await database;
    final from = DateFormat('yyyy-MM-dd').format(debut);
    final to = DateFormat(
      'yyyy-MM-dd',
    ).format(fin.add(const Duration(days: 1)));
    final zoneClause = zoneId == null ? '' : ' AND e.zone_id = ?';
    final agentClause = enqueteurId == null ? '' : ' AND e.enqueteur_id = ?';
    final rows = await db.rawQuery(
      '''
      SELECT e.id, e.code_enquete, e.date_debut, e.date_fin, e.statut,
             e.pdf_path, p.nom AS nom_producteur, p.code_phi, p.village,
             z.nom_zone, q.nom AS nom_agent, q.prenom AS prenom_agent,
             f.date_programmee, f.date_formation
      FROM enquetes e
      LEFT JOIN producteurs p ON p.id = e.producteur_id
      LEFT JOIN zones z ON z.id = e.zone_id
      LEFT JOIN enqueteurs q ON q.id = e.enqueteur_id
      LEFT JOIN formations f ON f.enquete_id = e.id
      WHERE COALESCE(e.date_fin, e.date_debut) >= ?
        AND COALESCE(e.date_fin, e.date_debut) < ?$zoneClause$agentClause
      ORDER BY COALESCE(e.date_fin, e.date_debut) DESC
    ''',
      [from, to, if (zoneId != null) zoneId, if (enqueteurId != null) enqueteurId],
    );

    final details = <Map<String, dynamic>>[];
    for (final row in rows) {
      final isCompleted = row['statut'] == 'termine' && row['pdf_path'] != null;
      final isNonConforming = isCompleted
          ? await _hasNonConformity(db, row['id'] as int)
          : false;
      details.add({
        ...row,
        'is_realisee': isCompleted,
        'is_non_conforme': isNonConforming,
      });
    }
    return details;
  }

  static Future<int> getProducteurIdByCode(String codeProducteur) async {
    final db = await database;
    final results = await db.query(
      'producteurs',
      where: 'code_phi = ?',
      whereArgs: [codeProducteur],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first['id'] as int;
    }
    return -1;
  }

  static Future<Map<String, dynamic>?> getProducteurByCode(
    String codePhi,
  ) async {
    final db = await database;
    final results = await db.query(
      'producteurs',
      where: 'code_phi = ?',
      whereArgs: [codePhi],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  static Future<int> createProducteur({
    required String codePhi,
    required String nom,
    required String contact,
    required String village,
  }) async {
    final db = await database;
    final normalizedCode = codePhi.trim().toUpperCase();
    final existing = await db.query(
      'producteurs',
      columns: ['id'],
      where: 'UPPER(code_phi) = ?',
      whereArgs: [normalizedCode],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await db.update(
        'producteurs',
        {
          'code_phi': normalizedCode,
          'nom': nom.trim().toUpperCase(),
          'contact': contact,
          'village': village.trim(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return id;
    }
    return db.insert('producteurs', {
      'code_phi': normalizedCode,
      'nom': nom.trim().toUpperCase(),
      'contact': contact,
      'village': village.trim(),
    });
  }

  // NORMALISATION DES CONTACTS (CI)
  // ===============================
  static String normalizeIvorianPhone(String raw) {
    if (raw.isEmpty) return "";

    // Supprimer tout ce qui n'est pas chiffre
    String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    // Cas 1 : +225XXXXXXXXX
    if (digits.startsWith('225') && digits.length == 12) {
      return '0${digits.substring(3)}';
    }

    // Cas 2 : XXXXXXXXX (9 chiffres, zéro perdu)
    if (digits.length == 9) {
      return '0$digits';
    }

    // Cas 3 : déjà correct
    if (digits.length == 10 && digits.startsWith('0')) {
      return digits;
    }

    // Cas 4 : 10 chiffres mais pas de 0 au début
    if (digits.length == 10 && !digits.startsWith('0')) {
      return '0${digits.substring(1)}';
    }

    // Cas non reconnu → on retourne tel quel
    return digits;
  }

  // ===============================
  // NORMALISATION DES NUMÉROS MULTIPLES
  // ===============================
  static String normalizeMultiplePhones(String raw) {
    if (raw.isEmpty) return "";

    // Séparer par les espaces
    final parts = raw.split(RegExp(r'\s+'));

    // Normaliser chaque partie et garder celles valides
    final normalized = parts
        .map(normalizeIvorianPhone)
        .where((p) => p.length == 10)
        .toList();

    if (normalized.isEmpty) return "";
    if (normalized.length == 1) return normalized.first;

    // Joindre avec " / " pour les numéros multiples
    return normalized.join(' / ');
  }

  // ===============================
  static Future<int> saveReponse({
    required int enqueteId,
    required String questionId, // Doit être '1', '2', etc. (sans Q)
    String? codeReponse,
    String? valeur,
    String? precision,
  }) async {
    final db = await database;

    // Vérifier si la réponse existe déjà pour cette enquête et cette question
    final existing = await db.query(
      'reponses',
      where: 'enquete_id = ? AND question_id = ?',
      whereArgs: [enqueteId, questionId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // ✅ MISE À JOUR : la réponse existe déjà
      await db.update(
        'reponses',
        {
          'code_reponse': codeReponse,
          'valeur': valeur,
          'precision_text': precision,
          'date_reponse': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return existing.first['id'] as int;
    } else {
      // ✅ INSERTION : nouvelle réponse
      return await db.insert('reponses', {
        'enquete_id': enqueteId,
        'question_id': questionId,
        'code_reponse': codeReponse,
        'valeur': valeur,
        'precision_text': precision,
        'date_reponse': DateTime.now().toIso8601String(),
      });
    }
  }

  // ===============================
  // MÉTHODES POUR PHOTOS
  // ===============================

  static Future<void> savePhoto({
    required int reponseId,
    required String chemin,
  }) async {
    final db = await database;
    await db.insert('photos', {
      'reponse_id': reponseId,
      'chemin': chemin,
      'date_prise': DateTime.now().toIso8601String(),
    });
  }

  // ===============================
  // MÉTHODES POUR SIGNATURES (NOUVELLES)
  // ===============================

  /// Sauvegarde ou met à jour une signature
  /// Utilise ConflictAlgorithm.replace pour mettre à jour si elle existe déjà
  static Future<void> saveSignature({
    required int enqueteId,
    required String type, // 'agent' ou 'planteur'
    required String chemin,
  }) async {
    final db = await database;

    await db.insert('signatures', {
      'enquete_id': enqueteId,
      'type': type,
      'chemin_fichier': chemin,
      'date_signature': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    debugPrint('✅ Signature $type sauvegardée pour enquête $enqueteId');
  }

  /// Récupère le chemin d'une signature
  static Future<String?> getSignature({
    required int enqueteId,
    required String type,
  }) async {
    final db = await database;

    final res = await db.query(
      'signatures',
      where: 'enquete_id = ? AND type = ?',
      whereArgs: [enqueteId, type],
      limit: 1,
    );

    return res.isNotEmpty ? res.first['chemin_fichier'] as String : null;
  }

  /// Récupère toutes les signatures d'une enquête
  static Future<Map<String, String>> getAllSignaturesForEnquete(
    int enqueteId,
  ) async {
    final db = await database;

    final res = await db.query(
      'signatures',
      where: 'enquete_id = ?',
      whereArgs: [enqueteId],
    );

    Map<String, String> signatures = {};
    for (var row in res) {
      signatures[row['type']?.toString() ?? ''] =
          row['chemin_fichier']?.toString() ?? '';
    }
    return signatures;
  }

  /// Supprime une signature (si nécessaire)
  static Future<void> deleteSignature({
    required int enqueteId,
    required String type,
  }) async {
    final db = await database;

    await db.delete(
      'signatures',
      where: 'enquete_id = ? AND type = ?',
      whereArgs: [enqueteId, type],
    );

    debugPrint('🗑️ Signature $type supprimée pour enquête $enqueteId');
  }

  // ===============================
  // MÉTHODES POUR LE PDF
  // ===============================

  static Future<Map<String, dynamic>?> getInfosEnquete(int enqueteId) async {
    final db = await database;
    final results = await db.rawQuery(
      '''
      SELECT 
        e.id as enquete_id,
        e.code_enquete,
        e.date_debut,
        e.date_fin,
        e.statut,
        p.code_phi as code_producteur,
        p.nom as nom_producteur,
        p.contact,
        p.village,
        en.nom as nom_enqueteur,
        en.prenom as prenom_enqueteur,
        z.nom_zone
      FROM enquetes e
      LEFT JOIN producteurs p ON e.producteur_id = p.id
      LEFT JOIN enqueteurs en ON e.enqueteur_id = en.id
      LEFT JOIN zones z ON e.zone_id = z.id
      WHERE e.id = ?
    ''',
      [enqueteId],
    );

    return results.isNotEmpty ? results.first : null;
  }

  static Future<List<Map<String, dynamic>>> getReponsesByEnquete(
    int enqueteId,
  ) async {
    final db = await database;
    return await db.rawQuery(
      '''
      SELECT 
        q.id as question_id,
        q.numero as reference,
        q.libelle as question_texte,
        q.type,
        r.code_reponse,
        r.valeur,
        r.precision_text,
        r.date_reponse
      FROM reponses r
      INNER JOIN questions q ON r.question_id = q.id
      WHERE r.enquete_id = ?
      ORDER BY q.numero
    ''',
      [enqueteId],
    );
  }

  static Future<List<Map<String, dynamic>>> getPhotosByReponse(
    int reponseId,
  ) async {
    final db = await database;
    return await db.query(
      'photos',
      where: 'reponse_id = ?',
      whereArgs: [reponseId],
    );
  }

  static Future<Map<String, String>> getAllPhotosForEnquete(
    int enqueteId,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 
        r.question_id,
        p.chemin
      FROM photos p
      INNER JOIN reponses r ON p.reponse_id = r.id
      WHERE r.enquete_id = ?
    ''',
      [enqueteId],
    );

    Map<String, String> photos = {};
    for (var row in result) {
      photos[row['question_id']?.toString() ?? ''] =
          row['chemin']?.toString() ?? '';
    }
    return photos;
  }

  // ===============================
  // MÉTHODES D'EXPORT
  // ===============================

  static Future<List<Map<String, dynamic>>> getReponsesForExport({
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    final db = await database;

    final debut = DateTime(
      dateDebut.year,
      dateDebut.month,
      dateDebut.day,
      0,
      0,
      0,
    );
    final fin = DateTime(dateFin.year, dateFin.month, dateFin.day, 23, 59, 59);

    return await db.rawQuery(
      '''
      SELECT 
        p.code_phi,
        q.id as question_id,
        q.numero as reference,
        r.code_reponse,
        r.valeur,
        r.precision_text as remarque,
        r.date_reponse,
        e.nom || ' ' || e.prenom as operateur,
        z.nom_zone as zone
      FROM reponses r
      INNER JOIN enquetes enq ON r.enquete_id = enq.id
      INNER JOIN producteurs p ON enq.producteur_id = p.id
      INNER JOIN enqueteurs e ON enq.enqueteur_id = e.id
      INNER JOIN zones z ON enq.zone_id = z.id
      INNER JOIN questions q ON r.question_id = q.id
      WHERE datetime(r.date_reponse) BETWEEN datetime(?) AND datetime(?)
      ORDER BY p.code_phi, r.date_reponse
    ''',
      [debut.toIso8601String(), fin.toIso8601String()],
    );
  }

  static Future<List<Map<String, dynamic>>> getAllReponsesForExport() async {
    final db = await database;

    return await db.rawQuery('''
      SELECT 
        p.code_phi,
        q.id as question_id,
        q.numero as reference,
        r.code_reponse,
        r.valeur,
        r.precision_text as remarque,
        r.date_reponse,
        e.nom || ' ' || e.prenom as operateur,
        z.nom_zone as zone
      FROM reponses r
      INNER JOIN enquetes enq ON r.enquete_id = enq.id
      INNER JOIN producteurs p ON enq.producteur_id = p.id
      INNER JOIN enqueteurs e ON enq.enqueteur_id = e.id
      INNER JOIN zones z ON enq.zone_id = z.id
      INNER JOIN questions q ON r.question_id = q.id
      ORDER BY p.code_phi, r.date_reponse
    ''');
  }

  // ===============================
  // DIAGNOSTIC
  // ===============================

  static Future<void> debugDates() async {
    final db = await database;

    print("\n📅=== DIAGNOSTIC DES DATES ===\n");

    final total = await db.rawQuery('SELECT COUNT(*) as count FROM reponses');
    print("📊 TOTAL réponses: ${total.first['count']}");

    print("\n📅 DERNIÈRES 10 DATES:");
    final dernieres = await db.rawQuery('''
      SELECT id, enquete_id, question_id, date_reponse 
      FROM reponses 
      ORDER BY date_reponse DESC 
      LIMIT 10
    ''');

    for (var r in dernieres) {
      print(
        "   ID:${r['id']} | Enq:${r['enquete_id']} | Q:${r['question_id']} | ${r['date_reponse']}",
      );
    }

    print("\n📊 RÉPARTITION PAR JOUR:");
    final parJour = await db.rawQuery('''
      SELECT 
        date(date_reponse) as jour,
        COUNT(*) as nombre
      FROM reponses
      GROUP BY date(date_reponse)
      ORDER BY jour DESC
      LIMIT 10
    ''');

    for (var j in parJour) {
      print("   ${j['jour']}: ${j['nombre']} réponses");
    }
  }

  // ===============================
  // RAPPORT MENSUEL (Version avec constantes)
  // ===============================

  /// Récupère les statistiques mensuelles pour le rapport RDUE
  static Future<Map<String, dynamic>> getRapportMensuel({
    required int annee,
    required int mois,
  }) async {
    final db = await database;
    final prefs = await SharedPreferences.getInstance();
    final moisStr = '$annee-${mois.toString().padLeft(2, '0')}';

    final rapport = <String, dynamic>{};

    try {
      // =======================
      // INFORMATIONS AGENT ET VALIDATEUR
      // =======================

      // Zone de l'agent (pour l'en-tête)
      rapport['zone_agent'] = prefs.getString("agent_zone") ?? 'Non définie';

      // Informations enquêteur
      final enqueteurNom = prefs.getString("agent_nom") ?? '—';
      final enqueteurContact = prefs.getString("agent_contact") ?? '—';
      final enqueteurZone = prefs.getString("agent_zone") ?? '—';
      rapport['enqueteur_nom'] = enqueteurNom;
      rapport['enqueteur_contact'] = enqueteurContact;
      rapport['enqueteur_zone'] = enqueteurZone;

      // Informations validateur
      final validateurNom = prefs.getString("VALIDATEUR_NOM") ?? '—';
      final validateurPrenoms = prefs.getString("VALIDATEUR_PRENOMS") ?? '';
      final validateurContact = prefs.getString("VALIDATEUR_CONTACT") ?? '—';
      rapport['validateur_nom'] = '$validateurPrenoms $validateurNom'.trim();
      rapport['validateur_contact'] = validateurContact;

      // =======================
      // ACTIVITÉ GÉNÉRALE
      // =======================

      // 1. Total enquêtes terminées
      final totalEnquetes = await db.rawQuery(
        '''
        SELECT COUNT(*) as count 
        FROM enquetes 
        WHERE statut = 'termine' AND pdf_path IS NOT NULL 
        AND strftime('%Y-%m', date_fin) = ?
      ''',
        [moisStr],
      );

      final total = (totalEnquetes.first['count'] as num?)?.toInt() ?? 0;
      rapport['total_enquetes'] = total;

      // 2. Enquêtes non conformes (avec constantes)
      final nonConformes = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE e.statut = 'termine' AND e.pdf_path IS NOT NULL
        AND strftime('%Y-%m', e.date_fin) = ?
        AND (
          (r.question_id = '1' AND r.code_reponse = ?) OR
          (r.question_id = ? AND r.code_reponse IN (?,?,?)) OR
          (r.question_id = ? AND r.code_reponse = ?) OR
          (r.question_id = ? AND r.code_reponse = ?) OR
          (r.question_id = ? AND r.code_reponse = ?) OR
          (r.question_id = ? AND r.code_reponse = ?) OR
          (r.question_id = ? AND r.code_reponse = ?) OR
          (r.question_id = ? AND r.code_reponse IS NOT NULL AND r.code_reponse != '') OR
          (r.question_id = ? AND r.code_reponse = ?) OR
          (r.question_id = ? AND r.code_reponse IN (?,?,?))
        )
      ''',
        [
          moisStr,
          CODE_NON_CONFORME, // pour Q1
          Q_PRODUITS_CHIMIQUES, CODE_OUI, 'B', 'C', // pour Q9
          Q_LITIGE, CODE_OUI, // pour Q11
          Q_PRESENCE_16_17, CODE_OUI_16_17, // pour Q16
          Q_PRESENCE_13_15, CODE_OUI_13_15, // pour Q20
          Q_PRESENCE_MOINS_13, CODE_OUI_MOINS_13, // pour Q25
          Q_CONSENTEMENT, 'C', // pour Q29
          Q_TRAVAILLEURS_MINEURS, // pour Q37
          Q_DOCUMENTS_ETRANGERS, CODE_OUI, // pour Q40
          Q_FRAIS_ETRANGERS, CODE_OUI, 'B', 'C', // pour Q41
        ],
      );

      final nonConformesCount =
          (nonConformes.first['count'] as num?)?.toInt() ?? 0;
      rapport['enquetes_non_conformes'] = nonConformesCount;
      rapport['enquetes_conformes'] = total - nonConformesCount;

      // =======================
      // RÉPARTITION PAR VILLAGE
      // =======================

      final villages = await db.rawQuery(
        '''
        SELECT p.village, COUNT(DISTINCT p.id) as total
        FROM enquetes e
        JOIN producteurs p ON e.producteur_id = p.id
        WHERE e.statut = 'termine' AND e.pdf_path IS NOT NULL
        AND strftime('%Y-%m', e.date_fin) = ?
        AND p.village IS NOT NULL AND p.village != ''
        GROUP BY p.village
        ORDER BY total DESC
      ''',
        [moisStr],
      );

      final List<Map<String, dynamic>> villagesList = [];
      for (var v in villages) {
        villagesList.add({
          'nom': v['village'],
          'total': (v['total'] as num?)?.toInt() ?? 0,
        });
      }
      rapport['villages_list'] = villagesList;

      // =======================
      // TRAVAIL DES ENFANTS (avec constantes)
      // =======================

      // Q16 - Présence 16-17 ans
      final presence16_17 = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE r.question_id = ? AND r.code_reponse = ?
        AND strftime('%Y-%m', e.date_fin) = ?
      ''',
        [Q_PRESENCE_16_17, CODE_OUI_16_17, moisStr],
      );
      rapport['presence_16_17'] =
          (presence16_17.first['count'] as num?)?.toInt() ?? 0;

      // Q20 - Présence 13-15 ans
      final presence13_15 = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE r.question_id = ? AND r.code_reponse = ?
        AND strftime('%Y-%m', e.date_fin) = ?
      ''',
        [Q_PRESENCE_13_15, CODE_OUI_13_15, moisStr],
      );
      rapport['presence_13_15'] =
          (presence13_15.first['count'] as num?)?.toInt() ?? 0;

      // Q25 - Présence moins de 13 ans
      final presenceMoins13 = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE r.question_id = ? AND r.code_reponse = ?
        AND strftime('%Y-%m', e.date_fin) = ?
      ''',
        [Q_PRESENCE_MOINS_13, CODE_OUI_MOINS_13, moisStr],
      );
      rapport['presence_moins_13'] =
          (presenceMoins13.first['count'] as num?)?.toInt() ?? 0;

      // =======================
      // LITIGES FONCIERS
      // =======================

      final litiges = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE r.question_id = ? AND r.code_reponse = ?
        AND strftime('%Y-%m', e.date_fin) = ?
      ''',
        [Q_LITIGE, CODE_OUI, moisStr],
      );
      rapport['litiges'] = (litiges.first['count'] as num?)?.toInt() ?? 0;

      // =======================
      // PRODUITS CHIMIQUES
      // =======================

      // Paraquat (A)
      final paraquat = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE r.question_id = ? AND r.code_reponse LIKE ?
        AND strftime('%Y-%m', e.date_fin) = ?
      ''',
        [Q_PRODUITS_CHIMIQUES, '%A%', moisStr],
      );
      rapport['produit_paraquat'] =
          (paraquat.first['count'] as num?)?.toInt() ?? 0;

      // Glyphosate (B)
      final glyphosate = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE r.question_id = ? AND r.code_reponse LIKE ?
        AND strftime('%Y-%m', e.date_fin) = ?
      ''',
        [Q_PRODUITS_CHIMIQUES, '%B%', moisStr],
      );
      rapport['produit_glyphosate'] =
          (glyphosate.first['count'] as num?)?.toInt() ?? 0;

      // 2-4D (C)
      final produit24d = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE r.question_id = ? AND r.code_reponse LIKE ?
        AND strftime('%Y-%m', e.date_fin) = ?
      ''',
        [Q_PRODUITS_CHIMIQUES, '%C%', moisStr],
      );
      rapport['produit_24d'] =
          (produit24d.first['count'] as num?)?.toInt() ?? 0;

      // Autres produits (D)
      final autresProduits = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE r.question_id = ? AND r.code_reponse LIKE ?
        AND strftime('%Y-%m', e.date_fin) = ?
      ''',
        [Q_PRODUITS_CHIMIQUES, '%D%', moisStr],
      );
      rapport['produit_autres'] =
          (autresProduits.first['count'] as num?)?.toInt() ?? 0;

      // =======================
      // EXPLOITATION HUMAINE
      // =======================

      // Q37 - Travailleurs mineurs
      final travailleursMineurs = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE r.question_id = ? AND r.code_reponse IS NOT NULL AND r.code_reponse != ''
        AND strftime('%Y-%m', e.date_fin) = ?
      ''',
        [Q_TRAVAILLEURS_MINEURS, moisStr],
      );
      rapport['travailleurs_mineurs'] =
          (travailleursMineurs.first['count'] as num?)?.toInt() ?? 0;

      // Q29 - Absence de consentement
      final absenceConsentement = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE r.question_id = ? AND r.code_reponse = ?
        AND strftime('%Y-%m', e.date_fin) = ?
      ''',
        [Q_CONSENTEMENT, 'C', moisStr],
      );
      rapport['absence_consentement'] =
          (absenceConsentement.first['count'] as num?)?.toInt() ?? 0;

      // Q40 - Documents conservés
      final documentsConserves = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE r.question_id = ? AND r.code_reponse = ?
        AND strftime('%Y-%m', e.date_fin) = ?
      ''',
        [Q_DOCUMENTS_ETRANGERS, CODE_OUI, moisStr],
      );
      rapport['documents_conserves'] =
          (documentsConserves.first['count'] as num?)?.toInt() ?? 0;

      // Q41 - Frais exigés
      final fraisExiges = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT r.enquete_id) as count
        FROM reponses r
        JOIN enquetes e ON r.enquete_id = e.id
        WHERE r.question_id = ? AND r.code_reponse IN (?, ?, ?)
        AND strftime('%Y-%m', e.date_fin) = ?
      ''',
        [Q_FRAIS_ETRANGERS, CODE_OUI, 'B', 'C', moisStr],
      );
      rapport['frais_exiges'] =
          (fraisExiges.first['count'] as num?)?.toInt() ?? 0;

      // =======================
      // REFUS D'ENQUÊTE
      // =======================

      final refusEnquetes = await db.rawQuery(
        '''
        SELECT COUNT(*) as count
        FROM enquetes
        WHERE statut = 'refuse'
        AND strftime('%Y-%m', date_fin) = ?
      ''',
        [moisStr],
      );

      rapport['refus_enquetes'] =
          (refusEnquetes.first['count'] as num?)?.toInt() ?? 0;

      return rapport;
    } catch (e) {
      debugPrint('❌ Erreur getRapportMensuel: $e');
      rethrow;
    }
  }

  // ===============================
  // RÉCUPÉRATION DES ZONES
  // ===============================
  static Future<List<Map<String, dynamic>>> getZones() async {
    final db = await database;

    return await db.query('zones', orderBy: 'nom_zone ASC');
  }

  // ===============================
  // RAPPORT MENSUEL PAR ZONE
  // ===============================
  static Future<Map<String, dynamic>> getRapportMensuelParZone({
    required int annee,
    required int mois,
    required int zoneId,
  }) async {
    final db = await database;
    final prefs = await SharedPreferences.getInstance();
    final moisStr = '$annee-${mois.toString().padLeft(2, '0')}';

    final rapport = <String, dynamic>{};

    try {
      // =======================
      // INFORMATIONS ZONE
      // =======================

      // Informations de la zone
      final zone = await db.query(
        'zones',
        where: 'id = ?',
        whereArgs: [zoneId],
        limit: 1,
      );
      rapport['zone_agent'] = zone.isNotEmpty
          ? (zone.first['nom_zone'] as String)
          : 'Zone inconnue';

      // Informations enquêteur
      final enqueteurNom = prefs.getString("agent_nom") ?? '—';
      final enqueteurContact = prefs.getString("agent_contact") ?? '—';
      final enqueteurZone = prefs.getString("agent_zone") ?? '—';
      rapport['enqueteur_nom'] = enqueteurNom;
      rapport['enqueteur_contact'] = enqueteurContact;
      rapport['enqueteur_zone'] = enqueteurZone;

      // Informations validateur
      final validateurNom = prefs.getString("VALIDATEUR_NOM") ?? '—';
      final validateurPrenoms = prefs.getString("VALIDATEUR_PRENOMS") ?? '';
      final validateurContact = prefs.getString("VALIDATEUR_CONTACT") ?? '—';
      rapport['validateur_nom'] = '$validateurPrenoms $validateurNom'.trim();
      rapport['validateur_contact'] = validateurContact;

      // =======================
      // ACTIVITÉ GÉNÉRALE (filtrée par zone)
      // =======================

      // Total enquêtes terminées dans la zone
      final totalEnquetes = await db.rawQuery(
        '''
      SELECT COUNT(*) as count 
      FROM enquetes 
      WHERE statut = 'termine' AND pdf_path IS NOT NULL 
      AND zone_id = ?
      AND strftime('%Y-%m', date_fin) = ?
    ''',
        [zoneId, moisStr],
      );

      final total = (totalEnquetes.first['count'] as num?)?.toInt() ?? 0;
      rapport['total_enquetes'] = total;

      // Enquêtes non conformes dans la zone
      final nonConformes = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE e.statut = 'termine' AND e.pdf_path IS NOT NULL
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
      AND (
        (r.question_id = '1' AND r.code_reponse = ?) OR
        (r.question_id = ? AND r.code_reponse IN (?,?,?)) OR
        (r.question_id = ? AND r.code_reponse = ?) OR
        (r.question_id = ? AND r.code_reponse = ?) OR
        (r.question_id = ? AND r.code_reponse = ?) OR
        (r.question_id = ? AND r.code_reponse = ?) OR
        (r.question_id = ? AND r.code_reponse = ?) OR
        (r.question_id = ? AND r.code_reponse IS NOT NULL AND r.code_reponse != '') OR
        (r.question_id = ? AND r.code_reponse = ?) OR
        (r.question_id = ? AND r.code_reponse IN (?,?,?))
      )
    ''',
        [
          zoneId,
          moisStr,
          CODE_NON_CONFORME,
          Q_PRODUITS_CHIMIQUES,
          CODE_OUI,
          'B',
          'C',
          Q_LITIGE,
          CODE_OUI,
          Q_PRESENCE_16_17,
          CODE_OUI_16_17,
          Q_PRESENCE_13_15,
          CODE_OUI_13_15,
          Q_PRESENCE_MOINS_13,
          CODE_OUI_MOINS_13,
          Q_CONSENTEMENT,
          'C',
          Q_TRAVAILLEURS_MINEURS,
          Q_DOCUMENTS_ETRANGERS,
          CODE_OUI,
          Q_FRAIS_ETRANGERS,
          CODE_OUI,
          'B',
          'C',
        ],
      );

      final nonConformesCount =
          (nonConformes.first['count'] as num?)?.toInt() ?? 0;
      rapport['enquetes_non_conformes'] = nonConformesCount;
      rapport['enquetes_conformes'] = total - nonConformesCount;

      // =======================
      // RÉPARTITION PAR VILLAGE (filtrée par zone)
      // =======================

      final villages = await db.rawQuery(
        '''
      SELECT p.village, COUNT(DISTINCT p.id) as total
      FROM enquetes e
      JOIN producteurs p ON e.producteur_id = p.id
      WHERE e.statut = 'termine' AND e.pdf_path IS NOT NULL
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
      AND p.village IS NOT NULL AND p.village != ''
      GROUP BY p.village
      ORDER BY total DESC
    ''',
        [zoneId, moisStr],
      );

      final List<Map<String, dynamic>> villagesList = [];
      for (var v in villages) {
        villagesList.add({
          'nom': v['village'],
          'total': (v['total'] as num?)?.toInt() ?? 0,
        });
      }
      rapport['villages_list'] = villagesList;

      // =======================
      // TRAVAIL DES ENFANTS (filtré par zone)
      // =======================

      // Q16 - Présence 16-17 ans
      final presence16_17 = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE r.question_id = ? AND r.code_reponse = ?
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
    ''',
        [Q_PRESENCE_16_17, CODE_OUI_16_17, zoneId, moisStr],
      );
      rapport['presence_16_17'] =
          (presence16_17.first['count'] as num?)?.toInt() ?? 0;

      // Q20 - Présence 13-15 ans
      final presence13_15 = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE r.question_id = ? AND r.code_reponse = ?
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
    ''',
        [Q_PRESENCE_13_15, CODE_OUI_13_15, zoneId, moisStr],
      );
      rapport['presence_13_15'] =
          (presence13_15.first['count'] as num?)?.toInt() ?? 0;

      // Q25 - Présence moins de 13 ans
      final presenceMoins13 = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE r.question_id = ? AND r.code_reponse = ?
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
    ''',
        [Q_PRESENCE_MOINS_13, CODE_OUI_MOINS_13, zoneId, moisStr],
      );
      rapport['presence_moins_13'] =
          (presenceMoins13.first['count'] as num?)?.toInt() ?? 0;

      // =======================
      // LITIGES FONCIERS (filtré par zone)
      // =======================

      final litiges = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE r.question_id = ? AND r.code_reponse = ?
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
    ''',
        [Q_LITIGE, CODE_OUI, zoneId, moisStr],
      );
      rapport['litiges'] = (litiges.first['count'] as num?)?.toInt() ?? 0;

      // =======================
      // PRODUITS CHIMIQUES (filtré par zone)
      // =======================

      // Paraquat (A)
      final paraquat = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE r.question_id = ? AND r.code_reponse LIKE ?
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
    ''',
        [Q_PRODUITS_CHIMIQUES, '%A%', zoneId, moisStr],
      );
      rapport['produit_paraquat'] =
          (paraquat.first['count'] as num?)?.toInt() ?? 0;

      // Glyphosate (B)
      final glyphosate = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE r.question_id = ? AND r.code_reponse LIKE ?
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
    ''',
        [Q_PRODUITS_CHIMIQUES, '%B%', zoneId, moisStr],
      );
      rapport['produit_glyphosate'] =
          (glyphosate.first['count'] as num?)?.toInt() ?? 0;

      // 2-4D (C)
      final produit24d = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE r.question_id = ? AND r.code_reponse LIKE ?
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
    ''',
        [Q_PRODUITS_CHIMIQUES, '%C%', zoneId, moisStr],
      );
      rapport['produit_24d'] =
          (produit24d.first['count'] as num?)?.toInt() ?? 0;

      // Autres produits (D)
      final autresProduits = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE r.question_id = ? AND r.code_reponse LIKE ?
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
    ''',
        [Q_PRODUITS_CHIMIQUES, '%D%', zoneId, moisStr],
      );
      rapport['produit_autres'] =
          (autresProduits.first['count'] as num?)?.toInt() ?? 0;

      // =======================
      // EXPLOITATION HUMAINE (filtré par zone)
      // =======================

      // Q37 - Travailleurs mineurs
      final travailleursMineurs = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE r.question_id = ? AND r.code_reponse IS NOT NULL AND r.code_reponse != ''
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
    ''',
        [Q_TRAVAILLEURS_MINEURS, zoneId, moisStr],
      );
      rapport['travailleurs_mineurs'] =
          (travailleursMineurs.first['count'] as num?)?.toInt() ?? 0;

      // Q29 - Absence de consentement
      final absenceConsentement = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE r.question_id = ? AND r.code_reponse = ?
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
    ''',
        [Q_CONSENTEMENT, 'C', zoneId, moisStr],
      );
      rapport['absence_consentement'] =
          (absenceConsentement.first['count'] as num?)?.toInt() ?? 0;

      // Q40 - Documents conservés
      final documentsConserves = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE r.question_id = ? AND r.code_reponse = ?
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
    ''',
        [Q_DOCUMENTS_ETRANGERS, CODE_OUI, zoneId, moisStr],
      );
      rapport['documents_conserves'] =
          (documentsConserves.first['count'] as num?)?.toInt() ?? 0;

      // Q41 - Frais exigés
      final fraisExiges = await db.rawQuery(
        '''
      SELECT COUNT(DISTINCT r.enquete_id) as count
      FROM reponses r
      JOIN enquetes e ON r.enquete_id = e.id
      WHERE r.question_id = ? AND r.code_reponse IN (?, ?, ?)
      AND e.zone_id = ?
      AND strftime('%Y-%m', e.date_fin) = ?
    ''',
        [Q_FRAIS_ETRANGERS, CODE_OUI, 'B', 'C', zoneId, moisStr],
      );
      rapport['frais_exiges'] =
          (fraisExiges.first['count'] as num?)?.toInt() ?? 0;

      // =======================
      // REFUS D'ENQUÊTE (filtré par zone)
      // =======================

      final refusEnquetes = await db.rawQuery(
        '''
      SELECT COUNT(*) as count
      FROM enquetes
      WHERE statut = 'refuse'
      AND zone_id = ?
      AND strftime('%Y-%m', date_fin) = ?
    ''',
        [zoneId, moisStr],
      );
      rapport['refus_enquetes'] =
          (refusEnquetes.first['count'] as num?)?.toInt() ?? 0;

      return rapport;
    } catch (e) {
      debugPrint('❌ Erreur getRapportMensuelParZone: $e');
      rethrow;
    }
  }
}
