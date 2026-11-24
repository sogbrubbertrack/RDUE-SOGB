import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'lecteur_pdf_page.dart';

class DossierRubberwayPage extends StatefulWidget {
  const DossierRubberwayPage({super.key});

  @override
  State<DossierRubberwayPage> createState() => _DossierRubberwayPageState();
}

class _DossierRubberwayPageState extends State<DossierRubberwayPage> {
  List<File> files = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<Directory> _getRubberwayDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory("${base.path}/Rubberway");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _charger() async {
    setState(() => loading = true);

    final dir = await _getRubberwayDir();
    final all = dir.listSync();

    final pdfs = all
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith(".pdf"))
        .toList();

    pdfs.sort((a, b) {
      final sa = a.statSync().modified;
      final sb = b.statSync().modified;
      return sb.compareTo(sa);
    });

    setState(() {
      files = pdfs;
      loading = false;
    });
  }

  // ===================== ACTIONS =====================

  void _ouvrir(File f) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LecteurPdfPage(path: f.path),
      ),
    );
  }

  Future<void> _partagerWhatsapp(File f) async {
    await Share.shareXFiles([XFile(f.path)], text: "Fiche d'enquête RDUE");
  }

  Future<void> _partagerEmail(File f) async {
    await Share.shareXFiles(
      [XFile(f.path)],
      subject: "Fiche d'enquête RDUE",
      text: "Veuillez trouver en pièce jointe la fiche d'enquête.",
    );
  }

  Future<void> _supprimer(File f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Supprimer"),
        content: Text("Supprimer le fichier :\n${_nomFichier(f)} ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await f.delete();
      await _charger();
    }
  }

  Future<void> _renommer(File f) async {
    final ctrl = TextEditingController(text: _nomFichierSansExtension(f));

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Renommer le fichier"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: "Nouveau nom (sans .pdf)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text("Renommer"),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      final dir = await _getRubberwayDir();
      final newPath = "${dir.path}/$newName.pdf";
      await f.rename(newPath);
      await _charger();
    }
  }

  // ===================== UTILS =====================

  String _nomFichier(File f) => f.path.split('/').last;

  String _nomFichierSansExtension(File f) {
    final n = _nomFichier(f);
    return n.toLowerCase().endsWith(".pdf") ? n.substring(0, n.length - 4) : n;
  }

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dossier Rubberway",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _charger,
            tooltip: "Actualiser",
          ),
        ],
      ),
      body: Container(
        color: Colors.white, // Fond blanc
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : files.isEmpty
            ? _buildEmptyState()
            : _buildPdfList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            "Aucun PDF trouvé",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Les fichiers PDF générés apparaîtront ici",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: files.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final f = files[index];
        final stat = f.statSync();
        final dateStr = DateFormat("dd/MM/yyyy HH:mm").format(stat.modified);

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.picture_as_pdf,
              color: Colors.red.shade700,
              size: 24,
            ),
          ),
          title: Text(
            _nomFichier(f),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            "Modifié le $dateStr",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          onTap: () => _ouvrir(f),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == "ouvrir") _ouvrir(f);
              if (v == "renommer") _renommer(f);
              if (v == "supprimer") _supprimer(f);
              if (v == "wa") _partagerWhatsapp(f);
              if (v == "mail") _partagerEmail(f);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: "ouvrir",
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 18),
                    SizedBox(width: 8),
                    Text("Ouvrir"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: "renommer",
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text("Renommer"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: "wa",
                child: Row(
                  children: [
                    Icon(Icons.share, size: 18),
                    SizedBox(width: 8),
                    Text("WhatsApp"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: "mail",
                child: Row(
                  children: [
                    Icon(Icons.email, size: 18),
                    SizedBox(width: 8),
                    Text("Email"),
                  ],
                ),
              ),
              PopupMenuItem(
                value: "supprimer",
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text("Supprimer"),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}