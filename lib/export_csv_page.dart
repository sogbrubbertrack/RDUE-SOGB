import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'export_csv_service.dart';
import 'liste_csv_page.dart';

class ExportCsvPage extends StatefulWidget {
  const ExportCsvPage({super.key});

  @override
  State<ExportCsvPage> createState() => _ExportCsvPageState();
}

class _ExportCsvPageState extends State<ExportCsvPage> {
  DateTime _dateDebut = DateTime.now().subtract(const Duration(days: 30));
  DateTime _dateFin = DateTime.now();
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Exporter CSV"),
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // ✅ Image de fond remplacée par fond_questionnaire.jpg
          Positioned.fill(
            child: Image.asset(
              "assets/images/fond_questionnaire.jpg",
              fit: BoxFit.cover,
            ),
          ),

          // Filtre sombre pour lisibilité (ajusté pour être plus léger)
          Container(color: Colors.black.withOpacity(0.2)),

          // Contenu principal
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Espace réduit
                  const SizedBox(height: 10),

                  // Carte Date début
                  _buildDateCard(
                    title: "DATE DE DÉBUT",
                    date: _dateDebut,
                    icon: Icons.calendar_today,
                    color: Colors.blue,
                    onTap: () => _selectDate(context, true),
                  ),

                  const SizedBox(height: 16),

                  // Carte Date fin
                  _buildDateCard(
                    title: "DATE DE FIN",
                    date: _dateFin,
                    icon: Icons.calendar_today,
                    color: Colors.orange,
                    onTap: () => _selectDate(context, false),
                  ),

                  const SizedBox(height: 30),

                  // Résumé de la période
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          color: Colors.green.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Période sélectionnée",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Du ${_formatDate(_dateDebut)} au ${_formatDate(_dateFin)}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const SizedBox(height: 40),

                  // Bouton Exporter
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isExporting ? null : _exporter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 5,
                      ),
                      child: _isExporting
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Text(
                        "EXPORTER",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Bouton Voir la liste
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ListeCsvPage()),
                        );
                      },
                      icon: const Icon(Icons.list, color: Colors.white),
                      label: const Text(
                        "VOIR LA LISTE CSV",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Bouton Annuler
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      child: const Text(
                        "ANNULER",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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

  // =======================
  // CARTE DE SÉLECTION DE DATE
  // =======================
  Widget _buildDateCard({
    required String title,
    required DateTime date,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(date),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =======================
  // SÉLECTEUR DE DATE
  // =======================
  Future<void> _selectDate(BuildContext context, bool isDebut) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isDebut ? _dateDebut : _dateFin,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isDebut) {
          _dateDebut = picked;
        } else {
          _dateFin = picked;
        }
      });
    }
  }

  // =======================
  // FORMATAGE DE DATE
  // =======================
  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // =======================
  // EXPORT CSV
  // =======================
  Future<void> _exporter() async {
    setState(() => _isExporting = true);

    try {
      // Appel du service d'export
      final file = await ExportCsvService.exportToCsv(
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );

      if (!mounted) return;

      // Message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ CSV exporté: ${file.path.split('/').last}"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // ✅ REDIRECTION VERS LA LISTE CSV APRÈS EXPORT RÉUSSI
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ListeCsvPage()),
      );

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Erreur: $e"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isExporting = false);
    }
  }
}