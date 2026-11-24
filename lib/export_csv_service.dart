// lib/export_csv_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/database_helper.dart';

class ExportCsvService {

  // Liste des questions multi à forcer
  static const List<String> multiQuestions = ['9', '19', '23', '37'];

  // =======================
  // RÉCUPÉRER LE NOM DE L'AGENT CONNECTÉ
  // =======================
  static Future<String> _getNomAgent() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ Utiliser la clé 'agent_nom' qui est effectivement utilisée
      final String agentNomComplet = prefs.getString('agent_nom') ?? '';

      print("👤 Nom agent récupéré: '$agentNomComplet'");

      if (agentNomComplet.isNotEmpty) {
        // Nettoyer le nom pour le fichier
        return agentNomComplet.toLowerCase().replaceAll(' ', '_');
      }
    } catch (e) {
      print("⚠️ Erreur lors de la récupération du nom de l'agent: $e");
    }
    return '';
  }

  // =======================
  // NETTOYER LE NOM DE FICHIER
  // =======================
  static String _cleanFileName(String text) {
    return text.replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .trim()
        .toLowerCase();
  }

  // =======================
  // EXPORTER LES DONNÉES SUR UNE PÉRIODE
  // =======================
  static Future<File> exportToCsv({
    required DateTime dateDebut,
    required DateTime dateFin,
  }) async {
    // 1. Récupérer les données de la période
    final reponses = await DatabaseHelper.getReponsesForExport(
      dateDebut: dateDebut,
      dateFin: dateFin,
    );

    print("📊 Export de ${reponses.length} réponses");

    // 2. Trier les réponses dans l'ordre de saisie (ASC)
    final reponsesTriees = List<Map<String, dynamic>>.from(reponses);
    reponsesTriees.sort((a, b) {
      final dateA = a['date_reponse']?.toString() ?? '';
      final dateB = b['date_reponse']?.toString() ?? '';
      return dateA.compareTo(dateB); // ASC = ordre réel de saisie
    });

    // 3. Créer le contenu CSV
    final List<List<String>> rows = [];

    // En-tête avec "Question ID"
    rows.add([
      'code_phi',
      'Question ID',
      'code_reponse',
      'remarque',
      'date',
      'agent_enqueteur',
      'zone',
    ]);

    // ✅ VERSION CORRIGÉE AVEC LA LOGIQUE MÉTIER
    for (var reponse in reponsesTriees) {
      // ✅ Utiliser reference pour le code question
      final questionCode =
          reponse['reference']?.toString() ??
              reponse['question_id']?.toString() ??
              '';

      // ✅ Détection correcte du code réponse
      final rawCode = reponse['code_reponse'];
      final codeReponse = (rawCode == null || rawCode.toString().trim().isEmpty)
          ? '0'
          : rawCode.toString();

      // ✅ Récupérer les données nécessaires
      final precision = reponse['remarque']?.toString(); // La requête retourne 'remarque' (alias de precision_text)
      final valeur = reponse['valeur']?.toString();

      // ✅ LOGIQUE MÉTIER POUR LA COLONNE REMARQUE
      String remarque = '';

      // 🔹 PRIORITÉ ABSOLUE : la précision saisie
      if (precision != null && precision.trim().isNotEmpty) {
        remarque = precision.trim();
      }
      // 🔹 QUESTIONS SANS CODE : la valeur saisie (texte, nombre, année, pourcentage)
      else if (codeReponse == '0' && valeur != null && valeur.trim().isNotEmpty) {
        remarque = valeur.trim();
      }

      // Nettoyage CSV
      remarque = remarque.replaceAll(',', ';');

      rows.add([
        reponse['code_phi']?.toString() ?? 'INCONNU',
        questionCode,
        codeReponse,
        remarque,
        _formatDate(reponse['date_reponse']?.toString() ?? ''),
        reponse['operateur']?.toString() ?? 'INCONNU',
        reponse['zone']?.toString() ?? 'INCONNU',
      ]);
    }

    // 4. Sauvegarder le fichier
    return await _saveCsvFile(rows, dateDebut, dateFin);
  }

  // =======================
  // EXPORTER UNE ENQUÊTE SPÉCIFIQUE
  // =======================
  static Future<File> exportEnquete(int enqueteId) async {
    // Récupérer les infos de l'enquête
    final infosEnquete = await DatabaseHelper.getInfosEnquete(enqueteId);

    // Récupérer les réponses
    final reponses = await DatabaseHelper.getReponsesByEnquete(enqueteId);

    print("📊 Export de l'enquête $enqueteId: ${reponses.length} réponses");

    // Trier les réponses dans l'ordre de saisie (ASC)
    final reponsesTriees = List<Map<String, dynamic>>.from(reponses);
    reponsesTriees.sort((a, b) {
      final dateA = a['date_reponse']?.toString() ?? '';
      final dateB = b['date_reponse']?.toString() ?? '';
      return dateA.compareTo(dateB); // ASC = ordre réel de saisie
    });

    final List<List<String>> rows = [];

    // En-tête avec "Question ID"
    rows.add([
      'code_phi',
      'Question ID',
      'code_reponse',
      'remarque',
      'date',
      'agent_enqueteur',
      'zone',
    ]);

    // ✅ VERSION CORRIGÉE AVEC LA LOGIQUE MÉTIER
    for (var reponse in reponsesTriees) {
      // ✅ Utiliser reference pour le code question
      final questionCode =
          reponse['reference']?.toString() ??
              reponse['question_id']?.toString() ??
              '';

      // ✅ Détection correcte du code réponse
      final rawCode = reponse['code_reponse'];
      final codeReponse = (rawCode == null || rawCode.toString().trim().isEmpty)
          ? '0'
          : rawCode.toString();

      // ✅ Récupérer les données nécessaires
      final precision = reponse['precision_text']?.toString(); // La requête retourne 'precision_text'
      final valeur = reponse['valeur']?.toString();

      // ✅ LOGIQUE MÉTIER POUR LA COLONNE REMARQUE
      String remarque = '';

      // 🔹 PRIORITÉ ABSOLUE : la précision saisie
      if (precision != null && precision.trim().isNotEmpty) {
        remarque = precision.trim();
      }
      // 🔹 QUESTIONS SANS CODE : la valeur saisie (texte, nombre, année, pourcentage)
      else if (codeReponse == '0' && valeur != null && valeur.trim().isNotEmpty) {
        remarque = valeur.trim();
      }

      // Nettoyage CSV
      remarque = remarque.replaceAll(',', ';');

      rows.add([
        infosEnquete?['code_producteur']?.toString() ?? 'INCONNU',
        questionCode,
        codeReponse,
        remarque,
        _formatDate(reponse['date_reponse']?.toString() ?? ''),
        // Agent complet (prénom + nom)
        '${infosEnquete?['prenom_enqueteur'] ?? ''} ${infosEnquete?['nom_enqueteur'] ?? ''}'.trim(),
        infosEnquete?['nom_zone']?.toString() ?? 'INCONNU',
      ]);
    }

    return await _saveCsvFile(rows, null, null, prefix: 'enquete_$enqueteId');
  }

  // =======================
  // EXPORTER TOUTES LES DONNÉES (sans filtre de date)
  // =======================
  static Future<File> exportAllData() async {
    final db = await DatabaseHelper.database;

    // Récupérer TOUTES les réponses
    final reponses = await db.rawQuery('''
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
      ORDER BY r.date_reponse ASC
    ''');

    print("📊 Export de ${reponses.length} réponses (toutes)");

    final List<List<String>> rows = [];

    // En-tête avec "Question ID"
    rows.add([
      'code_phi',
      'Question ID',
      'code_reponse',
      'remarque',
      'date',
      'agent_enqueteur',
      'zone',
    ]);

    // ✅ VERSION CORRIGÉE AVEC LA LOGIQUE MÉTIER
    for (var reponse in reponses) {
      // ✅ Utiliser reference pour le code question
      final questionCode =
          reponse['reference']?.toString() ??
              reponse['question_id']?.toString() ??
              '';

      // ✅ Détection correcte du code réponse
      final rawCode = reponse['code_reponse'];
      final codeReponse = (rawCode == null || rawCode.toString().trim().isEmpty)
          ? '0'
          : rawCode.toString();

      // ✅ Récupérer les données nécessaires
      final precision = reponse['remarque']?.toString(); // La requête retourne 'remarque' (alias de precision_text)
      final valeur = reponse['valeur']?.toString();

      // ✅ LOGIQUE MÉTIER POUR LA COLONNE REMARQUE
      String remarque = '';

      // 🔹 PRIORITÉ ABSOLUE : la précision saisie
      if (precision != null && precision.trim().isNotEmpty) {
        remarque = precision.trim();
      }
      // 🔹 QUESTIONS SANS CODE : la valeur saisie (texte, nombre, année, pourcentage)
      else if (codeReponse == '0' && valeur != null && valeur.trim().isNotEmpty) {
        remarque = valeur.trim();
      }

      // Nettoyage CSV
      remarque = remarque.replaceAll(',', ';');

      rows.add([
        reponse['code_phi']?.toString() ?? 'INCONNU',
        questionCode,
        codeReponse,
        remarque,
        _formatDate(reponse['date_reponse']?.toString() ?? ''),
        reponse['operateur']?.toString() ?? 'INCONNU',
        reponse['zone']?.toString() ?? 'INCONNU',
      ]);
    }

    return await _saveCsvFile(rows, null, null, prefix: 'export_all');
  }

  // =======================
  // FORMATER LA DATE
  // =======================
  static String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // =======================
  // SAUVEGARDER LE FICHIER CSV
  // =======================
  static Future<File> _saveCsvFile(
      List<List<String>> rows,
      DateTime? dateDebut,
      DateTime? dateFin, {
        String prefix = 'export',
      }) async {
    // Créer le contenu CSV
    final buffer = StringBuffer();
    for (final row in rows) {
      // Utiliser ';' comme séparateur
      buffer.writeln(row.map(_escapeCsvCell).join(';'));
    }

    // Créer le dossier Rubberway
    final baseDir = await getApplicationDocumentsDirectory();
    final rubberwayDir = Directory('${baseDir.path}/Rubberway');
    if (!await rubberwayDir.exists()) {
      await rubberwayDir.create(recursive: true);
    }

    // Récupérer le nom de l'agent avec la bonne clé 'agent_nom'
    final nomAgent = await _getNomAgent();
    final agentPart = nomAgent.isNotEmpty ? '_${nomAgent}' : '';

    // Générer le nom du fichier (format RDUE) avec le nom de l'agent
    String fileName;
    if (dateDebut != null && dateFin != null) {
      final df = DateFormat('dd-MM-yyyy');
      fileName = 'Enquête RDUE réalisé du ${df.format(dateDebut)} au ${df.format(dateFin)}${agentPart}.csv';
    } else {
      fileName = 'Enquête RDUE réalisé le ${DateFormat('dd-MM-yyyy_HH-mm').format(DateTime.now())}${agentPart}.csv';
    }

    // ✅ MODIFICATION UNIQUE : Ajout du BOM UTF-8 pour Excel
    final file = File('${rubberwayDir.path}/$fileName');
    await file.writeAsBytes(
      utf8.encode('\uFEFF${buffer.toString()}'),
    );

    print("✅ Fichier CSV créé: ${file.path}");
    print("📊 Nombre de lignes: ${rows.length} (en-tête inclus)");
    print("👤 Nom de l'agent dans le fichier: $nomAgent");

    return file;
  }

  // =======================
  // ÉCHAPPEMENT POUR CSV (adapté pour le séparateur ';')
  // =======================
  static String _escapeCsvCell(String cell) {
    if (cell.contains(';') || cell.contains('"') || cell.contains('\n')) {
      return '"${cell.replaceAll('"', '""')}"';
    }
    return cell;
  }
}