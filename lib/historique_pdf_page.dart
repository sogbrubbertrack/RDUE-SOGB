import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'rubberway_repository.dart';

class HistoriquePdfPage extends StatefulWidget {
  const HistoriquePdfPage({super.key});

  @override
  State<HistoriquePdfPage> createState() => _HistoriquePdfPageState();
}

class _HistoriquePdfPageState extends State<HistoriquePdfPage> {
  List<File> files = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => loading = true);

    final pdfs = await RubberwayRepository.getAllPdfs();

    setState(() {
      files = pdfs;
      loading = false;
    });
  }

  String _formatDate(DateTime d) {
    return DateFormat("dd/MM/yyyy HH:mm").format(d);
  }

  String _nomFichier(File f) => f.path.split('/').last;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des PDF"),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _charger,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : files.isEmpty
          ? const Center(child: Text("Aucun PDF trouvé."))
          : SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(
          columns: const [
            DataColumn(label: Text("Nom du fichier")),
            DataColumn(label: Text("Date / Heure")),
          ],
          rows: files.map((f) {
            final stat = f.statSync();
            final dateStr = _formatDate(stat.modified);

            return DataRow(cells: [
              DataCell(Text(_nomFichier(f))),
              DataCell(Text(dateStr)),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
