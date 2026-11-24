import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class LecteurPdfPage extends StatelessWidget {
  final String path;

  const LecteurPdfPage({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Lecture du PDF"),
        backgroundColor: Colors.green,
      ),
      body: PDFView(
        filePath: path,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
      ),
    );
  }
}
