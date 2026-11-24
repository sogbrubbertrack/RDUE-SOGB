import 'package:flutter/material.dart';
import 'package:rubberway/data/database_helper.dart';
import 'men_q26_page.dart';
import '../travailleurs/trav_q28_page.dart';

class MenQ25Page extends StatefulWidget {
  final int enqueteId;
  final int producteurId;

  const MenQ25Page({
    super.key,
    required this.enqueteId,
    required this.producteurId,
  });

  @override
  State<MenQ25Page> createState() => _MenQ25PageState();
}

class _MenQ25PageState extends State<MenQ25Page> {
  String? _reponse;
  bool _isSaving = false;

  Future<void> _continuer() async {
    if (_reponse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez choisir une réponse."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      int reponseId = await DatabaseHelper.saveReponse(
        enqueteId: widget.enqueteId,
        questionId: '25',
        codeReponse: _reponse,
        valeur: _reponse,
        precision: null,
      );

      debugPrint('✅ Réponse Q25 sauvegardée (ID: $reponseId)');

      Widget nextPage;

      // ✅ CORRECTION : Test sur "D" pour OUI, pas sur "A"
      if (_reponse == "D") {
        // OUI → il y a des enfants < 13 ans
        nextPage = MenQ26Page(
          enqueteId: widget.enqueteId,
          producteurId: widget.producteurId,
        );
      } else {
        // NON → passer aux travailleurs
        nextPage = TravQ28Page(
          enqueteId: widget.enqueteId,
          producteurId: widget.producteurId,
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => nextPage),
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
        title: const Text("Ménages"),
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
                        "Question 25/43",
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
                      "Y a-t-il des membres du ménage âgés de moins de 13 ans ?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Options Oui/Non
                  Row(
                    children: [
                      Expanded(
                        child: _buildChoiceCard("D", "OUI"),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildChoiceCard("Z", "NON"),
                      ),
                    ],
                  ),

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

  Widget _buildChoiceCard(String value, String label) {
    final isSelected = _reponse == value;

    // ✅ CORRECTION : Couleurs adaptées aux codes corrects
    Color getColor() {
      if (!isSelected) return Colors.grey.shade400;
      return value == "D" ? Colors.green : Colors.red;
    }

    return GestureDetector(
      onTap: _isSaving ? null : () => setState(() => _reponse = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? (value == "D" ? Colors.green : Colors.red)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              value == "D" ? Icons.child_care : Icons.person_outline,
              size: 40,
              color: getColor(),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: getColor(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}