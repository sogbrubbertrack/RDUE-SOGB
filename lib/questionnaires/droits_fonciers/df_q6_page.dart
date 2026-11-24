import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rubberway/data/database_helper.dart';
import '../environnement/env_q9_page.dart';

class DroitsFonciersQ6Page extends StatefulWidget {
  final int enqueteId;
  final int producteurId;

  const DroitsFonciersQ6Page({
    super.key,
    required this.enqueteId,
    required this.producteurId,
  });

  @override
  State<DroitsFonciersQ6Page> createState() => _DroitsFonciersQ6PageState();
}

class _DroitsFonciersQ6PageState extends State<DroitsFonciersQ6Page> {
  File? _image;
  int? _reponseId;
  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;

  Future<void> _prendrePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (photo == null) return;
    await _sauvegarderImage(File(photo.path));
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
          "DF_Q6_RECONNAISSANCE_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final File copie = await fichier.copy("${dossier.path}/$nouveauNom");

      _reponseId = await DatabaseHelper.saveReponse(
        enqueteId: widget.enqueteId,
        questionId: '6',
        codeReponse: "PHOTO",
        valeur: "Photo reconnaissance",
        precision: null,
      );

      if (_reponseId != null) {
        await DatabaseHelper.savePhoto(
          reponseId: _reponseId!,
          chemin: copie.path,
        );
        debugPrint('✅ Photo sauvegardée ID: $_reponseId');
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
          content: Text("Veuillez prendre une photo."),
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
                        "Question 6/43",
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
                      "Télechargez une image pour montrer comment l'utilisation des terres est reconnue:",
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
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          _image!,
                          height: 200,
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
                              Icons.photo_camera,
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

                  // Bouton photo
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _prendrePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("PRENDRE UNE PHOTO"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
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