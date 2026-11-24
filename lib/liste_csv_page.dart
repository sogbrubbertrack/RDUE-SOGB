import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'export_csv_page.dart';

class ListeCsvPage extends StatefulWidget {
  const ListeCsvPage({super.key});

  @override
  State<ListeCsvPage> createState() => _ListeCsvPageState();
}

class _ListeCsvPageState extends State<ListeCsvPage> {
  List<FileSystemEntity> _fichiers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerFichiers();
  }

  Future<void> _chargerFichiers() async {
    setState(() => _isLoading = true);

    try {
      final base = await getApplicationDocumentsDirectory();
      final directory = Directory('${base.path}/Rubberway');

      if (await directory.exists()) {
        final fichiers = directory.listSync().where((entity) {
          return entity is File &&
              (entity.path.endsWith('.csv') || entity.path.endsWith('.CSV'));
        }).toList();

        fichiers.sort((a, b) {
          return (b as File).lastModifiedSync().compareTo(
              (a as File).lastModifiedSync()
          );
        });

        setState(() {
          _fichiers = fichiers;
          _isLoading = false;
        });
      } else {
        setState(() {
          _fichiers = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Erreur: $e", isError: true);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Future<void> _partagerFichier(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Partage ${file.path.split('/').last}',
      );
    } catch (e) {
      _showSnackBar("Erreur partage", isError: true);
    }
  }

  Future<void> _supprimerFichier(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: Text('Supprimer ${file.path.split('/').last} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULER'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('SUPPRIMER'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await file.delete();
        _chargerFichiers();
        _showSnackBar("Fichier supprimé");
      } catch (e) {
        _showSnackBar("Erreur suppression", isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _voirContenu(File file) async {
    try {
      final contenu = await file.readAsString();
      final lignes = contenu.split('\n').take(10).join('\n');

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            file.path.split('/').last,
            style: const TextStyle(fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Text(
                lignes,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('FERMER'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnackBar("Lecture impossible", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Fichiers CSV",
          style: TextStyle(fontSize: 18),
        ),
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
        // ✅ Bouton dans l'AppBar pour retourner à l'export
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Nouvel export',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportCsvPage()),
              ).then((result) {
                if (result == true) {
                  _chargerFichiers();
                  _showSnackBar("Liste mise à jour");
                }
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade50,
              Colors.white,
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _fichiers.isEmpty
            ? _buildEmptyState()
            : _buildFileList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade100.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.insert_drive_file,
                  size: 50,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Aucun fichier CSV",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Les fichiers exportés apparaîtront ici",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileList() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView.builder(
        itemCount: _fichiers.length,
        itemBuilder: (context, index) {
          final file = _fichiers[index] as File;
          final stat = file.statSync();
          final fileName = file.path.split('/').last;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => _voirContenu(file),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Icône du fichier
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.insert_drive_file,
                        size: 18,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Informations du fichier
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(stat.modified),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.storage,
                                size: 12,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatFileSize(stat.size),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionButton(
                          icon: Icons.share,
                          color: Colors.green.shade400,
                          onPressed: () => _partagerFichier(file),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.delete,
                          color: Colors.red.shade400,
                          onPressed: () => _supprimerFichier(file),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }
}