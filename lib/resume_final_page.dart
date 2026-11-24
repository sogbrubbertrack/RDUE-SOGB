import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'generer_pdf_page.dart';
import 'pdf_type.dart';
import 'data/database_helper.dart';

// import 'rapport_non_conformite_page.dart'; // À créer ultérieurement

class ResumeFinalPage extends StatefulWidget {
  final int enqueteId;
  final int producteurId;

  const ResumeFinalPage({
    super.key,
    required this.enqueteId,
    required this.producteurId,
  });

  @override
  State<ResumeFinalPage> createState() => _ResumeFinalPageState();
}

class _ResumeFinalPageState extends State<ResumeFinalPage> {
  bool _isGenerating = false;
  bool _isLoading = true;
  Map<String, dynamic>? _infosEnquete;
  Map<String, List<Map<String, dynamic>>> _reponses = {};
  Map<String, dynamic>? _statistiques;

  // ✅ Historique des enquêtes du producteur

  // Couleurs professionnelles
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color accentOrange = Color(0xFFFF6F00);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color greyBackground = Color(0xFFF5F5F5);

  // Mapping des libellés de questions
  static const Map<String, String> questionsLabels = {
    '1': "Type d'autorisation pour utiliser le terrain",
    '2': "Type de documentation",
    '3': "Numéro de référence de la documentation",
    '4': "Image de la documentation",
    '5': "Comment l'utilisation du terrain est-elle reconnue",
    '6': "Image de reconnaissance",
    '7': "Année d'établissement de la plantation",
    '8': "Précision sur la reconnaissance",
    '9': "Produits chimiques utilisés",
    '10': "Connaissance de la liste des produits autorisés",
    '11': "Litiges fonciers",
    '12': "Précisions sur le litige",
    '13': "Autres membres du ménage",
    '14': "Membres > 18 ans",
    '15': "Nombre de membres > 18 ans",
    '16': "Membres 16-17 ans",
    '17': "Nombre de membres 16-17 ans",
    '18': "Travail des 16-17 ans",
    '19': "Activités des 16-17 ans",
    '20': "Membres 13-15 ans",
    '21': "Nombre de membres 13-15 ans",
    '22': "Travail des 13-15 ans",
    '23': "Activités des 13-15 ans",
    '24': "Heures de travail des 13-15 ans",
    '25': "Membres < 13 ans",
    '26': "Nombre de membres < 13 ans",
    '27': "Travail des < 13 ans",
    '28': "Travailleurs dans l'exploitation",
    '29': "Type de consentement",
    '30': "Mode de calcul du salaire",
    '31': "Revenu mensuel des travailleurs",
    '32': "Temps de travail hebdomadaire",
    '33': "Travailleurs > 18 ans",
    '34': "Nombre de travailleurs > 18 ans",
    '35': "Travailleurs 16-17 ans",
    '36': "Nombre de travailleurs 16-17 ans",
    '37': "Activités des 13-15 ans (travailleurs)",
    '38': "Travailleurs < 16 ans",
    '39': "Travailleurs étrangers",
    '40': "Conservation des documents étrangers",
    '41': "Frais exigés aux étrangers",
    '42': "Revenu mensuel du fermier",
    '43': "Pourcentage revenu caoutchouc",
  };

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _isLoading = true);

    try {
      // Charger les informations de l'enquête
      final infos = await DatabaseHelper.getInfosEnquete(widget.enqueteId);

      // Charger toutes les réponses
      final reps = await DatabaseHelper.getReponsesByEnquete(widget.enqueteId);

      // Organiser les réponses par question
      final Map<String, List<Map<String, dynamic>>> reponsesMap = {};
      for (final r in reps) {
        final q = r['question_id'];
        reponsesMap.putIfAbsent(q, () => []).add(r);
      }

      // ✅ Charger l'historique des enquêtes du producteur

      // Calculer les statistiques
      final stats = await _calculerStatistiques(reponsesMap);

      // ✅ Comparer avec l'enquête précédente si elle existe

      if (mounted) {
        setState(() {
          _infosEnquete = infos;
          _reponses = reponsesMap;
          _statistiques = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement données: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ Charger l'historique des enquêtes du producteur
  String _formatReponseAvecLibelle(String questionId, String code) {
    if (code.isEmpty) return '—';
    if (code == 'A') return 'OUI';
    if (code == 'B') return 'NON';
    if (code == 'C') return 'NON CONFORME';
    if (code == 'D') return 'AUTRE';
    if (code == 'Z') return 'NON';
    return code;
  }

  Future<Map<String, dynamic>> _calculerStatistiques(
    Map<String, List<Map<String, dynamic>>> reponses,
  ) async {
    int totalQuestions = 43;
    int questionsRepondues = reponses.length;

    // Calculer le temps approximatif
    String tempsTotal = '—';
    try {
      final toutesReponses = reponses.values.expand((e) => e).toList();
      if (toutesReponses.isNotEmpty) {
        toutesReponses.sort(
          (a, b) => a['date_reponse'].compareTo(b['date_reponse']),
        );
        final debut = DateTime.parse(toutesReponses.first['date_reponse']);
        final fin = DateTime.parse(toutesReponses.last['date_reponse']);
        final duree = fin.difference(debut);

        if (duree.inHours > 0) {
          tempsTotal = '${duree.inHours}h ${duree.inMinutes % 60}min';
        } else if (duree.inMinutes > 0) {
          tempsTotal = '${duree.inMinutes}min ${duree.inSeconds % 60}s';
        } else {
          tempsTotal = '${duree.inSeconds}s';
        }
      }
    } catch (e) {
      debugPrint('Erreur calcul temps: $e');
    }

    // Compter les photos
    int photosPrises = 0;
    final photos = await DatabaseHelper.getAllPhotosForEnquete(
      widget.enqueteId,
    );
    photosPrises = photos.length;

    // ✅ Récupérer les signatures depuis la base de données (Map explicite)
    final Map<String, String> signatures =
        await DatabaseHelper.getAllSignaturesForEnquete(widget.enqueteId);

    final prefs = await SharedPreferences.getInstance();
    final profileSignaturePath = prefs.getString('agent_signature_path');
    final hasProfileSignature =
        profileSignaturePath != null &&
        await File(profileSignaturePath).exists();
    final hasAgentSignature =
        signatures.containsKey(DatabaseHelper.SIGNATURE_AGENT) ||
        hasProfileSignature;
    bool hasPlanteurSignature = signatures.containsKey(
      DatabaseHelper.SIGNATURE_PLANTEUR,
    );
    final signatureCount =
        (hasAgentSignature ? 1 : 0) + (hasPlanteurSignature ? 1 : 0);

    return {
      'questions_repondues': questionsRepondues,
      'total_questions': totalQuestions,
      'taux_completion': (questionsRepondues / totalQuestions * 100)
          .toStringAsFixed(1),
      'temps_total': tempsTotal,
      'photos_prises': photosPrises,
      'signatures': signatureCount,
      'has_agent_signature': hasAgentSignature,
      'has_planteur_signature': hasPlanteurSignature,
    };
  }

  // ==================== FONCTIONS D'EXTRACTION ====================

  String _getCode(String questionId) {
    return _reponses[questionId]?.first['code_reponse']?.toString() ?? '';
  }

  String _getValeur(String questionId) {
    return _reponses[questionId]?.first['valeur']?.toString() ?? '';
  }

  List<String> _getCodesMulti(String questionId) {
    final list = _reponses[questionId];
    if (list == null || list.isEmpty) return [];
    final raw = list.first['code_reponse']?.toString() ?? '';
    if (raw.isEmpty) return [];
    return raw.split(',').map((e) => e.trim()).toList();
  }

  String _getPrecision(String questionId) {
    return _reponses[questionId]?.first['precision_text']?.toString() ?? '';
  }

  // ✅ Liste des points de non-conformité
  List<Map<String, String>> _getPointsNonConformite() {
    List<Map<String, String>> points = [];

    if (_getCode('1') == 'C') {
      points.add({
        'question': 'Utilisation du terrain',
        'detail': 'Utilisation non autorisée du terrain',
        'type': 'danger',
        'formation': 'Droits fonciers et procédures légales',
      });
    }

    final produitsChimiques = _getCodesMulti('9');
    if (produitsChimiques.contains('A') || produitsChimiques.contains('C')) {
      points.add({
        'question': 'Produits chimiques',
        'detail': 'Utilisation de produits interdits',
        'type': 'danger',
        'formation': 'Gestion des produits phytosanitaires',
      });
    }

    if (_getCode('11') == 'A') {
      points.add({
        'question': 'Litiges fonciers',
        'detail': 'Présence de litiges fonciers non résolus',
        'type': 'warning',
        'formation': 'Médiation et résolution de conflits',
      });
    }

    const activitesDangereuses = ['A', 'C', 'F', 'G', 'J', 'K'];
    final mineursConcerned = ['19', '23', '37'].any(
      (questionId) =>
          _getCodesMulti(questionId).any(activitesDangereuses.contains),
    );
    if (mineursConcerned) {
      points.add({
        'question': 'Travail des enfants',
        'detail': 'Activité dangereuse déclarée pour des mineurs',
        'type': 'danger',
        'formation': 'Santé et sécurité au travail',
      });
    }
    if (_getCode('24') == 'B') {
      points.add({
        'question': 'Temps de travail',
        'detail': 'Durée de travail excessive pour les 13-15 ans',
        'type': 'warning',
        'formation': 'Droit du travail et temps de repos',
      });
    }

    if (_getCode('27') == 'A') {
      points.add({
        'question': 'Travail des enfants',
        'detail': 'Enfants de moins de 13 ans travaillant',
        'type': 'danger',
        'formation': 'Lutte contre le travail des enfants',
      });
    }

    if (_getCode('29') == 'C') {
      points.add({
        'question': 'Consentement des travailleurs',
        'detail': 'Absence de consentement',
        'type': 'danger',
        'formation': 'Droits des travailleurs',
      });
    }

    if (_getCode('40') == 'A') {
      points.add({
        'question': 'Documents travailleurs',
        'detail': 'Conservation des documents d\'identité',
        'type': 'warning',
        'formation': 'Gestion administrative du personnel',
      });
    }

    if (['A', 'B', 'C'].contains(_getCode('41'))) {
      points.add({
        'question': 'Frais de recrutement',
        'detail': 'Des frais sont exigés aux travailleurs étrangers',
        'type': 'warning',
        'formation': 'Droits des travailleurs étrangers',
      });
    }
    return points;
  }

  bool _estNonConforme() {
    return _getPointsNonConformite().isNotEmpty;
  }

  String _formatReponse(String questionId) {
    final code = _getCode(questionId);
    if (code.isEmpty) return '—';
    return _formatReponseAvecLibelle(questionId, code);
  }

  String _getLibelleOption(String questionId, String code) {
    // Mapping des libellés d'options
    const Map<String, Map<String, String>> options = {
      '1': {
        'A': 'Documentation',
        'B': 'Reconnue sans doc',
        'C': 'Non autorisée',
      },
      '2': {
        'A': 'Certificat',
        'B': 'Attestation',
        'C': 'Contrat',
        'D': 'Autre',
      },
      '5': {'A': 'Démarcation', 'B': 'Longue durée', 'C': 'Autre'},
      '9': {'A': 'Paraquat', 'B': 'Glyphosate', 'C': '2-4D', 'D': 'Autre'},
      '19': {
        'A': 'Saignée',
        'B': 'Collecte',
        'C': 'Rabattage',
        'D': 'Ramassage',
        'E': 'Semis',
        'F': 'Trouaison',
        'G': 'Pulvérisation',
        'H': 'Piquetage',
        'I': 'Bâches',
        'J': 'Défrichage',
        'K': 'Brûlage',
        'L': 'Autre',
      },
      '23': {
        'A': 'Saignée',
        'B': 'Collecte',
        'C': 'Rabattage',
        'D': 'Ramassage',
        'E': 'Semis',
        'F': 'Trouaison',
        'G': 'Pulvérisation',
        'H': 'Piquetage',
        'I': 'Bâches',
        'J': 'Défrichage',
        'K': 'Brûlage',
        'L': 'Autre',
      },
      '37': {
        'A': 'Saignée',
        'B': 'Collecte',
        'C': 'Rabattage',
        'D': 'Ramassage',
        'E': 'Semis',
        'F': 'Trouaison',
        'G': 'Pulvérisation',
        'H': 'Piquetage',
        'I': 'Bâches',
        'J': 'Défrichage',
        'K': 'Brûlage',
        'L': 'Autre',
      },
    };

    return options[questionId]?[code] ?? code;
  }

  // ==================== WIDGETS DE RÉSUMÉ ====================

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Widget pour afficher l'historique et les comparaisons
  Widget _buildAnswerSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> answers,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 21),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text('${answers.length} réponses'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          children: answers,
        ),
      ),
    );
  }

  Widget _buildComplianceBanner(bool nonConforme) {
    final color = nonConforme ? accentRed : primaryGreen;
    final background = nonConforme ? const Color(0xFFFFEBEE) : lightGreen;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(
            nonConforme ? Icons.warning_rounded : Icons.verified_rounded,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nonConforme ? 'Enquête non conforme' : 'Enquête conforme',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  nonConforme
                      ? 'Les critères à corriger sont détaillés ci-dessous.'
                      : 'Aucun critère de non-conformité détecté.',
                  style: TextStyle(color: color.withOpacity(0.9), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsNonConformite() {
    final points = _getPointsNonConformite();

    if (points.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentRed, width: 1),
        boxShadow: [
          BoxShadow(
            color: accentRed.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: accentRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'POINTS DE NON-CONFORMITÉ (${points.length})',
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: accentRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    point['type'] == 'danger' ? Icons.error : Icons.warning,
                    size: 16,
                    color: point['type'] == 'danger' ? accentRed : accentOrange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point['question'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          point['detail'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Text(
                          'Formation: ${point['formation'] ?? ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: primaryGreen,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReponseCard(String questionId) {
    final label = questionsLabels[questionId] ?? 'Question $questionId';
    final code = _getCode(questionId);
    final valeur = _getValeur(questionId);
    final codesMulti = _getCodesMulti(questionId);
    final precision = _getPrecision(questionId);

    // Déterminer si c'est une réponse à risque
    bool isRisque = false;
    if (questionId == '1' && code == 'C') isRisque = true;
    if (questionId == '9' &&
        (codesMulti.contains('A') ||
            codesMulti.contains('B') ||
            codesMulti.contains('C')))
      isRisque = true;
    if (questionId == '11' && code == 'A') isRisque = true;
    if (questionId == '24' && code == 'B') isRisque = true;
    if (questionId == '27' && code == 'A') isRisque = true;
    if (questionId == '29' && code == 'C') isRisque = true;
    if (questionId == '40' && code == 'A') isRisque = true;

    // Questions avec valeur textuelle
    if ([
      '3',
      '7',
      '8',
      '12',
      '15',
      '17',
      '21',
      '26',
      '31',
      '32',
      '34',
      '36',
      '42',
      '43',
    ].contains(questionId)) {
      return _buildReponseTexte(label, valeur);
    }

    // Questions multi
    if (['9', '19', '23', '37'].contains(questionId)) {
      return _buildReponseMulti(label, codesMulti, precision: precision);
    }

    // Questions binaires
    return _buildReponseBinaire(
      label,
      _formatReponse(questionId),
      isWarning: isRisque,
    );
  }

  Widget _buildReponseBinaire(
    String question,
    String reponse, {
    bool isWarning = false,
  }) {
    final Color color = isWarning ? accentRed : primaryGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isWarning ? Border.all(color: accentRed, width: 1) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isWarning) Icon(Icons.warning, size: 18, color: accentRed),
          if (isWarning) const SizedBox(width: 8),
          Expanded(
            child: Text(
              question,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isWarning ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              reponse,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReponseTexte(String question, String valeur) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              valeur.isEmpty ? 'Non renseigné' : valeur,
              style: TextStyle(
                fontSize: 14,
                color: valeur.isEmpty ? Colors.grey.shade500 : Colors.black87,
                fontStyle: valeur.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReponseMulti(
    String question,
    List<String> codes, {
    String? precision,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          if (codes.isEmpty)
            Text(
              'Aucune sélection',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: codes
                  .map(
                    (code) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: lightGreen,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _getLibelleOption(question, code),
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryGreen,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (precision != null && precision.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentOrange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: accentOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      precision,
                      style: TextStyle(fontSize: 12, color: accentOrange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nonConforme = _estNonConforme();

    return Scaffold(
      backgroundColor: greyBackground,
      appBar: AppBar(
        title: const Text(
          'Résumé final',
          style: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
        ),
        backgroundColor: nonConforme ? accentRed : primaryGreen,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && nonConforme)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning, size: 16, color: accentRed),
                  SizedBox(width: 4),
                  Text(
                    'NON CONFORME',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accentRed,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ Carte d'en-tête avec infos producteur
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [primaryGreen, primaryGreen.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: primaryGreen.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _infosEnquete?['nom_producteur'] ??
                                          'Producteur',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      'Code: ${_infosEnquete?['code_producteur'] ?? '—'}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white30),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _infosEnquete?['village'] ?? '—',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.phone,
                                size: 16,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _infosEnquete?['contact'] ?? '—',
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ Statistiques
                    _buildComplianceBanner(nonConforme),

                    if (_statistiques != null) ...[
                      _buildSectionHeader(
                        'STATISTIQUES',
                        Icons.assessment,
                        accentOrange,
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.2,
                        children: [
                          _buildStatCard(
                            'Réponses',
                            '${_statistiques!['questions_repondues']}/${_statistiques!['total_questions']}',
                            Icons.checklist,
                            accentOrange,
                          ),
                          _buildStatCard(
                            'Temps',
                            _statistiques!['temps_total'],
                            Icons.timer,
                            primaryGreen,
                          ),
                          _buildStatCard(
                            'Photos',
                            '${_statistiques!['photos_prises']}',
                            Icons.photo_camera,
                            Colors.blue,
                          ),
                          _buildStatCard(
                            'Signatures',
                            '${_statistiques!['signatures']}/2',
                            Icons.draw,
                            Colors.purple,
                          ),
                        ],
                      ),

                      // ✅ Indicateur des signatures (optionnel)
                      if (_statistiques!['signatures'] < 2)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accentOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: accentOrange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: accentOrange,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Signatures manquantes',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _statistiques!['has_agent_signature'] ==
                                                  false &&
                                              _statistiques!['has_planteur_signature'] ==
                                                  false
                                          ? 'Agent et planteur'
                                          : _statistiques!['has_agent_signature'] ==
                                                false
                                          ? 'Agent'
                                          : 'Planteur',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: accentOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],

                    const SizedBox(height: 20),

                    // ✅ Historique et comparaisons
                    const SizedBox(height: 20),

                    // ✅ Points de non-conformité (si non conforme)
                    if (nonConforme) _buildPointsNonConformite(),

                    // ✅ RÉSUMÉ DES RÉPONSES
                    _buildAnswerSection(
                      title: 'Droits fonciers',
                      icon: Icons.landscape,
                      color: primaryGreen,
                      answers: [
                        _buildReponseCard('1'),
                        if (_getCode('1') == 'A') ...[
                          _buildReponseCard('2'),
                          if (_getCode('2') == 'D') _buildReponseCard('3'),
                          _buildReponseCard('4'),
                        ],
                        if (_getCode('1') == 'B') ...[
                          _buildReponseCard('5'),
                          if (_getCode('5') == 'B') _buildReponseCard('7'),
                          if (_getCode('5') == 'C') _buildReponseCard('8'),
                          _buildReponseCard('6'),
                        ],
                      ],
                    ),
                    _buildAnswerSection(
                      title: 'Environnement',
                      icon: Icons.eco,
                      color: Colors.green,
                      answers: [
                        _buildReponseCard('9'),
                        _buildReponseCard('10'),
                      ],
                    ),
                    _buildAnswerSection(
                      title: 'Droits des tiers',
                      icon: Icons.gavel,
                      color: Colors.deepPurple,
                      answers: [
                        _buildReponseCard('11'),
                        if (_getCode('11') == 'A') _buildReponseCard('12'),
                      ],
                    ),
                    _buildAnswerSection(
                      title: 'Ménages',
                      icon: Icons.family_restroom,
                      color: Colors.teal,
                      answers: [
                        _buildReponseCard('13'),
                        if (_getCode('13') == 'A') ...[
                          _buildReponseCard('14'),
                          if (_getCode('14') == 'A') _buildReponseCard('15'),
                          _buildReponseCard('16'),
                          if (_getCode('16') == 'B') ...[
                            _buildReponseCard('17'),
                            _buildReponseCard('18'),
                            if (_getCode('18') == 'A') _buildReponseCard('19'),
                          ],
                          _buildReponseCard('20'),
                          if (_getCode('20') == 'C') ...[
                            _buildReponseCard('21'),
                            _buildReponseCard('22'),
                            if (_getCode('22') == 'A') _buildReponseCard('23'),
                            _buildReponseCard('24'),
                          ],
                          _buildReponseCard('25'),
                          if (_getCode('25') == 'D') ...[
                            _buildReponseCard('26'),
                            _buildReponseCard('27'),
                          ],
                        ],
                      ],
                    ),
                    _buildAnswerSection(
                      title: 'Travailleurs',
                      icon: Icons.people,
                      color: Colors.blue,
                      answers: [
                        _buildReponseCard('28'),
                        if (_getCode('28') == 'A') ...[
                          _buildReponseCard('29'),
                          _buildReponseCard('30'),
                          _buildReponseCard('31'),
                          _buildReponseCard('32'),
                          _buildReponseCard('33'),
                          if (_getCode('33') == 'A') _buildReponseCard('34'),
                          _buildReponseCard('35'),
                          if (_getCode('35') == 'B') ...[
                            _buildReponseCard('36'),
                            _buildReponseCard('37'),
                          ],
                          _buildReponseCard('38'),
                          _buildReponseCard('39'),
                          if (_getCode('39') == 'A') ...[
                            _buildReponseCard('40'),
                            _buildReponseCard('41'),
                          ],
                        ],
                      ],
                    ),
                    _buildAnswerSection(
                      title: 'Revenu',
                      icon: Icons.monetization_on,
                      color: Colors.amber.shade800,
                      answers: [
                        _buildReponseCard('42'),
                        _buildReponseCard('43'),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Document confidentiel - RubberWay',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _genererPdf,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _isGenerating ? 'Génération du PDF...' : 'Générer le PDF',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ✅ Fonction pour générer le PDF
  Future<void> _genererPdf() async {
    setState(() => _isGenerating = true);

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GenererPdfPage(
            enqueteId: widget.enqueteId,
            producteurId: widget.producteurId,
            pdfType: PdfType.enquete,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }
}
