import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'signature_planteur_page.dart';

class ConfirmationIdentitePage extends StatefulWidget {
  final int enqueteId;      // ← AJOUT DES PARAMÈTRES
  final int producteurId;   // ← AJOUT DES PARAMÈTRES

  const ConfirmationIdentitePage({
    super.key,
    required this.enqueteId,      // ← REQUIS
    required this.producteurId,   // ← REQUIS
  });

  @override
  State<ConfirmationIdentitePage> createState() => _ConfirmationIdentitePageState();
}

class _ConfirmationIdentitePageState extends State<ConfirmationIdentitePage> {
  final ImagePicker _picker = ImagePicker();

  XFile? photoInterlocuteur;
  XFile? pieceRecto;
  XFile? pieceVerso;

  bool saving = false;

  Future<void> _choisirImage(Function(XFile) onPicked) async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Prendre une photo"),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                  maxWidth: 1280,
                );
                if (image != null) {
                  setState(() => onPicked(image));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text("Choisir depuis la galerie"),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 1280,
                );
                if (image != null) {
                  setState(() => onPicked(image));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _apercu(XFile? file) {
    if (file == null) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text("Aucune image"),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(file.path),
        height: 120,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Future<void> _continuer() async {
    if (photoInterlocuteur == null || pieceRecto == null || pieceVerso == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez fournir toutes les photos"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString("PHOTO_INTERLOCUTEUR", photoInterlocuteur!.path);
      await prefs.setString("PHOTO_PIECE_RECTO", pieceRecto!.path);
      await prefs.setString("PHOTO_PIECE_VERSO", pieceVerso!.path);

      if (!mounted) return;

      // ✅ CORRECTION : Passage des paramètres à SignaturePlanteurPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignaturePlanteurPage(
            enqueteId: widget.enqueteId,      // ← Passage de l'ID
            producteurId: widget.producteurId, // ← Passage de l'ID
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirmation d'identité"),
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Image de fond
          Positioned.fill(
            child: Image.asset(
              "assets/images/fond_inf.png",
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withOpacity(0.1)),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "CONFIRMATION D'IDENTITÉ",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Photo interlocuteur
                  _buildPhotoSection(
                    title: "Photo de l'interlocuteur",
                    icon: Icons.person,
                    file: photoInterlocuteur,
                    onTap: () => _choisirImage((x) => photoInterlocuteur = x),
                  ),

                  const SizedBox(height: 20),

                  // Pièce recto
                  _buildPhotoSection(
                    title: "Pièce d'identité (Recto)",
                    icon: Icons.credit_card,
                    file: pieceRecto,
                    onTap: () => _choisirImage((x) => pieceRecto = x),
                  ),

                  const SizedBox(height: 20),

                  // Pièce verso
                  _buildPhotoSection(
                    title: "Pièce d'identité (Verso)",
                    icon: Icons.credit_card,
                    file: pieceVerso,
                    onTap: () => _choisirImage((x) => pieceVerso = x),
                  ),

                  const SizedBox(height: 30),

                  // Bouton CONTINUER
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: saving ? null : _continuer,
                      icon: saving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Icon(Icons.arrow_forward),
                      label: Text(saving ? "CHARGEMENT..." : "CONTINUER"),
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

  Widget _buildPhotoSection({
    required String title,
    required IconData icon,
    required XFile? file,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _apercu(file),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(file == null ? Icons.add_a_photo : Icons.edit),
              label: Text(file == null ? "Ajouter une photo" : "Changer la photo"),
            ),
          ),
        ],
      ),
    );
  }
}