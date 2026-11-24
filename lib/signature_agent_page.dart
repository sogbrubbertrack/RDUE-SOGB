import 'dart:io';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rubberway/data/database_helper.dart';
import 'resume_final_page.dart'; // À adapter selon l'arborescence

class SignatureAgentPage extends StatefulWidget {
  final int enqueteId;
  final int producteurId;

  const SignatureAgentPage({
    super.key,
    required this.enqueteId,
    required this.producteurId,
  });

  @override
  State<SignatureAgentPage> createState() => _SignatureAgentPageState();
}

class _SignatureAgentPageState extends State<SignatureAgentPage> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez signer avant de continuer"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Export PNG
      final signatureBytes = await _controller.toPngBytes();
      if (signatureBytes == null) {
        throw Exception("Impossible de générer la signature");
      }

      // 2. Dossier signatures
      final appDir = await getApplicationDocumentsDirectory();
      final signatureDir = Directory('${appDir.path}/signatures');
      if (!await signatureDir.exists()) {
        await signatureDir.create(recursive: true);
      }

      // 3. Nom UNIQUE avec ID de l'enquête
      final file = File(
        '${signatureDir.path}/signature_agent_${widget.enqueteId}.png',
      );
      await file.writeAsBytes(signatureBytes);

      // 4. Sauvegarde en BASE SQLite
      await DatabaseHelper.saveSignature(
        enqueteId: widget.enqueteId,
        type: DatabaseHelper.SIGNATURE_AGENT,
        chemin: file.path,
      );

      debugPrint('✅ Signature agent sauvegardée: ${file.path}');

      if (!mounted) return;

      // 5. Redirection vers ResumeFinalPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResumeFinalPage(
            enqueteId: widget.enqueteId,
            producteurId: widget.producteurId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Erreur signature agent: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clear() => _controller.clear();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Signature de l'agent"),
        backgroundColor: Colors.green,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isSaving ? null : _clear,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Image de fond
          Positioned.fill(
            child: Image.asset(
              'assets/images/fond_questionnaire.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withOpacity(0.2)),

          // Contenu principal
          SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    "L'agent enquêteur doit signer dans la zone ci-dessous",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),

                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Signature(
                        controller: _controller,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _clear,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: const BorderSide(color: Colors.grey),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("EFFACER"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSignature,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Text("CONTINUER"),
                        ),
                      ),
                    ],
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