import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tableau_de_bord_page.dart';

class EnregistrementValidateurPage extends StatefulWidget {
  const EnregistrementValidateurPage({super.key});

  @override
  State<EnregistrementValidateurPage> createState() => _EnregistrementValidateurPageState();
}

class _EnregistrementValidateurPageState extends State<EnregistrementValidateurPage> {
  final TextEditingController nomController = TextEditingController();
  final TextEditingController prenomsController = TextEditingController();
  final TextEditingController contactController = TextEditingController();

  bool dejaEnregistre = false;

  @override
  void initState() {
    super.initState();
    chargerValidateur();
  }

  Future<void> chargerValidateur() async {
    final prefs = await SharedPreferences.getInstance();

    final nom = prefs.getString("VALIDATEUR_NOM");
    final prenoms = prefs.getString("VALIDATEUR_PRENOMS");
    final contact = prefs.getString("VALIDATEUR_CONTACT");

    if (nom != null || prenoms != null || contact != null) {
      setState(() {
        dejaEnregistre = true;
        nomController.text = nom ?? "";
        prenomsController.text = prenoms ?? "";
        contactController.text = contact ?? "";
      });
    }
  }

  @override
  void dispose() {
    nomController.dispose();
    prenomsController.dispose();
    contactController.dispose();
    super.dispose();
  }

  Future<void> enregistrerEtAllerAuTableauDeBord() async {
    final nom = nomController.text.trim();
    final prenoms = prenomsController.text.trim();
    final contact = contactController.text.trim();

    if (nom.isEmpty || prenoms.isEmpty || contact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs.")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("VALIDATEUR_NOM", nom);
    await prefs.setString("VALIDATEUR_PRENOMS", prenoms);
    await prefs.setString("VALIDATEUR_CONTACT", contact);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          dejaEnregistre
              ? "Informations du validateur mises à jour."
              : "Validateur enregistré avec succès.",
        ),
      ),
    );

    // ✅ ALLER AU TABLEAU DE BORD (vider la pile)
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const TableauDeBordPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Validateur"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  dejaEnregistre
                      ? "Modifier les informations du validateur"
                      : "Enregistrement du validateur",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: "Nom",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: prenomsController,
                  decoration: const InputDecoration(
                    labelText: "Prénoms",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: contactController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Contact",
                    border: OutlineInputBorder(),
                  ),
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: enregistrerEtAllerAuTableauDeBord,
                    icon: const Icon(Icons.save),
                    label: Text(
                      dejaEnregistre
                          ? "METTRE À JOUR ET ALLER AU TABLEAU DE BORD"
                          : "ENREGISTRER ET ALLER AU TABLEAU DE BORD",
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
