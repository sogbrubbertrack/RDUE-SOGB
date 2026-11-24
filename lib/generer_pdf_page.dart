import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'options_envoi_page.dart';
import 'data/database_helper.dart';
import 'pdf_type.dart';

/// =====================================================
/// UTILITAIRES PDF
/// =====================================================

pw.Widget pdfCheck(bool value, {double size = 8}) {
  return pw.Text(
    value ? 'X' : '',
    textAlign: pw.TextAlign.center,
    style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold),
  );
}

pw.Widget infoItem(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 3),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$label : ',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
        pw.Expanded(
          child: pw.Text(
            value.isEmpty ? '—' : value,
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
      ],
    ),
  );
}

pw.Widget infoBox(String title, List<pw.Widget> children) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(width: 0.5),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Divider(thickness: 0.5),
        pw.SizedBox(height: 2),
        ...children,
      ],
    ),
  );
}

String _buildAnswersIndex(List<List<Map<String, dynamic>>> groups) {
  final answers = <Map<String, String>>[];
  for (final group in groups) {
    for (final question in group) {
      final options = question['options'];
      String response;
      String code;
      if (options is List) {
        final selected = options.where((option) => option['selected'] == true).toList();
        response = selected.map((option) => '${option['libelle'] ?? ''}'.trim())
            .where((value) => value.isNotEmpty).join(' ; ');
        code = selected.map((option) => '${option['code'] ?? ''}'.trim())
            .where((value) => value.isNotEmpty).join(' ; ');
      } else {
        response = '${question['remarque'] ?? ''}'.trim();
        code = '${question['code'] ?? ''}'.trim();
      }
      if (response.isEmpty) continue;
      answers.add({
        'ref': '${question['ref'] ?? ''}',
        'theme': '${question['theme'] ?? ''}',
        'question': '${question['question'] ?? ''}',
        'code': code,
        'response': response,
      });
    }
  }
  return 'RWANSWERSv1:${base64.encode(utf8.encode(jsonEncode(answers)))}:ENDRWANSWERS';
}

pw.Widget headerCell(String text, {double fontSize = 7}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(3),
    color: PdfColors.grey300,
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget dataCell(
  String text, {
  double fontSize = 7,
  bool bold = false,
  bool center = false,
  double padding = 2,
  PdfColor? background,
}) {
  return pw.Container(
    padding: pw.EdgeInsets.all(padding),
    alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
    decoration: background != null ? pw.BoxDecoration(color: background) : null,
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

/// Réduit les photos très lourdes avant leur intégration au PDF.
Uint8List _preparePdfImage(Uint8List sourceBytes) {
  try {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) return sourceBytes;

    const maxDimension = 1100;
    final scale = math.min(
      1.0,
      maxDimension / math.max(decoded.width, decoded.height),
    );
    final resized = scale < 1
        ? img.copyResize(
            decoded,
            width: (decoded.width * scale).round(),
            height: (decoded.height * scale).round(),
          )
        : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 68));
  } catch (_) {
    return sourceBytes;
  }
}

/// Prépare les images d'un PDF dans un seul isolate pour éviter de démarrer
/// un nouvel isolate pour chaque photo ou signature.
List<Uint8List?> _preparePdfImages(List<Uint8List?> sourceImages) =>
    sourceImages
        .map((bytes) => bytes == null ? null : _preparePdfImage(bytes))
        .toList(growable: false);

/// =====================================================
/// PAGE PRINCIPALE
/// =====================================================

class GenererPdfPage extends StatefulWidget {
  final int enqueteId;
  final int producteurId;
  final PdfType pdfType;
  final Map<String, dynamic>? reportData;
  final DateTime? mois;
  final String? zone;

  const GenererPdfPage({
    super.key,
    required this.enqueteId,
    required this.producteurId,
    required this.pdfType,
    this.reportData,
    this.mois,
    this.zone,
  });

  @override
  State<GenererPdfPage> createState() => _GenererPdfPageState();
}

class _GenererPdfPageState extends State<GenererPdfPage> {
  bool _loading = false;
  String? _error;
  String _progressMessage = "Préparation...";

  Map<String, dynamic>? infos;
  Map<String, List<Map<String, dynamic>>> reponses = {};

  // Données supplémentaires
  bool _estProducteurQuiRepond = true;
  String _interlocuteurNom = "";
  String _interlocuteurContact = "";
  String _interlocuteurLien = "";
  String _validateurNom = "";
  String _validateurPrenoms = "";
  String _validateurContact = "";

  // Photos
  String? _photoInterlocuteurPath;
  String? _photoPieceRectoPath;
  String? _photoPieceVersoPath;
  String? _photoDocFoncierPath;
  String? _photoReconnaissancePath;

  // ✅ Signatures - Récupérées depuis la base de données
  String? _signaturePlanteurPath;
  String? _signatureAgentPath;

  // Logo pour le rapport mensuel
  pw.ImageProvider? logo;

  /// =====================================================
  /// CHARGEMENT DONNÉES (pour enquête)
  /// =====================================================

  Future<void> _loadEnqueteData() async {
    setState(
      () => _progressMessage = "Chargement des informations de l'enquête...",
    );

    infos = await DatabaseHelper.getInfosEnquete(widget.enqueteId);

    setState(() => _progressMessage = "Chargement des réponses...");
    final reps = await DatabaseHelper.getReponsesByEnquete(widget.enqueteId);
    reponses.clear();
    for (final r in reps) {
      final q = r['question_id'];
      reponses.putIfAbsent(q, () => []).add(r);
    }

    setState(() => _progressMessage = "Chargement des données utilisateur...");
    final prefs = await SharedPreferences.getInstance();

    // Charger les informations avec l'ID du producteur
    _estProducteurQuiRepond =
        prefs.getBool("INTERLOC_EST_PRODUCTEUR_${widget.producteurId}") ?? true;
    _interlocuteurNom =
        prefs.getString("INTERLOC_NOM_${widget.producteurId}") ?? "";
    _interlocuteurContact =
        prefs.getString("INTERLOC_CONTACT_${widget.producteurId}") ?? "";
    _interlocuteurLien =
        prefs.getString("INTERLOC_LIEN_${widget.producteurId}") ?? "";

    _validateurNom = prefs.getString("VALIDATEUR_NOM") ?? "";
    _validateurPrenoms = prefs.getString("VALIDATEUR_PRENOMS") ?? "";
    _validateurContact = prefs.getString("VALIDATEUR_CONTACT") ?? "";

    // ✅ Récupérer les signatures depuis la base de données
    setState(() => _progressMessage = "Chargement des signatures...");
    final signatures = await DatabaseHelper.getAllSignaturesForEnquete(
      widget.enqueteId,
    );
    _signatureAgentPath =
        signatures[DatabaseHelper.SIGNATURE_AGENT] ??
        prefs.getString('agent_signature_path');
    if (_signatureAgentPath != null &&
        !await File(_signatureAgentPath!).exists()) {
      _signatureAgentPath = prefs.getString('agent_signature_path');
    }
    if (_signatureAgentPath != null &&
        !await File(_signatureAgentPath!).exists()) {
      _signatureAgentPath = null;
    }
    _signaturePlanteurPath = signatures[DatabaseHelper.SIGNATURE_PLANTEUR];

    // Photos
    _photoInterlocuteurPath = prefs.getString("PHOTO_INTERLOCUTEUR");
    _photoPieceRectoPath = prefs.getString("PHOTO_PIECE_RECTO");
    _photoPieceVersoPath = prefs.getString("PHOTO_PIECE_VERSO");

    setState(() => _progressMessage = "Chargement des photos...");
    final photos = await DatabaseHelper.getAllPhotosForEnquete(
      widget.enqueteId,
    );
    _photoDocFoncierPath = photos['4'] ?? prefs.getString("PHOTO_DOC_FONCIER");
    _photoReconnaissancePath =
        photos['6'] ?? prefs.getString("PHOTO_RECONNAISSANCE");
  }

  /// =====================================================
  /// ACCÈS AUX RÉPONSES
  /// =====================================================

  String val(String q) => reponses[q]?.first['valeur']?.toString() ?? '';
  String code(String q) => reponses[q]?.first['code_reponse']?.toString() ?? '';

  bool isChecked(String q, String code) {
    final list = reponses[q];
    if (list == null || list.isEmpty) return false;

    final raw = list.first['code_reponse']?.toString() ?? '';
    if (raw.isEmpty) return false;

    return raw.split(',').map((e) => e.trim()).contains(code);
  }

  String precision(String q, String code) {
    final list = reponses[q];
    if (list == null) return '';

    for (final r in list) {
      final raw = r['code_reponse']?.toString() ?? '';
      final codes = raw.split(',').map((e) => e.trim());

      if (codes.contains(code)) {
        return r['precision_text']?.toString() ?? '';
      }
    }
    return '';
  }

  /// =====================================================
  /// CONSTRUCTION DES QUESTIONS POUR ENQUÊTE
  /// =====================================================

  List<Map<String, dynamic>> _buildQuestionsDroitsFonciers() {
    return [
      {
        'theme': 'DROITS FONCIERS',
        'ref': '1',
        'question': "Type d'autorisation pour utiliser le terrain :",
        'options': [
          {
            'code': 'A',
            'selected': code('1') == 'A',
            'libelle': 'Documentation foncière',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('1') == 'B',
            'libelle': "L'Utilisation est reconnue sans document",
            'remarque': '',
          },
          {
            'code': 'C',
            'selected': code('1') == 'C',
            'libelle': 'Utilisation non autorisée du terrain',
            'remarque': '',
          },
        ],
        'branchement': '2/5/8',
      },
      {
        'theme': 'DROITS FONCIERS',
        'ref': '2',
        'question': 'Type de documentation :',
        'options': [
          {
            'code': 'A',
            'selected': code('2') == 'A',
            'libelle': 'Certificat foncier',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('2') == 'B',
            'libelle': 'Attestation coutumière',
            'remarque': '',
          },
          {
            'code': 'C',
            'selected': code('2') == 'C',
            'libelle': 'Contrat de location ou de métayage',
            'remarque': '',
          },
          {
            'code': 'D',
            'selected': code('2') == 'D',
            'libelle': 'Autres (veuillez préciser dans les remarques)',
            'remarque': precision('2', 'D'),
          },
        ],
        'branchement': '3',
      },
      {
        'theme': 'DROITS FONCIERS',
        'ref': '3',
        'question': 'Numéro de référence de la documentation ?',
        'type': 'text',
        'code': '0',
        'reponse': '(saisir le numéro de référence)',
        'remarque': val('3'),
        'branchement': '4',
      },
      {
        'theme': 'DROITS FONCIERS',
        'ref': '4',
        'question': 'Image de la documentation',
        'type': 'image',
        'code': '0',
        'reponse': '(prise de photos/téléchargement de fichiers)',
        'remarque': _photoDocFoncierPath != null
            ? 'Voir documentation photo'
            : '',
        'branchement': '9',
      },
      {
        'theme': 'DROITS FONCIERS',
        'ref': '5',
        'question': "Comment l'utilisation du terrain est-elle reconnue ?",
        'options': [
          {
            'code': 'A',
            'selected': code('5') == 'A',
            'libelle': 'Démarcation physique coutumière',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('5') == 'B',
            'libelle': 'Occupation de longue durée',
            'remarque': '',
          },
          {
            'code': 'C',
            'selected': code('5') == 'C',
            'libelle': 'Autres (veuillez préciser)',
            'remarque': precision('5', 'C'),
          },
        ],
        'branchement': '6/7/8',
      },
      {
        'theme': 'DROITS FONCIERS',
        'ref': '6',
        'question':
            "Téléchargez une image pour montrer comment l'utilisation des terres est reconnue ?",
        'type': 'image',
        'code': '0',
        'reponse': '(prise de photos/téléchargement de fichiers)',
        'remarque': _photoReconnaissancePath != null
            ? 'Photo reconnaissance'
            : '',
        'branchement': '9',
      },
      {
        'theme': 'DROITS FONCIERS',
        'ref': '7',
        'question':
            "Pour une occupation de longue durée, en quelle année la plantation a-t-elle été établie ?",
        'type': 'year',
        'code': '0',
        'reponse': '(indiquer l\'année)',
        'remarque': val('7'),
        'branchement': '9',
      },
      {
        'theme': 'DROITS FONCIERS',
        'ref': '8',
        'question':
            "Veuillez préciser comment l'utilisation des terres est reconnue :",
        'type': 'text',
        'code': '0',
        'reponse': '(saisir le texte)',
        'remarque': val('8'),
        'branchement': '9',
      },
    ];
  }

  List<Map<String, dynamic>> _buildQuestionsEnvironnement() {
    return [
      {
        'theme': 'ENVIRONNEMENT',
        'ref': '9',
        'question':
            "Parmi les Produits chimiques suivants, lesquels sont utilisés sur le terrain (plusieurs options possibles) ?",
        'options': [
          {
            'code': 'A',
            'selected': isChecked('9', 'A'),
            'libelle': 'Paraquat',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': isChecked('9', 'B'),
            'libelle': 'Glyphosate (Roundup)',
            'remarque': '',
          },
          {
            'code': 'C',
            'selected': isChecked('9', 'C'),
            'libelle': '2-4D',
            'remarque': '',
          },
          {
            'code': 'D',
            'selected': isChecked('9', 'D'),
            'libelle': 'Autres (veuillez préciser)',
            'remarque': precision('9', 'D'),
          },
        ],
        'branchement': '10',
      },
      {
        'theme': 'ENVIRONNEMENT',
        'ref': '10',
        'question':
            "J'ai pris Connaissance de la liste des engrais et pesticides autorisés en Côte d'Ivoire ?",
        'options': [
          {
            'code': 'A',
            'selected': code('10') == 'A',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('10') == 'B',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '11',
      },
    ];
  }

  List<Map<String, dynamic>> _buildQuestionsDroitsTiers() {
    return [
      {
        'theme': 'DROITS DES TIERS',
        'ref': '11',
        'question':
            "Existe-t-il actuellement des litiges fonciers non résolus avec des groupes indigènes ou autochtones ?",
        'options': [
          {
            'code': 'A',
            'selected': code('11') == 'A',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('11') == 'B',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '12/13',
      },
      {
        'theme': 'DROITS DES TIERS',
        'ref': '12',
        'question': "Veuillez donner des précisions sur le litige foncier :",
        'type': 'text',
        'code': '0',
        'reponse': '(saisir le texte)',
        'remarque': val('12'),
        'branchement': '13',
      },
    ];
  }

  List<Map<String, dynamic>> _buildQuestionsMenages() {
    return [
      {
        'theme': 'MÉNAGES',
        'ref': '13',
        'question':
            "Outre le planteur, y a-t-il d'autres membres du ménage qui séjournent sur la plantation ou dans ses environs ?",
        'options': [
          {
            'code': 'A',
            'selected': code('13') == 'A',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('13') == 'B',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '14/28',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '14',
        'question': "Y a-t-il des membres du ménage âgés de plus de 18 ans ?",
        'options': [
          {
            'code': 'A',
            'selected': code('14') == 'A',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'Z',
            'selected': code('14') == 'Z',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '15/16',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '15',
        'question': "Nombre de membres du ménage âgés de plus de 18 ans",
        'type': 'number',
        'code': '0',
        'reponse': '(saisir nombre)',
        'remarque': val('15'),
        'branchement': '18',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '16',
        'question': "Y a-t-il des membres du ménage âgés de 16 à 17 ans ?",
        'options': [
          {
            'code': 'B',
            'selected': code('16') == 'B',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'Z',
            'selected': code('16') == 'Z',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '17/20',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '17',
        'question': "Nombre de membres du ménage âgés de 16 à 17 ans",
        'type': 'number',
        'code': '0',
        'reponse': '(saisir nombre)',
        'remarque': val('17'),
        'branchement': '18',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '18',
        'question':
            "Parmi les jeunes âgés de 16 à 17 ans, certains travaillent-ils sur la plantation ?",
        'options': [
          {
            'code': 'A',
            'selected': code('18') == 'A',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('18') == 'B',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '19/20',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '19',
        'question':
            "Pour les personnes âgées de 16 à 17 ans, quelles activités leur sont confiées ? (Plusieurs options possibles)",
        'options': [
          {
            'code': 'A',
            'selected': isChecked('19', 'A'),
            'libelle': 'Effectuer la saignée',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': isChecked('19', 'B'),
            'libelle': 'Collecte du latex dans les tasses',
            'remarque': '',
          },
          {
            'code': 'C',
            'selected': isChecked('19', 'C'),
            'libelle': 'Faire le Rabattage',
            'remarque': '',
          },
          {
            'code': 'D',
            'selected': isChecked('19', 'D'),
            'libelle': "Ramasser les graines d'hévéa",
            'remarque': '',
          },
          {
            'code': 'E',
            'selected': isChecked('19', 'E'),
            'libelle': "Semer les graines d'hévéa",
            'remarque': '',
          },
          {
            'code': 'F',
            'selected': isChecked('19', 'F'),
            'libelle': 'Effectuer le trouaison',
            'remarque': '',
          },
          {
            'code': 'G',
            'selected': isChecked('19', 'G'),
            'libelle': 'Pulvérisation de produits chimiques (herbicides, etc)',
            'remarque': '',
          },
          {
            'code': 'H',
            'selected': isChecked('19', 'H'),
            'libelle': 'Aider au piquetage',
            'remarque': '',
          },
          {
            'code': 'I',
            'selected': isChecked('19', 'I'),
            'libelle': 'Couvrir le caoutchouc stocké avec des bâches',
            'remarque': '',
          },
          {
            'code': 'J',
            'selected': isChecked('19', 'J'),
            'libelle': 'Défrichage',
            'remarque': '',
          },
          {
            'code': 'K',
            'selected': isChecked('19', 'K'),
            'libelle': 'Brûlage des parcelles',
            'remarque': '',
          },
          {
            'code': 'L',
            'selected': isChecked('19', 'L'),
            'libelle': 'Autres (à préciser dans les remarques)',
            'remarque': precision('19', 'L'),
          },
        ],
        'branchement': '20',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '20',
        'question': "Y a-t-il des membres du ménage âgés de 13 à 15 ans ?",
        'options': [
          {
            'code': 'C',
            'selected': code('20') == 'C',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'Z',
            'selected': code('20') == 'Z',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '21/25',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '21',
        'question': "Nombre de membres du ménage âgés de 13 à 15 ans :",
        'type': 'number',
        'code': '0',
        'reponse': '(saisir le nombre)',
        'remarque': val('21'),
        'branchement': '22',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '22',
        'question':
            "Parmi les jeunes âgés de 13-15 ans, certains travaillent-ils sur la plantation ?",
        'options': [
          {
            'code': 'A',
            'selected': code('22') == 'A',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('22') == 'B',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '23/25',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '23',
        'question':
            "Pour les personnes âgées de 13 à 15 ans, quelles activités leur sont confiées ? (Plusieurs options possibles)",
        'options': [
          {
            'code': 'A',
            'selected': isChecked('23', 'A'),
            'libelle': 'Effectuer la saignée',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': isChecked('23', 'B'),
            'libelle': 'Collecte du latex dans les tasses',
            'remarque': '',
          },
          {
            'code': 'C',
            'selected': isChecked('23', 'C'),
            'libelle': 'Faire le rabattage',
            'remarque': '',
          },
          {
            'code': 'D',
            'selected': isChecked('23', 'D'),
            'libelle': "Ramasser les graines d'hévéa",
            'remarque': '',
          },
          {
            'code': 'E',
            'selected': isChecked('23', 'E'),
            'libelle': "Semer les graines d'hévéa",
            'remarque': '',
          },
          {
            'code': 'F',
            'selected': isChecked('23', 'F'),
            'libelle': 'Effectuer la trouaison',
            'remarque': '',
          },
          {
            'code': 'G',
            'selected': isChecked('23', 'G'),
            'libelle': 'Pulvérisation de produits chimiques (herbicides, etc.)',
            'remarque': '',
          },
          {
            'code': 'H',
            'selected': isChecked('23', 'H'),
            'libelle': 'Aider au piquetage',
            'remarque': '',
          },
          {
            'code': 'I',
            'selected': isChecked('23', 'I'),
            'libelle': 'Couvrir le caoutchouc stocké avec des bâches',
            'remarque': '',
          },
          {
            'code': 'J',
            'selected': isChecked('23', 'J'),
            'libelle': 'Défrichage',
            'remarque': '',
          },
          {
            'code': 'K',
            'selected': isChecked('23', 'K'),
            'libelle': 'Brûlage des parcelles',
            'remarque': '',
          },
          {
            'code': 'L',
            'selected': isChecked('23', 'L'),
            'libelle': 'Autres (à préciser dans les remarques)',
            'remarque': precision('23', 'L'),
          },
        ],
        'branchement': '24',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '24',
        'question':
            "Pour les personnes âgées de 13 à 15 ans, quel est le nombre moyen d'heures de travail par jour ?",
        'options': [
          {
            'code': 'A',
            'selected': code('24') == 'A',
            'libelle': 'Moins de 3 heures',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('24') == 'B',
            'libelle': 'Plus de 3 heures',
            'remarque': '',
          },
        ],
        'branchement': '25',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '25',
        'question': "Y a-t-il des membres du ménage âgés de moins de 13 ans ?",
        'options': [
          {
            'code': 'D',
            'selected': code('25') == 'D',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'Z',
            'selected': code('25') == 'Z',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '26/28',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '26',
        'question': "Nombre de membres du ménage âgés de moins de 13 ans",
        'type': 'number',
        'code': '0',
        'reponse': '(saisir le nombre)',
        'remarque': val('26'),
        'branchement': '27',
      },
      {
        'theme': 'MÉNAGES',
        'ref': '27',
        'question':
            "Les personnes âgées de moins de 13 ans travaillent-elles sur la plantation ?",
        'options': [
          {
            'code': 'A',
            'selected': code('27') == 'A',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('27') == 'B',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '28',
      },
    ];
  }

  List<Map<String, dynamic>> _buildQuestionsTravailleurs() {
    return [
      {
        'theme': 'TRAVAILLEURS',
        'ref': '28',
        'question': "Y a-t-il des travailleurs dans l'exploitation ?",
        'options': [
          {
            'code': 'A',
            'selected': code('28') == 'A',
            'libelle': 'Oui (travailleurs réguliers/occasionnels)',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('28') == 'B',
            'libelle': 'Pas de travailleurs',
            'remarque': '',
          },
        ],
        'branchement': '29/42',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '29',
        'question': "Type de consentement accordé par les travailleurs :",
        'options': [
          {
            'code': 'A',
            'selected': code('29') == 'A',
            'libelle': 'Consentement écrit',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('29') == 'B',
            'libelle': 'Consentement verbal',
            'remarque': '',
          },
          {
            'code': 'C',
            'selected': code('29') == 'C',
            'libelle': 'Absence de consentement',
            'remarque': '',
          },
        ],
        'branchement': '30',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '30',
        'question': "Comment le salaire des travailleurs est-il calculé ?",
        'options': [
          {
            'code': 'A',
            'selected': code('30') == 'A',
            'libelle': 'Participation aux bénéfices',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('30') == 'B',
            'libelle': 'Volume',
            'remarque': '',
          },
          {
            'code': 'C',
            'selected': code('30') == 'C',
            'libelle': 'Jour',
            'remarque': '',
          },
          {
            'code': 'D',
            'selected': code('30') == 'D',
            'libelle': 'Tâche',
            'remarque': '',
          },
          {
            'code': 'E',
            'selected': code('30') == 'E',
            'libelle': 'Fixe mensuel',
            'remarque': '',
          },
        ],
        'branchement': '31',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '31',
        'question': "Revenu mensuel des travailleurs (FCFA) ?",
        'type': 'number',
        'code': '0',
        'reponse': '(saisir le nombre)',
        'remarque': val('31'),
        'branchement': '32',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '32',
        'question': "Temps de travail hebdomadaire moyen des travailleurs ?",
        'type': 'number',
        'code': '0',
        'reponse': '(saisir le nombre)',
        'remarque': val('32'),
        'branchement': '33',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '33',
        'question': "Y a-t-il des travailleurs âgés de 18 ans et plus ?",
        'options': [
          {
            'code': 'A',
            'selected': code('33') == 'A',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'Z',
            'selected': code('33') == 'Z',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '34/35',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '34',
        'question': "Nombre de travailleurs âgés de 18 ans et plus",
        'type': 'number',
        'code': '0',
        'reponse': '(saisir le nombre)',
        'remarque': val('34'),
        'branchement': '35',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '35',
        'question': "Y a-t-il des travailleurs âgés de 16 à 17 ans ?",
        'options': [
          {
            'code': 'B',
            'selected': code('35') == 'B',
            'libelle': 'Oui',
            'remarque': '',
          },
          {
            'code': 'Z',
            'selected': code('35') == 'Z',
            'libelle': 'Non',
            'remarque': '',
          },
        ],
        'branchement': '36/38',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '36',
        'question': "Nombre de travailleurs entre 16-17 ans",
        'type': 'number',
        'code': '0',
        'reponse': '(saisir le nombre)',
        'remarque': val('36'),
        'branchement': '37',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '37',
        'question':
            "Pour les personnes âgées de 13 à 15 ans, quelles activités leur sont confiées ? (Plusieurs options possibles)",
        'options': [
          {
            'code': 'A',
            'selected': isChecked('37', 'A'),
            'libelle': 'Effectuer la saignée',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': isChecked('37', 'B'),
            'libelle': 'Collecte du latex dans les tasses',
            'remarque': '',
          },
          {
            'code': 'C',
            'selected': isChecked('37', 'C'),
            'libelle': 'Faire le rabattage',
            'remarque': '',
          },
          {
            'code': 'D',
            'selected': isChecked('37', 'D'),
            'libelle': 'Ramasser les graines',
            'remarque': '',
          },
          {
            'code': 'E',
            'selected': isChecked('37', 'E'),
            'libelle': 'Semer les graines',
            'remarque': '',
          },
          {
            'code': 'F',
            'selected': isChecked('37', 'F'),
            'libelle': 'Effectuer la Trouaison',
            'remarque': '',
          },
          {
            'code': 'G',
            'selected': isChecked('37', 'G'),
            'libelle': 'Pulvérisation de produits chimiques (herbicides, etc.)',
            'remarque': '',
          },
          {
            'code': 'H',
            'selected': isChecked('37', 'H'),
            'libelle': 'Aider au piquetage',
            'remarque': '',
          },
          {
            'code': 'I',
            'selected': isChecked('37', 'I'),
            'libelle': 'Couvrir le caoutchouc stocké avec des bâches',
            'remarque': '',
          },
          {
            'code': 'J',
            'selected': isChecked('37', 'J'),
            'libelle': 'Défrichage',
            'remarque': '',
          },
          {
            'code': 'K',
            'selected': isChecked('37', 'K'),
            'libelle': 'Brûlage des parcelles',
            'remarque': '',
          },
          {
            'code': 'L',
            'selected': isChecked('37', 'L'),
            'libelle': 'Autres (à préciser dans les remarques)',
            'remarque': precision('37', 'L'),
          },
        ],
        'branchement': '38',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '38',
        'question': "Y a-t-il des travailleurs de moins de 16 ans ?",
        'options': [
          {
            'code': 'C',
            'selected': code('38') == 'C',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'Z',
            'selected': code('38') == 'Z',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '39',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '39',
        'question':
            "Y a-t-il des Travailleurs étrangers ? (En provenance d'un autre pays)",
        'options': [
          {
            'code': 'A',
            'selected': code('39') == 'A',
            'libelle': 'Oui, au moins un travailleur étranger',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('39') == 'B',
            'libelle': 'Non, seulement les travailleurs locaux',
            'remarque': '',
          },
        ],
        'branchement': '40/42',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '40',
        'question':
            "Les documents d'identité originaux des travailleurs étrangers sont-ils conservés ?",
        'options': [
          {
            'code': 'A',
            'selected': code('40') == 'A',
            'libelle': 'OUI',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': code('40') == 'B',
            'libelle': 'NON',
            'remarque': '',
          },
        ],
        'branchement': '41',
      },
      {
        'theme': 'TRAVAILLEURS',
        'ref': '41',
        'question':
            "Les travailleurs étrangers doivent-ils verser des droits pour obtenir un travail sur la ferme ?",
        'options': [
          {
            'code': 'A',
            'selected': isChecked('41', 'A'),
            'libelle': 'Dépôt de garantie (financier, bien ou)',
            'remarque': '',
          },
          {
            'code': 'B',
            'selected': isChecked('41', 'B'),
            'libelle': 'Frais de recrutement remboursés au travailleur',
            'remarque': '',
          },
          {
            'code': 'C',
            'selected': isChecked('41', 'C'),
            'libelle': 'Frais de recrutement non remboursés au travailleur',
            'remarque': '',
          },
          {
            'code': 'D',
            'selected': isChecked('41', 'D'),
            'libelle': 'Ne payent rien',
            'remarque': '',
          },
        ],
        'branchement': '42',
      },
    ];
  }

  List<Map<String, dynamic>> _buildQuestionsRevenu() {
    return [
      {
        'theme': 'REVENU EXPLOITANT',
        'ref': '42',
        'question': "Quel est le revenu mensuel moyen du fermier (FCFA) ?",
        'type': 'number',
        'code': '0',
        'reponse': '(saisir le nombre)',
        'remarque': val('42'),
        'branchement': '43',
      },
      {
        'theme': 'REVENU EXPLOITANT',
        'ref': '43',
        'question':
            "Quel pourcentage du revenu mensuel du fermier est généré par les activités liées au caoutchouc ?",
        'type': 'percentage',
        'code': '0',
        'reponse': '(saisir le nombre)',
        'remarque': val('43'),
        'branchement': 'FIN',
      },
    ];
  }

  /// =====================================================
  /// CONSTRUCTION RAPPORT MENSUEL (VERSION FINALE CORRIGÉE)
  /// =====================================================

  pw.Widget _buildRapportMensuel() {
    // ✅ Sécurité : ces valeurs sont garanties non-null grâce à la vérification
    final data = widget.reportData!;
    final mois = widget.mois!;
    final zone = widget.zone ?? (data['zone_agent'] ?? 'Toutes les zones');
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ==================== EN-TÊTE AVEC LOGO SOGB ====================
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(20),
          color: PdfColors.green,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo SOGB à gauche
              pw.Image(
                logo!, // Le logo est chargé dans _generatePdf
                height: 60,
              ),
              // Titre et informations à droite
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'RAPPORT MENSUEL RDUE',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Période : ${DateFormat('MMMM yyyy', 'fr_FR').format(mois)}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.white),
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.Text(
                    'Généré le : $dateStr',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.white),
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 20),

        // ==================== INFORMATIONS AGENT ENQUÊTEUR ====================
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text('👤 ', style: pw.TextStyle(fontSize: 14)),
                  pw.Text(
                    'AGENT ENQUÊTEUR',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700,
                    ),
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildInfoRowAgent(
                      'Nom complet',
                      data['enqueteur_nom'] as String? ?? '—',
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: _buildInfoRowAgent(
                      'Contact',
                      data['enqueteur_contact'] as String? ?? '—',
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildInfoRowAgent(
                      'Zone',
                      data['enqueteur_zone'] as String? ?? '—',
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(child: _buildInfoRowAgent('Filtre', zone)),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 20),

        // ==================== RÉSUMÉ DE L'ACTIVITÉ ====================
        _buildRapportSection('📊 RÉSUMÉ DE L\'ACTIVITÉ', [
          _buildStatRow(
            'Enquêtes réalisées',
            (data['total_enquetes'] as int? ?? 0).toString(),
            '📋',
          ),
          pw.Divider(),
          _buildStatRow(
            'Enquêtes conformes',
            (data['enquetes_conformes'] as int? ?? 0).toString(),
            '✅',
            color: PdfColors.green,
          ),
          pw.Divider(),
          _buildStatRow(
            'Enquêtes non conformes',
            (data['enquetes_non_conformes'] as int? ?? 0).toString(),
            '⚠️',
            color: PdfColors.red,
          ),
          pw.Divider(),
          _buildStatRow(
            'Refus d\'enquête',
            (data['refus_enquetes'] as int? ?? 0).toString(),
            '⛔',
            color: PdfColors.orange,
          ),
        ]),

        pw.SizedBox(height: 20),

        // ==================== RÉPARTITION PAR VILLAGE ====================
        _buildRapportSection('📍 RÉPARTITION PAR VILLAGE', [
          ...(data['villages_list'] as List? ?? [])
              .map(
                (village) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        village['nom'] ?? '',
                        style: pw.TextStyle(fontSize: 11),
                      ),
                      pw.Text(
                        '${village['total']} enquête${village['total'] > 1 ? 's' : ''}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          if ((data['villages_list'] as List?)?.isEmpty ?? true)
            pw.Text(
              'Aucune donnée disponible',
              style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
            ),
        ]),

        pw.SizedBox(height: 20),

        // ==================== INDICATEURS DE NON-CONFORMITÉ ====================
        _buildRapportSection('⚠️ INDICATEURS DE NON-CONFORMITÉ', [
          // Travail des enfants
          pw.Text(
            '👶 TRAVAIL DES ENFANTS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          _buildIndicatorRow(
            'Présence 16-17 ans',
            (data['presence_16_17'] as int? ?? 0).toString(),
          ),
          _buildIndicatorRow(
            'Présence 13-15 ans',
            (data['presence_13_15'] as int? ?? 0).toString(),
          ),
          _buildIndicatorRow(
            'Présence moins de 13 ans',
            (data['presence_moins_13'] as int? ?? 0).toString(),
          ),

          pw.Divider(),
          pw.SizedBox(height: 8),

          // Litiges fonciers
          pw.Text(
            '⚖️ LITIGES FONCIERS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          _buildIndicatorRow(
            'Litiges détectés',
            (data['litiges'] as int? ?? 0).toString(),
          ),

          pw.Divider(),
          pw.SizedBox(height: 8),

          // Produits chimiques interdits
          pw.Text(
            '🧪 PRODUITS CHIMIQUES INTERDITS',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          _buildIndicatorRow(
            'Paraquat',
            (data['produit_paraquat'] as int? ?? 0).toString(),
          ),
          _buildIndicatorRow(
            'Glyphosate',
            (data['produit_glyphosate'] as int? ?? 0).toString(),
          ),
          _buildIndicatorRow(
            '2-4D',
            (data['produit_24d'] as int? ?? 0).toString(),
          ),
          _buildIndicatorRow(
            'Autres produits',
            (data['produit_autres'] as int? ?? 0).toString(),
          ),

          pw.Divider(),
          pw.SizedBox(height: 8),

          // Exploitation humaine
          pw.Text(
            '👥 EXPLOITATION HUMAINE',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          _buildIndicatorRow(
            'Travailleurs mineurs',
            (data['travailleurs_mineurs'] as int? ?? 0).toString(),
          ),
          _buildIndicatorRow(
            'Absence de consentement',
            (data['absence_consentement'] as int? ?? 0).toString(),
          ),
          _buildIndicatorRow(
            'Documents conservés',
            (data['documents_conserves'] as int? ?? 0).toString(),
          ),
          _buildIndicatorRow(
            'Frais exigés',
            (data['frais_exiges'] as int? ?? 0).toString(),
          ),
        ]),

        pw.SizedBox(height: 20),

        // ==================== CONCLUSION ====================
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          color: PdfColors.blue50,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '📋 CONCLUSION',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                _getConclusionTexte(data, mois),
                style: pw.TextStyle(fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 20),

        // ==================== PIED DE PAGE ====================
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Document confidentiel - RubberWay',
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
            pw.Text(
              'Page 1/1',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          ],
        ),
      ],
    );
  }

  /// Fonction pour afficher une ligne d'information agent
  pw.Widget _buildInfoRowAgent(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(
          '$label : ',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
        ),
      ],
    );
  }

  /// ✅ Fonction corrigée pour afficher une ligne de statistique avec emoji
  pw.Widget _buildStatRow(
    String label,
    String value,
    String iconText, {
    PdfColor? color,
  }) {
    return pw.Row(
      children: [
        pw.Text(iconText, style: pw.TextStyle(fontSize: 14)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 11))),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }

  /// Fonction pour afficher une ligne d'indicateur
  pw.Widget _buildIndicatorRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 20, bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('  • $label', style: pw.TextStyle(fontSize: 10)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Fonction utilitaire pour créer une section de rapport
  pw.Widget _buildRapportSection(String titre, List<pw.Widget> enfants) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            titre,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          ...enfants,
        ],
      ),
    );
  }

  /// Fonction utilitaire pour les lignes indentées (pour compatibilité)
  pw.Widget _buildRapportRowIndent(String label, String valeur) {
    return _buildIndicatorRow(label, valeur);
  }

  /// Version améliorée de _buildRapportRow avec couleur optionnelle (pour compatibilité)
  pw.Widget _buildRapportRow(
    String label,
    String valeur, {
    PdfColor? valueColor,
  }) {
    return _buildStatRow(label, valeur, '•', color: valueColor);
  }

  /// Mise à jour de la fonction _getConclusionTexte
  String _getConclusionTexte(Map<String, dynamic> data, DateTime mois) {
    final total = (data['total_enquetes'] as int? ?? 0);
    final nonConformes = (data['enquetes_non_conformes'] as int? ?? 0);
    final refus = (data['refus_enquetes'] as int? ?? 0);
    final travailEnfants =
        ((data['presence_16_17'] as int? ?? 0) +
        (data['presence_13_15'] as int? ?? 0) +
        (data['presence_moins_13'] as int? ?? 0));
    final litiges = (data['litiges'] as int? ?? 0);
    final villages = data['villages_list'] as List? ?? [];

    final pourcentageNonConforme = total > 0
        ? ((nonConformes) * 100 / total).toStringAsFixed(1)
        : '0';

    String zonesRisque = '';
    if (villages.isNotEmpty) {
      final villagesAvecRisque = villages
          .where((v) => (v['total'] as int) > 3)
          .toList();
      if (villagesAvecRisque.isNotEmpty) {
        zonesRisque =
            ' dans les villages ${villagesAvecRisque.map((v) => v['nom']).join(', ')}';
      }
    }

    return 'Au cours du mois de ${DateFormat('MMMM yyyy', 'fr_FR').format(mois)}, '
        '$total enquêtes RDUE ont été réalisées. '
        '$nonConformes enquêtes (${pourcentageNonConforme}%) sont non conformes, '
        'dont $travailEnfants cas de travail des enfants et $litiges litiges fonciers. '
        '$refus producteurs ont refusé de participer à l\'enquête. '
        'Des actions correctives sont recommandées$zonesRisque.';
  }

  /// =====================================================
  /// CONSTRUCTION TABLEAU AVEC PADDING AJUSTABLE
  /// =====================================================

  pw.Widget _buildTable(
    List<Map<String, dynamic>> questions, {
    bool isMenage = false,
    double padding = 2.0,
    double fontSize = 6.5,
  }) {
    final rows = <pw.TableRow>[];

    // En-tête avec 8 colonnes
    rows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          headerCell('Thème', fontSize: isMenage ? 6 : 7),
          headerCell('Ref', fontSize: isMenage ? 6 : 7),
          headerCell('Question', fontSize: isMenage ? 6 : 7),
          headerCell('Code', fontSize: isMenage ? 6 : 7),
          headerCell('Cocher', fontSize: isMenage ? 6 : 7),
          headerCell('Réponse', fontSize: isMenage ? 6 : 7),
          headerCell('Remarque', fontSize: isMenage ? 6 : 7),
          headerCell('→', fontSize: isMenage ? 6 : 7),
        ],
      ),
    );

    for (var q in questions) {
      if (q.containsKey('options')) {
        final options = q['options'] as List;
        for (int i = 0; i < options.length; i++) {
          final opt = options[i];
          rows.add(
            pw.TableRow(
              children: [
                // Thème
                dataCell(
                  i == 0 ? (q['theme'] ?? '') : '',
                  fontSize: fontSize,
                  bold: i == 0,
                  padding: padding,
                ),
                // Ref
                dataCell(
                  i == 0 ? q['ref'] : '',
                  fontSize: fontSize,
                  center: true,
                  padding: padding,
                ),
                // Question
                dataCell(
                  i == 0 ? q['question'] : '',
                  fontSize: fontSize,
                  padding: padding,
                ),
                // Code
                dataCell(
                  opt['code'],
                  fontSize: fontSize,
                  bold: true,
                  center: true,
                  padding: padding,
                ),
                // X (croix)
                dataCell(
                  opt['selected'] ? 'X' : '',
                  fontSize: fontSize,
                  center: true,
                  padding: padding,
                  bold: opt['selected'],
                  background: opt['code'] == '0' ? PdfColors.grey200 : null,
                ),
                // Réponse
                dataCell(opt['libelle'], fontSize: fontSize, padding: padding),
                dataCell(
                  opt['remarque'] ?? '',
                  fontSize: fontSize,
                  padding: padding,
                  background:
                      (opt['remarque'] == null ||
                          opt['remarque'].toString().trim().isEmpty)
                      ? PdfColors.grey200
                      : null,
                ),
                // Branchement
                dataCell(
                  i == 0 ? (q['branchement'] ?? '') : '',
                  fontSize: fontSize,
                  center: true,
                  padding: padding,
                ),
              ],
            ),
          );
        }
      } else {
        rows.add(
          pw.TableRow(
            children: [
              // Thème
              dataCell(q['theme'] ?? '', fontSize: fontSize, padding: padding),
              // Ref
              dataCell(
                q['ref'] ?? '',
                fontSize: fontSize,
                center: true,
                padding: padding,
              ),
              // Question
              dataCell(
                q['question'] ?? '',
                fontSize: fontSize,
                padding: padding,
              ),
              // Code
              dataCell(
                q['code'] ?? '0',
                fontSize: fontSize,
                center: true,
                padding: padding,
              ),
              // X (vide pour les questions sans options)
              dataCell('', fontSize: fontSize, padding: padding),
              // Réponse
              dataCell(
                q['reponse'] ?? '',
                fontSize: fontSize,
                padding: padding,
              ),
              // Remarque
              dataCell(
                q['remarque'] ?? '',
                fontSize: fontSize,
                padding: padding,
              ),
              // Branchement
              dataCell(
                q['branchement'] ?? '',
                fontSize: fontSize,
                center: true,
                padding: padding,
              ),
            ],
          ),
        );
      }
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.1),
      columnWidths: <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(isMenage ? 0.8 : 0.9),
        1: pw.FlexColumnWidth(0.4),
        2: pw.FlexColumnWidth(isMenage ? 2.0 : 2.2),
        3: pw.FlexColumnWidth(0.2),
        4: pw.FlexColumnWidth(0.2),
        5: pw.FlexColumnWidth(isMenage ? 1.0 : 1.2),
        6: pw.FlexColumnWidth(isMenage ? 0.8 : 1.0),
        7: pw.FlexColumnWidth(0.3),
      },
      children: rows,
    );
  }

  /// =====================================================
  /// MOTEUR DE CONFORMITÉ (avec nouveaux IDs)
  /// =====================================================

  bool _estNonConforme() {
    if (code('1') == 'C') return true;
    if (isChecked('9', 'A') || isChecked('9', 'C')) return true;
    if (code('11') == 'A') return true;

    List<String> activitesDangereuses = ['A', 'C', 'F', 'G', 'J', 'K'];
    for (var act in activitesDangereuses) {
      if (isChecked('19', act)) return true;
      if (isChecked('23', act)) return true;
      if (isChecked('37', act)) return true;
    }

    if (code('24') == 'B') return true;
    if (code('27') == 'A') return true;
    if (code('29') == 'C') return true;
    if (code('40') == 'A') return true;
    if (isChecked('41', 'A') || isChecked('41', 'B') || isChecked('41', 'C'))
      return true;

    return false;
  }

  /// =====================================================
  /// CHARGEMENT DES IMAGES
  /// =====================================================

  Future<List<pw.ImageProvider?>> _loadPdfImages(List<String?> paths) async {
    final originalImages = await Future.wait<Uint8List?>(
      paths.map((path) async {
        if (path == null || path.isEmpty) return null;
        try {
          final file = File(path);
          if (!await file.exists()) {
            debugPrint('Image non trouvée: $path');
            return null;
          }
          return await file.readAsBytes();
        } catch (e) {
          debugPrint('Erreur chargement image $path: $e');
          return null;
        }
      }),
    );

    if (originalImages.every((bytes) => bytes == null)) {
      return List<pw.ImageProvider?>.filled(paths.length, null);
    }

    final preparedImages = await compute(_preparePdfImages, originalImages);
    return preparedImages
        .map((bytes) => bytes == null ? null : pw.MemoryImage(bytes))
        .toList(growable: false);
  }

  /// =====================================================
  /// GÉNÉRATION PDF
  /// =====================================================

  Future<void> _generatePdf() async {
    setState(() {
      _loading = true;
      _error = null;
      _progressMessage = "Démarrage...";
    });

    try {
      // ✅ VÉRIFICATION CRITIQUE pour le rapport mensuel
      if (widget.pdfType == PdfType.rapportMensuel) {
        if (widget.reportData == null || widget.mois == null) {
          throw Exception(
            "❌ Données du rapport mensuel manquantes (reportData ou mois null)",
          );
        }
        debugPrint("✅ Rapport mensuel - données validées");
      }

      if (widget.pdfType == PdfType.enquete) {
        await _loadEnqueteData();
      }

      setState(() => _progressMessage = "Préparation du PDF...");
      final now = DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(now);
      final prefs = await SharedPreferences.getInstance();

      // Charger le logo pour tous les types de PDF
      logo = await imageFromAssetBundle("assets/images/logo_sogb.jpg");

      // Charger les images pour la page 5 (uniquement pour enquête)
      pw.ImageProvider? photoInterlocuteur;
      pw.ImageProvider? photoPieceRecto;
      pw.ImageProvider? photoPieceVerso;
      pw.ImageProvider? photoDocFoncier;
      pw.ImageProvider? photoReconnaissance;
      pw.ImageProvider? signaturePlanteur;
      pw.ImageProvider? signatureAgent;

      if (widget.pdfType == PdfType.enquete) {
        setState(() => _progressMessage = "Chargement des images...");

        // Photos
        final images = await _loadPdfImages([
          _photoInterlocuteurPath,
          _photoPieceRectoPath,
          _photoPieceVersoPath,
          _photoDocFoncierPath,
          _photoReconnaissancePath,
          _signaturePlanteurPath,
          _signatureAgentPath,
        ]);
        photoInterlocuteur = images[0];
        photoPieceRecto = images[1];
        photoPieceVerso = images[2];
        photoDocFoncier = images[3];
        photoReconnaissance = images[4];
        signaturePlanteur = images[5];
        signatureAgent = images[6];
      }

      // Polices
      setState(() => _progressMessage = "Chargement des polices...");
      final regular = pw.Font.ttf(
        await rootBundle.load("assets/fonts/Roboto-Regular.ttf"),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load("assets/fonts/Roboto-Bold.ttf"),
      );

      // Les photos sont déjà encodées en JPEG. Désactiver la compression PDF
      // évite une seconde compression coûteuse sur les téléphones de terrain.
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
      );

      final nonConforme = widget.pdfType == PdfType.enquete
          ? _estNonConforme()
          : false;
      final statutConformite = nonConforme ? "NON CONFORME" : "CONFORME";
      final couleurStatut = nonConforme ? PdfColors.red : PdfColors.green;

      // Construire les questions (pour enquête)
      List<Map<String, dynamic>>? questionsDF;
      List<Map<String, dynamic>>? questionsEnv;
      List<Map<String, dynamic>>? questionsDT;
      List<Map<String, dynamic>>? questionsMen;
      List<Map<String, dynamic>>? questionsTrav;
      List<Map<String, dynamic>>? questionsRev;

      if (widget.pdfType == PdfType.enquete) {
        setState(() => _progressMessage = "Préparation des questions...");
        questionsDF = _buildQuestionsDroitsFonciers();
        questionsEnv = _buildQuestionsEnvironnement();
        questionsDT = _buildQuestionsDroitsTiers();
        questionsMen = _buildQuestionsMenages();
        questionsTrav = _buildQuestionsTravailleurs();
        questionsRev = _buildQuestionsRevenu();
      }
      final answersIndex = widget.pdfType == PdfType.enquete
          ? _buildAnswersIndex([
              questionsDF!, questionsEnv!, questionsDT!, questionsMen!,
              questionsTrav!, questionsRev!,
            ])
          : '';

      if (widget.pdfType == PdfType.rapportMensuel) {
        setState(() => _progressMessage = "Génération du rapport mensuel...");
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (_) => _buildRapportMensuel(),
          ),
        );
      } else {
        setState(() => _progressMessage = "Génération de la page 1...");
        // PAGE 1
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(20),
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // En-tête
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Image(logo!, height: 45),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'QUESTIONNAIRE RDUE SOGB',
                          style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Date : $dateStr',
                          style: pw.TextStyle(fontSize: 9),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: pw.BoxDecoration(
                            color: nonConforme
                                ? PdfColors.red50
                                : PdfColors.green50,
                            border: pw.Border.all(color: couleurStatut),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            statutConformite,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: couleurStatut,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 15),
                pw.Divider(),
                pw.SizedBox(height: 12),

                // Ligne 1 : Agent et Validateur
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: infoBox('AGENT ENQUÊTEUR', [
                        infoItem(
                          'Nom',
                          '${infos?['prenom_enqueteur'] ?? ''} ${infos?['nom_enqueteur'] ?? ''}'
                              .trim(),
                        ),
                        infoItem(
                          'Contact',
                          prefs.getString("agent_contact") ?? '',
                        ),
                        infoItem('Zone', infos?['nom_zone'] ?? ''),
                      ]),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: infoBox('VALIDATEUR', [
                        infoItem(
                          'Nom',
                          '$_validateurPrenoms $_validateurNom'.trim(),
                        ),
                        infoItem('Contact', _validateurContact),
                      ]),
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),

                // Ligne 2 : Producteur et Interlocuteur
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: infoBox('PRODUCTEUR', [
                        infoItem('Code PHI', infos?['code_producteur'] ?? ''),
                        infoItem('Nom', infos?['nom_producteur'] ?? ''),
                        infoItem('Contact', infos?['contact'] ?? ''),
                        infoItem('Village', infos?['village'] ?? ''),
                      ]),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: infoBox(
                        'INTERLOCUTEUR',
                        _estProducteurQuiRepond
                            ? [
                                pw.Text(
                                  'Planteur lui-même',
                                  style: pw.TextStyle(fontSize: 8),
                                ),
                              ]
                            : [
                                infoItem('Nom', _interlocuteurNom),
                                infoItem('Contact', _interlocuteurContact),
                                infoItem('Lien', _interlocuteurLien),
                              ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 15),

                // Texte de consentement
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.3),
                    color: PdfColors.grey50,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CONSENTEMENT DU PRODUCTEUR',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Divider(),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Je soussigné(e) ci-dessous :\n\n'
                        'Par la présente, je donne mon consentement et j\'autorise SOGB et ses partenaires à utiliser toute '
                        'information confidentielle, y compris les informations personnelles, que j\'ai fournies lors de la collecte de '
                        'données liées à la cartographie de mes parcelles et à la réalisation d\'enquêtes de légalité.\n\n'
                        'Les informations collectées peuvent inclure des données personnelles relatives au nom de l\'agriculteur, '
                        'à son identité, à sa date de naissance, à son adresse, à ses coordonnées, à sa photo, aux détails de '
                        'sa parcelle, aux données de base sur son foyer et ses employés, ainsi qu\'à des données économiques.\n\n'
                        'Je comprends que les données personnelles que je fournis sont des données confidentielles, '
                        'où ces données seront stockées correctement pour maintenir la confidentialité et ne peuvent être '
                        'consultées que par des personnes autorisées. SOGB peut autoriser ses partenaires à accéder à certaines '
                        'données sur la base d\'un accord de confidentialité.\n\n'
                        'Je comprends que je peux retirer mon accord à tout moment en envoyant une notification écrite par '
                        'courrier électronique à SOGB. Je m\'engage à ne pas soumettre de réclamations, de demandes '
                        'de compensation, de demandes d\'exécution d\'obligations ou d\'autres actions légales en raison '
                        'de l\'utilisation d\'informations confidentielles par SOGB sur la base de cette lettre d\'accord. Cet accord est '
                        'valable à compter de la date du présent consentement et restera en vigueur jusqu\'à son retrait.\n\n'
                        'Fait pour valoir ce que de droit.',
                        style: pw.TextStyle(fontSize: 9, height: 1.3),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 8),

                // Mention consentement
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    border: pw.Border.all(color: PdfColors.green),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        '✓',
                        style: pw.TextStyle(
                          color: PdfColors.green,
                          fontSize: 11,
                        ),
                      ),
                      pw.SizedBox(width: 5),
                      pw.Text(
                        'Le producteur a consenti au questionnaire',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Signatures
                pw.Divider(),
                pw.SizedBox(height: 10),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Signature agent
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SIGNATURE AGENT',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          width: 170,
                          height: 65,
                          decoration: pw.BoxDecoration(border: pw.Border.all()),
                          child: signatureAgent != null
                              ? pw.Image(signatureAgent, fit: pw.BoxFit.contain)
                              : pw.Center(
                                  child: pw.Text(
                                    'Non signé',
                                    style: pw.TextStyle(fontSize: 9),
                                  ),
                                ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          '${infos?['prenom_enqueteur']} ${infos?['nom_enqueteur']}'
                              .trim(),
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Contact: ${prefs.getString("agent_contact") ?? ''}',
                          style: pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          'Zone: ${infos?['nom_zone'] ?? ''}',
                          style: pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),

                    // Signature producteur
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'SIGNATURE PLANTEUR',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Container(
                          width: 170,
                          height: 65,
                          decoration: pw.BoxDecoration(border: pw.Border.all()),
                          child: signaturePlanteur != null
                              ? pw.Image(
                                  signaturePlanteur,
                                  fit: pw.BoxFit.contain,
                                )
                              : pw.Center(
                                  child: pw.Text(
                                    'Non signé',
                                    style: pw.TextStyle(fontSize: 9),
                                  ),
                                ),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          _estProducteurQuiRepond
                              ? (infos?['nom_producteur'] ?? '')
                              : _interlocuteurNom,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 8),

                pw.Text(
                  'Document confidentiel généré le $dateStr',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontStyle: pw.FontStyle.italic,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                if (answersIndex.isNotEmpty)
                  pw.Text(
                    answersIndex,
                    style: pw.TextStyle(fontSize: 0.1, color: PdfColors.white),
                  ),
              ],
            ),
          ),
        );

        setState(() => _progressMessage = "Génération de la page 2...");
        // PAGE 2
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(8),
            build: (_) => pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(3),
                  color: PdfColors.green50,
                  child: pw.Text(
                    'DROITS FONCIERS',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 5),
                _buildTable(questionsDF!, padding: 3.0, fontSize: 6.5),
                pw.SizedBox(height: 1),
                _buildTable(questionsEnv!, padding: 3.0, fontSize: 6.5),
                pw.SizedBox(height: 1),
                _buildTable(questionsDT!, padding: 3.0, fontSize: 6.5),
              ],
            ),
          ),
        );

        setState(() => _progressMessage = "Génération de la page 3...");
        // PAGE 3
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(8),
            build: (_) => pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(3),
                  color: PdfColors.amber50,
                  child: pw.Text(
                    'MÉNAGES',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.amber700,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 4.5),
                _buildTable(
                  questionsMen!,
                  isMenage: true,
                  padding: 1.5,
                  fontSize: 6.0,
                ),
              ],
            ),
          ),
        );

        setState(() => _progressMessage = "Génération de la page 4...");
        // PAGE 4
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(8),
            build: (_) => pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(2),
                  color: PdfColors.blue50,
                  child: pw.Text(
                    'TRAVAILLEURS | REVENU EXPLOITANT',
                    style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue700,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 4),
                _buildTable(questionsTrav!, padding: 1.5, fontSize: 6.0),
                pw.SizedBox(height: 4),
                _buildTable(questionsRev!, padding: 1.5, fontSize: 6.0),
              ],
            ),
          ),
        );

        setState(() => _progressMessage = "Génération de la page 5...");
        // PAGE 5
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(15),
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 5),
                  color: PdfColors.grey300,
                  child: pw.Text(
                    'PHOTOS',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 15),

                // Ligne 1 : Photos d'identité
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPhotoFrame('Interlocuteur', photoInterlocuteur, 110),
                    _buildPhotoFrame('Pièce recto', photoPieceRecto, 110),
                    _buildPhotoFrame('Pièce verso', photoPieceVerso, 110),
                  ],
                ),

                pw.SizedBox(height: 15),

                // Ligne 2 : Photos de documentation
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPhotoFrame('Documentation', photoDocFoncier, 110),
                    _buildPhotoFrame(
                      'Reconnaissance',
                      photoReconnaissance,
                      110,
                    ),
                    pw.Container(width: 110),
                  ],
                ),

                pw.SizedBox(height: 15),

                // Mention de confirmation
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    border: pw.Border.all(color: PdfColors.green),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        '✓',
                        style: pw.TextStyle(
                          color: PdfColors.green,
                          fontSize: 12,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        'Photos confirmées',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      setState(
        () => _progressMessage =
            "Mise en page des ${widget.pdfType == PdfType.enquete ? 5 : 1} pages du PDF...",
      );
      // Sauvegarde avec nom formaté
      String fileName;
      if (widget.pdfType == PdfType.rapportMensuel) {
        final mois = widget.mois!;
        final data = widget.reportData!;

        // Récupérer le nom et prénom de l'agent enquêteur
        String agentNom = data['enqueteur_nom'] as String? ?? '';
        String agentPrenom = data['enqueteur_prenom'] as String? ?? '';

        // Si les champs séparés ne sont pas disponibles, essayer de décomposer le nom complet
        if (agentNom.isEmpty && agentPrenom.isEmpty) {
          String agentNomComplet = data['enqueteur_nom'] as String? ?? '';
          if (agentNomComplet.isNotEmpty) {
            // Essayer de séparer prénom et nom (supposition: le dernier mot est le nom)
            List<String> parts = agentNomComplet.split(' ');
            if (parts.length > 1) {
              agentPrenom = parts.sublist(0, parts.length - 1).join(' ');
              agentNom = parts.last;
            } else {
              agentNom = agentNomComplet;
            }
          }
        }

        // Nettoyer les noms pour le fichier
        String cleanFileName(String text) {
          return text
              .replaceAll(RegExp(r'[^\w\s-]'), '')
              .replaceAll(RegExp(r'[\s-]+'), '_')
              .trim()
              .toLowerCase();
        }

        String agentNomPropre = cleanFileName(agentNom);
        String agentPrenomPropre = cleanFileName(agentPrenom);

        // Construire le nom du fichier avec le nom et prénom de l'agent
        if (agentPrenomPropre.isNotEmpty && agentNomPropre.isNotEmpty) {
          fileName =
              'Rapport_mensuel_${DateFormat('MM_yyyy').format(mois)}_${agentPrenomPropre}_${agentNomPropre}.pdf';
        } else if (agentNomPropre.isNotEmpty) {
          fileName =
              'Rapport_mensuel_${DateFormat('MM_yyyy').format(mois)}_${agentNomPropre}.pdf';
        } else {
          fileName =
              'Rapport_mensuel_${DateFormat('MM_yyyy').format(mois)}.pdf';
        }
      } else {
        String codePhi = infos?['code_producteur'] ?? 'inconnu';
        String nomProducteur = infos?['nom_producteur'] ?? 'inconnu';

        String cleanFileName(String text) {
          return text
              .replaceAll(RegExp(r'[^\w\s-]'), '')
              .replaceAll(RegExp(r'[\s-]+'), '_')
              .trim();
        }

        String codePropre = cleanFileName(codePhi);
        String nomPropre = cleanFileName(nomProducteur);

        fileName = (codePhi != 'inconnu' && nomProducteur != 'inconnu')
            ? '${codePropre}_${nomPropre}.pdf'
            : 'enquete_${infos?['code_producteur'] ?? widget.enqueteId}.pdf';
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      // Laisse Flutter afficher l'étape avant l'assemblage, qui peut être lourd
      // sur les téléphones lorsque l'enquête contient plusieurs photos.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final assemblyTimer = Stopwatch()..start();
      final pdfBytes = await pdf.save();
      assemblyTimer.stop();
      debugPrint(
        'Assemblage PDF : ${assemblyTimer.elapsed.inMilliseconds} ms, ${(pdfBytes.length / 1024).toStringAsFixed(1)} Ko',
      );
      if (pdfBytes.isEmpty) {
        throw Exception("Le PDF généré est vide.");
      }
      if (mounted) {
        setState(() => _progressMessage = "Écriture du fichier PDF...");
      }
      await file.writeAsBytes(pdfBytes, flush: true);
      if (!await file.exists() || await file.length() != pdfBytes.length) {
        throw Exception("La vérification du PDF enregistré a échoué.");
      }

      print("✅ PDF généré: $fileName");

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OptionsEnvoiPage(
            pdfFile: file,
            enqueteId: widget.pdfType == PdfType.enquete
                ? widget.enqueteId
                : null,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      debugPrint("❌ Erreur génération PDF: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Fonction pour créer un cadre photo
  pw.Widget _buildPhotoFrame(
    String title,
    pw.ImageProvider? image,
    double size,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Container(
          width: size,
          height: size,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey, width: 1),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: image != null
              ? pw.Image(image, fit: pw.BoxFit.cover)
              : pw.Center(
                  child: pw.Text(
                    'Aucune photo',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pdfType == PdfType.rapportMensuel
              ? 'Générer le rapport'
              : 'Générer le PDF',
        ),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/fond_inf.png', fit: BoxFit.cover),
          ),
          Container(color: Colors.black.withOpacity(0.2)),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (_loading) ...[
                  const CircularProgressIndicator(color: Colors.green),
                  const SizedBox(height: 20),
                  Text(
                    _progressMessage,
                    style: const TextStyle(color: Colors.white),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: _generatePdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'GÉNÉRER',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
