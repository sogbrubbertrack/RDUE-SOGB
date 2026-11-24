import 'package:flutter/material.dart';
import 'package:rubberway/data/database_helper.dart';
import 'trav_q39_page.dart';

class TravQ38Page extends StatefulWidget {
  final int enqueteId;
  final int producteurId;

  const TravQ38Page({
    super.key,
    required this.enqueteId,
    required this.producteurId,
  });

  @override
  State<TravQ38Page> createState() => _TravQ38PageState();
}

class _TravQ38PageState extends State<TravQ38Page> {
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
        questionId: '38',
        codeReponse: _reponse,
        valeur: _reponse,
        precision: null,
      );

      debugPrint('✅ Réponse Q38 sauvegardée (ID: $reponseId)');

      // ✅ CORRECTION: push au lieu de pushReplacement
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TravQ39Page(
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
            // ✅ SingleChildScrollView pour éviter overflow
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
                        "Question 38/43",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Question (simplifiée)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Y a-t-il des travailleurs de moins de 16 ans ?",
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
                        child: _buildChoiceCard("C", "OUI"),
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

    return GestureDetector(
      onTap: _isSaving ? null : () => setState(() => _reponse = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? (value == "C" ? Colors.orange : Colors.green)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              value == "C" ? Icons.warning : Icons.check_circle,
              size: 40,
              color: isSelected
                  ? (value == "C" ? Colors.orange : Colors.green)
                  : Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? (value == "C" ? Colors.orange : Colors.green)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}