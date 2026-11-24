import 'package:flutter/material.dart';
import 'package:rubberway/data/database_helper.dart';
import 'env_q10_page.dart';

class EnvironnementQ9Page extends StatefulWidget {
  final int enqueteId;
  final int producteurId;

  const EnvironnementQ9Page({
    super.key,
    required this.enqueteId,
    required this.producteurId,
  });

  @override
  State<EnvironnementQ9Page> createState() => _EnvironnementQ9PageState();
}

class _EnvironnementQ9PageState extends State<EnvironnementQ9Page> {
  final Map<String, bool> _selections = {
    "A": false,
    "B": false,
    "C": false,
    "D": false,
  };
  final TextEditingController _autresController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _autresController.dispose();
    super.dispose();
  }

  Future<void> _continuer() async {
    if (!_selections.values.any((v) => v)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sélectionnez au moins une option"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selections["D"] == true && _autresController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Précisez le produit"),
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
        questionId: '9',
        codeReponse: codesString,
        valeur: codesString,
        precision: _selections["D"] == true ? _autresController.text.trim() : null,
      );

      debugPrint('✅ Réponse Q9 sauvegardée (ID: $reponseId)');

      // ✅ CORRECTION: push au lieu de pushReplacement
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EnvironnementQ10Page(
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
        title: const Text("Environnement"),
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
                        "Question 9/43",
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
                      "Parmi les Produits chimiques suivants, lesquels sont utilisés sur le terrain (plusieurs options possibles)?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Options (cases à cocher)
                  _buildCheckboxCard("A", "Paraquat"),
                  const SizedBox(height: 12),
                  _buildCheckboxCard("B", "Glyphosate (Roundup)"),
                  const SizedBox(height: 12),
                  _buildCheckboxCard("C", "2-4D"),
                  const SizedBox(height: 12),
                  _buildCheckboxCard("D", "Autres (veuillez préciser)"),

                  // Champ de précision si "Autres"
                  if (_selections["D"] == true) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: TextField(
                        controller: _autresController,
                        decoration: const InputDecoration(
                          labelText: "Précisez",
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_isSaving,
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

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

  Widget _buildCheckboxCard(String code, String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _selections[code]! ? Colors.green : Colors.grey.shade300,
          width: _selections[code]! ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: _selections[code]! ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        value: _selections[code],
        activeColor: Colors.green,
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