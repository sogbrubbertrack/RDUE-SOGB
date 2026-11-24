import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rubberway/data/database_helper.dart';
import '../environnement/env_q9_page.dart';

class DroitsFonciersQ4Page extends StatefulWidget {
  final int enqueteId;
  final int producteurId;

  const DroitsFonciersQ4Page({
    super.key,
    required this.enqueteId,
    required this.producteurId,
  });

  @override
  State<DroitsFonciersQ4Page> createState() => _DroitsFonciersQ4PageState();
}

class _DroitsFonciersQ4PageState extends State<DroitsFonciersQ4Page> {
  File? _image;
  int? _reponseId;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  Future<void> _prendrePhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    await _sauvegarderImage(File(photo.path));
  }

  Future<void> _importerImage() async {
    final XFile? fichier = await _picker.pickImage(source: ImageSource.gallery);
    if (fichier == null) return;
    await _sauvegarderImage(File(fichier.path));
  }

  Future<void> _sauvegarderImage(File fichier) async {
    setState(() => _isSaving = true);

    try {
      final dir = await getApplicationDocumentsDirectory();
      final dossier = Directory("${dir.path}/Rubberway/df");

      if (!await dossier.exists()) {
        await dossier.create(recursive: true);
      }

      final String nouveauNom =
          "DF_Q4_DOC_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final File copie = await fichier.copy("${dossier.path}/$nouveauNom");

      _reponseId = await DatabaseHelper.saveReponse(
        enqueteId: widget.enqueteId,
        questionId: '4',
        codeReponse: "PHOTO",
        valeur: "Photo documentation",
        precision: null,
      );

      if (_reponseId != null) {
        await DatabaseHelper.savePhoto(
          reponseId: _reponseId!,
          chemin: copie.path,
        );
        debugPrint('✅ Photo sauvegardée pour réponse ID: $_reponseId');
      }

      setState(() => _image = copie);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Image sauvegardée"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Erreur : $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _continuer() {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez prendre ou importer une image."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ CORRECTION: push au lieu de pushReplacement
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnvironnementQ9Page(
          enqueteId: widget.enqueteId,
          producteurId: widget.producteurId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Droits fonciers"),
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
                        "Question 4/43",
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
                      "Image de la documentation",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Aperçu de l'image
                  if (_image != null)
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          _image!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white54),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image,
                              size: 40,
                              color: Colors.white70,
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Aucune image",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Boutons photo
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _prendrePhoto,
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text("Prendre"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _importerImage,
                          icon: const Icon(Icons.image, size: 18),
                          label: const Text("Importer"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Bouton CONTINUER
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (_isSaving || _image == null) ? null : _continuer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
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