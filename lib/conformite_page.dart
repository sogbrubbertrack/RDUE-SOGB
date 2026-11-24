import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PageConformite extends StatefulWidget {
  const PageConformite({super.key});

  @override
  State<PageConformite> createState() => _PageConformiteState();
}

class _PageConformiteState extends State<PageConformite> {
  bool? estConforme;
  String statutTexte = "";

  @override
  void initState() {
    super.initState();
    verifierConformite();
  }

  // =============================
  // OUTILS
  // =============================
  bool checkUnique(SharedPreferences prefs, String key, String valeur) {
    return prefs.getString(key) == valeur;
  }

  bool checkMultipleExact(SharedPreferences prefs, String prefix, List<String> valeursAttendues) {
    const toutes = ["A","B","C","D","E","F","G","H","I","J","K","L"];

    for (final k in valeursAttendues) {
      if ((prefs.getBool("${prefix}_$k") ?? false) != true) {
        return false;
      }
    }

    for (final k in toutes) {
      if (!valeursAttendues.contains(k)) {
        if ((prefs.getBool("${prefix}_$k") ?? false) == true) {
          return false;
        }
      }
    }

    return true;
  }

  // =============================
  // LOGIQUE PRINCIPALE
  // =============================
  Future<void> verifierConformite() async {
    final prefs = await SharedPreferences.getInstance();

    bool estNonConforme = true;

    estNonConforme &= checkUnique(prefs, "DF_Q1_type_autorisation", "C");
    estNonConforme &= checkMultipleExact(prefs, "ENV_Q9", ["A","B","C"]);
    estNonConforme &= checkUnique(prefs, "DT_Q11_litiges_fonciers", "A");

    estNonConforme &= checkMultipleExact(prefs, "MEN_Q19", ["A","C","F","G","J","K"]);
    estNonConforme &= checkMultipleExact(prefs, "MEN_Q23", ["A","C","F","G","J","K"]);
    estNonConforme &= checkUnique(prefs, "MEN_Q24_heures_travail_13_15", "B");
    estNonConforme &= checkUnique(prefs, "MEN_Q27_moins_13_travaillent", "A");

    estNonConforme &= checkUnique(prefs, "TRAV_Q29_type_consentement", "C");
    estNonConforme &= checkMultipleExact(prefs, "TRAV_Q37", ["A","C","F","G","J","K"]);
    estNonConforme &= checkUnique(prefs, "TRAV_Q40_docs_identite_conserves", "A");

    final q41 = prefs.getString("TRAV_Q41_frais_obtention_travail");
    estNonConforme &= (q41 == "A" || q41 == "B" || q41 == "C");

    final conforme = !estNonConforme;

    final statut = conforme ? "CONFORME" : "NON CONFORME";

    // =============================
    // SAUVEGARDE POUR PDF
    // =============================
    await prefs.setBool("FICHE_CONFORME", conforme);
    await prefs.setString("FICHE_STATUT_TEXTE", statut);

    setState(() {
      estConforme = conforme;
      statutTexte = statut;
    });
  }

  // =============================
  // UI
  // =============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Résultat de conformité"),
        backgroundColor: Colors.green,
      ),
      body: estConforme == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              estConforme! ? Icons.verified : Icons.warning,
              size: 120,
              color: estConforme! ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              statutTexte,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: estConforme! ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
