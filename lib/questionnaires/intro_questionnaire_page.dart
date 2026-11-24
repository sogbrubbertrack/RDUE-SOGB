import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'questionnaire_start_page.dart';

/// ===============================
/// 🔁 RESET POUR NOUVELLE FICHE
/// ===============================
Future<void> resetQuestionnairePourNouvelleFiche() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys();

  for (final k in keys) {
    if (
    // 🔁 QUESTIONNAIRES
    k.startsWith("DF_") ||
        k.startsWith("ENV_") ||
        k.startsWith("DT_") ||
        k.startsWith("MEN_") ||
        k.startsWith("TRAV_") ||

        // 🔁 SIGNATURES & PHOTOS
        k.startsWith("SIGNATURE_") ||
        k.startsWith("PHOTO_") ||

        // 🔁 CONFORMITÉ / ÉTAT FICHE
        k.startsWith("FICHE_")
    ) {
      await prefs.remove(k);
    }
  }

  // ⚠️ Autoriser le recomptage pour la nouvelle fiche
  await prefs.remove("FICHE_DEJA_COMPTEE");
}

/// ===============================
/// PAGE : INTRO QUESTIONNAIRE
/// ===============================
class IntroQuestionnairePage extends StatelessWidget {
  // AJOUT DES PARAMÈTRES
  final int enqueteId;
  final int producteurId;

  const IntroQuestionnairePage({
    super.key,
    required this.enqueteId,      // ← AJOUTÉ
    required this.producteurId,   // ← AJOUTÉ
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ===== IMAGE DE FOND =====
          Positioned.fill(
            child: Image.asset(
              "assets/images/fond_questionnaire.jpg",
              fit: BoxFit.cover,
            ),
          ),

          // ===== FILTRE SOMBRE =====
          Container(color: Colors.black.withOpacity(0.45)),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  Image.asset(
                    "assets/images/logo_sogb.jpg",
                    height: 110,
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "QUESTIONNAIRE RDUE SOGB",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "ENQUÊTE PRODUCTEUR",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "43 questions",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                  const Spacer(),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () async {
                        // 🔁 Nettoyer uniquement les réponses questionnaire
                        await resetQuestionnairePourNouvelleFiche();

                        if (context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QuestionnaireStartPage(
                                enqueteId: enqueteId,        // ← TRANSMETTRE LES IDs
                                producteurId: producteurId,  // ← TRANSMETTRE LES IDs
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text(
                        "COMMENCER",
                        style: TextStyle(fontSize: 18),
                      ),
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
}