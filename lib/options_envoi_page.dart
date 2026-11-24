import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'data/database_helper.dart';

import 'tableau_de_bord_page.dart';

class OptionsEnvoiPage extends StatefulWidget {
  final File pdfFile;
  final int? enqueteId;

  const OptionsEnvoiPage({super.key, required this.pdfFile, this.enqueteId});

  @override
  State<OptionsEnvoiPage> createState() => _OptionsEnvoiPageState();
}

class _OptionsEnvoiPageState extends State<OptionsEnvoiPage> {
  late TextEditingController nomCtrl;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();

    // Extraire le nom du fichier sans l'extension .pdf
    String fileName = widget.pdfFile.path.split('/').last;
    if (fileName.endsWith('.pdf')) {
      fileName = fileName.substring(0, fileName.length - 4);
    }

    nomCtrl = TextEditingController(text: fileName);
  }

  @override
  void dispose() {
    nomCtrl.dispose();
    super.dispose();
  }

  Future<void> _retourTableauDeBord() async {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const TableauDeBordPage()),
          (route) => false,
    );
  }

// =========================
// 📁 PRÉPARER LE FICHIER FINAL (Dossier interne Rubberway)
// =========================
  Future<File?> _preparerFichierFinal() async {
    final rawName = nomCtrl.text.trim().replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
    final safeName = rawName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'[\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[. ]+$'), '');

    if (safeName.isEmpty) {
      _showSaveError('Saisis un nom de fichier valide.');
      return null;
    }

    try {
      if (!await widget.pdfFile.exists()) {
        throw const FileSystemException('Le PDF temporaire est introuvable.');
      }
      final bytes = await widget.pdfFile.readAsBytes();
      if (bytes.isEmpty) {
        throw const FileSystemException('Le PDF est vide. Regénère le document.');
      }

      final baseDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${baseDir.path}${Platform.pathSeparator}Rubberway');
      await dir.create(recursive: true);
      final finalFile = File('${dir.path}${Platform.pathSeparator}$safeName.pdf');
      await finalFile.writeAsBytes(bytes, flush: true);
      if (!await finalFile.exists() || await finalFile.length() != bytes.length) {
        throw const FileSystemException('La vérification du fichier enregistré a échoué.');
      }

      if (widget.enqueteId != null) {
        await DatabaseHelper.marquerEnqueteAvecPdf(widget.enqueteId!, finalFile.path);
      }
      try {
        await widget.pdfFile.delete();
      } catch (_) {}
      return finalFile;
    } catch (e) {
      _showSaveError('Impossible d’enregistrer le PDF : $e');
      return null;
    }
  }

  void _showSaveError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 6)));
  }
  // =========================
  // 💾 ENREGISTRER SEULEMENT
  // =========================
  Future<void> enregistrer() async {
    if (_enCours) return;
    setState(() => _enCours = true);
    try {
      final file = await _preparerFichierFinal();
      if (file == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF enregistré dans : ${file.path}')),
      );
      await _retourTableauDeBord();
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }
  // =========================
  // 📤 PARTAGE WHATSAPP
  // =========================
  Future<void> envoyerWhatsapp() async {
    if (_enCours) return;
    setState(() => _enCours = true);
    try {
      final file = await _preparerFichierFinal();
      if (file == null || !mounted) return;
      await Share.shareXFiles([XFile(file.path)], text: "Fiche d'enquête RDUE");
      await _retourTableauDeBord();
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }
  // =========================
  // 📧 PARTAGE EMAIL
  // =========================
  Future<void> envoyerMail() async {
    if (_enCours) return;
    setState(() => _enCours = true);
    try {
      final file = await _preparerFichierFinal();
      if (file == null || !mounted) return;
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Fiche d’enquête RDUE',
        text: 'Veuillez trouver en pièce jointe la fiche d’enquête.',
      );
      await _retourTableauDeBord();
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }
  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Options du PDF"),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/fond_inf.png",
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withOpacity(0.35)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    "Que voulez-vous faire avec ce PDF ?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ================== NOM FICHIER ==================
                  TextField(
                    controller: nomCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nom du fichier (sans .pdf)",
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ================== ENREGISTRER ==================
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text("ENREGISTRER"),
                      onPressed: _enCours ? null : enregistrer,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ================== WHATSAPP ==================
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text("Envoyer par WhatsApp"),
                      onPressed: _enCours ? null : envoyerWhatsapp,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ================== EMAIL ==================
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.email),
                      label: const Text("Envoyer par Email"),
                      onPressed: _enCours ? null : envoyerMail,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
