import 'package:flutter/material.dart';
import 'package:rubberway/data/database_helper.dart';
import 'trav_q38_page.dart';

class TravQ37Page extends StatefulWidget {
  final int enqueteId;
  final int producteurId;

  const TravQ37Page({
    super.key,
    required this.enqueteId,
    required this.producteurId,
  });

  @override
  State<TravQ37Page> createState() => _TravQ37PageState();
}

class _TravQ37PageState extends State<TravQ37Page> {
  final Map<String, bool> _selections = {
    "A": false,
    "B": false,
    "C": false,
    "D": false,
    "E": false,
    "F": false,
    "G": false,
    "H": false,
    "I": false,
    "J": false,
    "K": false,
    "L": false,
  };

  final TextEditingController _autreController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _autreController.dispose();
    super.dispose();
  }

  Future<void> _continuer() async {
    if (!_selections.values.any((v) => v)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sélectionnez au moins une activité"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selections["L"] == true && _autreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Précisez l'activité"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      List<String> selectedCodes = [];
      _selections.forEach((code, selected) {
        if (selected) selectedCodes.add(code);
      });
      String codesString = selectedCodes.join(',');

      int reponseId = await DatabaseHelper.saveReponse(
        enqueteId: widget.enqueteId,
        questionId: '37',
        codeReponse: codesString,
        valeur: codesString,
        precision: _selections["L"] == true ? _autreController.text.trim() : null,
      );

      debugPrint('✅ Réponse Q37 sauvegardée (ID: $reponseId)');

      // ✅ CORRECTION: push au lieu de pushReplacement
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TravQ38Page(
            enqueteId: widget.enqueteId,
            producteurId: widget.producteurId,
          ),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur : $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Travailleurs"),
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/fond_questionnaire.jpg",
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withOpacity(0.2)),
          SafeArea(
            // ✅ SingleChildScrollView pour les longues listes
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Indicateur de progression
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Question 37/43",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Question
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Pour les travailleurs âgés de 16 à 17 ans, à quel type de tâches participent-ils ? (plusieurs options possibles)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Liste des activités
                  _buildCheckboxCard("A", "Effectuer la saignée"),
                  _buildCheckboxCard("B", "Collecte du latex dans les tasses"),
                  _buildCheckboxCard("C", "Faire le rabattage"),
                  _buildCheckboxCard("D", "Ramasser les graines"),
                  _buildCheckboxCard("E", "Semer les graines"),
                  _buildCheckboxCard("F", "Effectuer la Trouaison"),
                  _buildCheckboxCard("G", "Pulvérisation de produits chimiques(herbicides,ect.)"),
                  _buildCheckboxCard("H", "Aider au piquetage"),
                  _buildCheckboxCard("I", "Couvrir le caoutchouc stocké avec des bâches"),
                  _buildCheckboxCard("J", "Défrichage"),
                  _buildCheckboxCard("K", "Brûlage des parcelles "),
                  _buildCheckboxCard("L", "Autres(à préciser dans les remarques"),

                  // Champ de précision si "Autres"
                  if (_selections["L"] == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _autreController,
                        decoration: const InputDecoration(
                          labelText: "Précisez",
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_isSaving,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Bouton CONTINUER
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _continuer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text(
                        "CONTINUER",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxCard(String code, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _selections[code]! ? Colors.green : Colors.grey.shade300,
          width: _selections[code]! ? 1.5 : 0.5,
        ),
      ),
      child: CheckboxListTile(
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: _selections[code]! ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        value: _selections[code],
        activeColor: Colors.green,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        onChanged: _isSaving
            ? null
            : (bool? value) {
          setState(() {
            _selections[code] = value ?? false;
          });
        },
      ),
    );
  }
}