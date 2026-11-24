import 'package:flutter/material.dart';

// Imports avec chemins relatifs
import 'droits_des_tiers/dt_q11_page.dart';
import 'droits_des_tiers/dt_q12_page.dart';
import 'droits_fonciers/df_q1_page.dart';
import 'droits_fonciers/df_q2_page.dart';
import 'droits_fonciers/df_q3_page.dart';
import 'droits_fonciers/df_q4_page.dart';
import 'droits_fonciers/df_q5_page.dart';
import 'droits_fonciers/df_q6_page.dart';
import 'droits_fonciers/df_q7_page.dart';
import 'droits_fonciers/df_q8_page.dart';
import 'environnement/env_q9_page.dart';
import 'environnement/env_q10_page.dart';
import 'menages/men_q13_page.dart';
import 'menages/men_q14_page.dart';
import 'menages/men_q15_page.dart';
import 'menages/men_q16_page.dart';
import 'menages/men_q17_page.dart';
import 'menages/men_q18_page.dart';
import 'menages/men_q19_page.dart';
import 'menages/men_q20_page.dart';
import 'menages/men_q21_page.dart';
import 'menages/men_q22_page.dart';
import 'menages/men_q23_page.dart';
import 'menages/men_q24_page.dart';
import 'menages/men_q25_page.dart';
import 'menages/men_q26_page.dart';
import 'menages/men_q27_page.dart';
import 'travailleurs/trav_q28_page.dart';
import 'travailleurs/trav_q29_page.dart';
import 'travailleurs/trav_q30_page.dart';
import 'travailleurs/trav_q31_page.dart';
import 'travailleurs/trav_q32_page.dart';
import 'travailleurs/trav_q33_page.dart';
import 'travailleurs/trav_q34_page.dart';
import 'travailleurs/trav_q35_page.dart';
import 'travailleurs/trav_q36_page.dart';
import 'travailleurs/trav_q37_page.dart';
import 'travailleurs/trav_q38_page.dart';
import 'travailleurs/trav_q39_page.dart';
import 'travailleurs/trav_q40_page.dart';
import 'travailleurs/trav_q41_page.dart';
import 'revenu_exploitant/rev_q42_page.dart';
import 'revenu_exploitant/rev_q43_page.dart';

class QuestionnaireStartPage extends StatefulWidget {
  // ✅ PARAMÈTRES OBLIGATOIRES - plus de dépendance à SharedPreferences
  final int enqueteId;
  final int producteurId;

  const QuestionnaireStartPage({
    super.key,
    required this.enqueteId,
    required this.producteurId,
  });

  @override
  State<QuestionnaireStartPage> createState() => _QuestionnaireStartPageState();
}

class _QuestionnaireStartPageState extends State<QuestionnaireStartPage> {
  // Simulons un état de progression
  final Map<String, List<bool>> _themeProgress = {
    'Droits Fonciers': List.filled(8, false),
    'Environnement': [false, false],
    'Droits des Tiers': [false, false],
    'Ménages': List.filled(15, false),
    'Travailleurs': List.filled(14, false),
    'Revenu Exploitant': [false, false],
  };

  final List<ThemeData> _themes = [
    ThemeData(
      name: 'Droits Fonciers',
      icon: Icons.landscape,
      color: Colors.green,
      questions: [
        QuestionData(
          title: 'Q1 - Autorisation terrain',
          pageBuilder: (enqueteId, producteurId) => DroitsFonciersQ1Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q2 - Type documentation',
          pageBuilder: (enqueteId, producteurId) => DroitsFonciersQ2Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q3 - Numéro référence',
          pageBuilder: (enqueteId, producteurId) => DroitsFonciersQ3Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q4 - Image documentation',
          pageBuilder: (enqueteId, producteurId) => DroitsFonciersQ4Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q5 - Reconnaissance terrain',
          pageBuilder: (enqueteId, producteurId) => DroitsFonciersQ5Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q6 - Image reconnaissance',
          pageBuilder: (enqueteId, producteurId) => DroitsFonciersQ6Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q7 - Année plantation',
          pageBuilder: (enqueteId, producteurId) => DroitsFonciersQ7Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q8 - Précision utilisation',
          pageBuilder: (enqueteId, producteurId) => DroitsFonciersQ8Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
      ],
    ),
    ThemeData(
      name: 'Environnement',
      icon: Icons.eco,
      color: Colors.teal,
      questions: [
        QuestionData(
          title: 'Q9 - Produits chimiques',
          pageBuilder: (enqueteId, producteurId) => EnvironnementQ9Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q10 - Liste autorisée',
          pageBuilder: (enqueteId, producteurId) => EnvironnementQ10Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
      ],
    ),
    ThemeData(
      name: 'Droits des Tiers',
      icon: Icons.people,
      color: Colors.blue,
      questions: [
        QuestionData(
          title: 'Q11 - Litiges fonciers',
          pageBuilder: (enqueteId, producteurId) => DroitsDesTiersQ11Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q12 - Détails litige',
          pageBuilder: (enqueteId, producteurId) => DroitsDesTiersQ12Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
      ],
    ),
    ThemeData(
      name: 'Ménages',
      icon: Icons.home,
      color: Colors.orange,
      questions: [
        QuestionData(
          title: 'Q13 - Autres membres',
          pageBuilder: (enqueteId, producteurId) => MenQ13Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q14 - Membres +18 ans',
          pageBuilder: (enqueteId, producteurId) => MenQ14Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q15 - Nombre +18 ans',
          pageBuilder: (enqueteId, producteurId) => MenQ15Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q16 - Membres 16-17 ans',
          pageBuilder: (enqueteId, producteurId) => MenQ16Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q17 - Nombre 16-17 ans',
          pageBuilder: (enqueteId, producteurId) => MenQ17Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q18 - 16-17 ans travaillent',
          pageBuilder: (enqueteId, producteurId) => MenQ18Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q19 - Activités 16-17 ans',
          pageBuilder: (enqueteId, producteurId) => MenQ19Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q20 - Membres 13-15 ans',
          pageBuilder: (enqueteId, producteurId) => MenQ20Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q21 - Nombre 13-15 ans',
          pageBuilder: (enqueteId, producteurId) => MenQ21Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q22 - 13-15 ans travaillent',
          pageBuilder: (enqueteId, producteurId) => MenQ22Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q23 - Activités 13-15 ans',
          pageBuilder: (enqueteId, producteurId) => MenQ23Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q24 - Heures travail 13-15',
          pageBuilder: (enqueteId, producteurId) => MenQ24Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q25 - Membres -13 ans',
          pageBuilder: (enqueteId, producteurId) => MenQ25Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q26 - Nombre -13 ans',
          pageBuilder: (enqueteId, producteurId) => MenQ26Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q27 - -13 ans travaillent',
          pageBuilder: (enqueteId, producteurId) => MenQ27Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
      ],
    ),
    ThemeData(
      name: 'Travailleurs',
      icon: Icons.work,
      color: Colors.purple,
      questions: [
        QuestionData(
          title: 'Q28 - Présence travailleurs',
          pageBuilder: (enqueteId, producteurId) => TravQ28Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q29 - Type consentement',
          pageBuilder: (enqueteId, producteurId) => TravQ29Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q30 - Calcul salaire',
          pageBuilder: (enqueteId, producteurId) => TravQ30Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q31 - Revenu mensuel',
          pageBuilder: (enqueteId, producteurId) => TravQ31Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q32 - Temps travail hebdo',
          pageBuilder: (enqueteId, producteurId) => TravQ32Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q33 - Travailleurs +18 ans',
          pageBuilder: (enqueteId, producteurId) => TravQ33Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q34 - Nombre +18 ans',
          pageBuilder: (enqueteId, producteurId) => TravQ34Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q35 - Travailleurs 16-17 ans',
          pageBuilder: (enqueteId, producteurId) => TravQ35Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q36 - Nombre 16-17 ans',
          pageBuilder: (enqueteId, producteurId) => TravQ36Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q37 - Activités 16-17 ans',
          pageBuilder: (enqueteId, producteurId) => TravQ37Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q38 - Travailleurs -16 ans',
          pageBuilder: (enqueteId, producteurId) => TravQ38Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q39 - Travailleurs étrangers',
          pageBuilder: (enqueteId, producteurId) => TravQ39Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q40 - Documents identité',
          pageBuilder: (enqueteId, producteurId) => TravQ40Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q41 - Frais travail',
          pageBuilder: (enqueteId, producteurId) => TravQ41Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
      ],
    ),
    ThemeData(
      name: 'Revenu Exploitant',
      icon: Icons.monetization_on,
      color: Colors.amber,
      questions: [
        QuestionData(
          title: 'Q42 - Revenu mensuel fermier',
          pageBuilder: (enqueteId, producteurId) => RevQ42Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
        QuestionData(
          title: 'Q43 - % revenu caoutchouc',
          pageBuilder: (enqueteId, producteurId) => RevQ43Page(
            enqueteId: enqueteId,
            producteurId: producteurId,
          ),
        ),
      ],
    ),
  ];

  bool _isThemeCompleted(String themeName) {
    final progress = _themeProgress[themeName];
    if (progress == null) return false;
    return progress.every((answered) => answered);
  }

  int _getCompletedCount(String themeName) {
    final progress = _themeProgress[themeName];
    if (progress == null) return 0;
    return progress.where((answered) => answered).length;
  }

  // ✅ MÉTHODE SIMPLIFIÉE - Plus de SharedPreferences
  Future<void> _commencerQuestionnaire() async {
    final enqueteId = widget.enqueteId;
    final producteurId = widget.producteurId;

    // Vérification simple
    if (enqueteId <= 0 || producteurId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur: Informations manquantes pour commencer"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigation directe vers Q1
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DroitsFonciersQ1Page(
          enqueteId: enqueteId,
          producteurId: producteurId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalQuestions = _themes.fold(0, (sum, theme) => sum + theme.questions.length);
    final totalCompleted = _themeProgress.values.fold(
        0,
            (sum, progress) => sum + progress.where((a) => a).length
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Questionnaire'),
        backgroundColor: Colors.green,
        elevation: 2,
      ),
      body: Stack(
        children: [
          // Image de fond
          Positioned.fill(
            child: Image.asset(
              "assets/images/fond_questionnaire.jpg",
              fit: BoxFit.cover,
            ),
          ),

          // Filtre sombre
          Container(color: Colors.black.withOpacity(0.4)),

          // Contenu
          SafeArea(
            child: Column(
              children: [
                // Logo SOGB
                Container(
                  margin: const EdgeInsets.only(top: 30, bottom: 20),
                  child: Image.asset(
                    "assets/images/logo_sogb.jpg",
                    height: 100,
                  ),
                ),

                const SizedBox(height: 20),

                // Bouton COMMENCER
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton(
                    onPressed: _commencerQuestionnaire,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      "COMMENCER",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Texte informatif
                const Text(
                  "43 questions • 6 thèmes",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 10),

                // Barre de progression globale
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progression',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$totalCompleted/$totalQuestions',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: totalQuestions > 0 ? totalCompleted / totalQuestions : 0,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Pied de page
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "SOGB - Enquête producteur",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Modèles de données
class ThemeData {
  final String name;
  final IconData icon;
  final Color color;
  final List<QuestionData> questions;

  ThemeData({
    required this.name,
    required this.icon,
    required this.color,
    required this.questions,
  });
}

class QuestionData {
  final String title;
  final Widget Function(int enqueteId, int producteurId) pageBuilder;

  QuestionData({required this.title, required this.pageBuilder});
}