import 'package:flutter/material.dart';
import 'package:rubberway/data/database_helper.dart';
import 'trav_q32_page.dart';

class TravQ31Page extends StatefulWidget {
  final int enqueteId;
  final int producteurId;

  const TravQ31Page({
    super.key,
    required this.enqueteId,
    required this.producteurId,
  });

  @override
  State<TravQ31Page> createState() => _TravQ31PageState();
}

class _TravQ31PageState extends State<TravQ31Page> {
  final TextEditingController _revenuController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _revenuController.dispose();
    super.dispose();
  }

  Future<void> _continuer() async {
    final txt = _revenuController.text.trim();

    if (txt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez saisir un montant"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final int? valeur = int.tryParse(txt);
    if (valeur == null || valeur < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Montant invalide"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      int reponseId = await DatabaseHelper.saveReponse(
        enqueteId: widget.enqueteId,
        questionId: '31',
        codeReponse: null,
        valeur: valeur.toString(),
        precision: null,
      );

      debugPrint('✅ Réponse Q31 sauvegardée (ID: $reponseId)');

      // ✅ CORRECTION: push au lieu de pushReplacement
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TravQ32Page(
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
                        "Question 31/43",
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
                      "Revenu mensuel des travailleurs (FCFA)?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Champ de saisie
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Montant",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _revenuController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: "Ex: 75000",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            suffixText: "FCFA",
                          ),
                          enabled: !_isSaving,
                          autofocus: true,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "Revenu mensuel moyen en FCFA",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
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
}