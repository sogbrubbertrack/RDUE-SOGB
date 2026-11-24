import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'data/database_helper.dart'; // À créer pour la table refus

class ResumeRefusPage extends StatefulWidget {
  final int? enqueteId; // Optionnel, si on veut lier à une enquête

  const ResumeRefusPage({super.key, this.enqueteId});

  @override
  State<ResumeRefusPage> createState() => _ResumeRefusPageState();
}

class _ResumeRefusPageState extends State<ResumeRefusPage> {
  String? _motifRefus;
  String? _autreMotif;
  bool _isSaving = false;

  // Liste des motifs de refus
  final List<String> _motifs = [
    'Refus verbal sans justification',
    'Producteur indisponible',
    'Méfiance / Refus de participer',
    'Problème de langue',
    'Absence prolongée',
    'Autre (préciser)',
  ];

  Future<void> _enregistrerRefus() async {
    if (_motifRefus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner un motif de refus"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_motifRefus == 'Autre (préciser)' &&
        (_autreMotif == null || _autreMotif!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez préciser le motif de refus"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ Récupération des informations du producteur
      final codePhi = prefs.getString("PROD_CODE_PHI") ?? "—";
      final nom = prefs.getString("PROD_NOM") ?? "—";
      final village = prefs.getString("PROD_VILLAGE") ?? "—";
      final contact = prefs.getString("PROD_CONTACT") ?? "—";

      // ✅ Récupération des informations de l'agent
      final agentNom = prefs.getString("agent_nom") ?? "—";
      final agentContact = prefs.getString("agent_contact") ?? "—";
      final agentZone = prefs.getString("agent_zone") ?? "—";

      // ✅ Construction du motif complet
      String motifComplet = _motifRefus!;
      if (_motifRefus == 'Autre (préciser)' && _autreMotif != null) {
        motifComplet = 'Autre : ${_autreMotif!.trim()}';
      }

      // ✅ Sauvegarde en base de données (si DatabaseHelper est disponible)
      if (widget.enqueteId != null) {
        // À implémenter dans DatabaseHelper
        // await DatabaseHelper.saveRefus(
        //   enqueteId: widget.enqueteId!,
        //   motif: motifComplet,
        //   dateRefus: DateTime.now(),
        // );
      }

      // ✅ Génération du PDF
      await _genererPdf(
        codePhi: codePhi,
        nom: nom,
        village: village,
        contact: contact,
        agentNom: agentNom,
        agentContact: agentContact,
        agentZone: agentZone,
        motif: motifComplet,
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _genererPdf({
    required String codePhi,
    required String nom,
    required String village,
    required String contact,
    required String agentNom,
    required String agentContact,
    required String agentZone,
    required String motif,
  }) async {
    final now = DateTime.now();
    final dateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    final heureStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    // ✅ Chargement du logo
    final logo = await imageFromAssetBundle("assets/images/logo_sogb.jpg");

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ==================== EN-TÊTE AVEC LOGO ====================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Image(logo, height: 50),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "FICHE DE REFUS D’ENQUÊTE",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                      pw.Text(
                        "RDUE - SOGB",
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.red),
              pw.SizedBox(height: 10),

              // ==================== DATE ET HEURE ====================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Date : $dateStr",
                    style: pw.TextStyle(fontSize: 11),
                  ),
                  pw.Text(
                    "Heure : $heureStr",
                    style: pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // ==================== INFORMATIONS PRODUCTEUR ====================
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          '👤 ',
                          style: pw.TextStyle(fontSize: 14),
                        ),
                        pw.Text(
                          "INFORMATIONS DU PRODUCTEUR",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red,
                          ),
                        ),
                      ],
                    ),
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildInfoRow('Code PHI', codePhi),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          child: _buildInfoRow('Nom complet', nom),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildInfoRow('Village', village),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          child: _buildInfoRow('Contact', contact),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // ==================== MOTIF DE REFUS ====================
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                color: PdfColors.red50,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "MOTIF DE REFUS",
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      motif,
                      style: pw.TextStyle(fontSize: 12, height: 1.4),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      "Le producteur a refusé de participer au questionnaire RDUE. "
                          "Aucune donnée technique ou sociale n’a été collectée.",
                      style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // ==================== INFORMATIONS AGENT ====================
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          '👤 ',
                          style: pw.TextStyle(fontSize: 14),
                        ),
                        pw.Text(
                          "AGENT ENQUÊTEUR",
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green700,
                          ),
                        ),
                      ],
                    ),
                    pw.Divider(),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildInfoRow('Nom complet', agentNom),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          child: _buildInfoRow('Contact', agentContact),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildInfoRow('Zone', agentZone),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // ==================== MENTION REFUS DE SIGNATURE ====================
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  "Le producteur a refusé de signer tout document.",
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              pw.Spacer(),

              // ==================== SIGNATURES ====================
              pw.Divider(),
              pw.SizedBox(height: 10),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "Signature de l'agent",
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 25),
                      pw.Text(
                        agentNom,
                        style: pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Container(
                    width: 150,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Cachet SOGB",
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 25),
                        pw.Text(
                          "(emplacement réservé)",
                          style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // ==================== PIED DE PAGE ====================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Document généré par l’application RubberWay',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                  ),
                  pw.Text(
                    'Page 1/1',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // ✅ Impression du PDF
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'refus_enquete_$codePhi.pdf',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("PDF généré avec succès"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ✅ Widget helper pour afficher une ligne d'information
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Text(
          '$label : ',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.black,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Constat de refus",
          style: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.red,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // ✅ Image de fond
          Positioned.fill(
            child: Image.asset(
              'assets/images/fond_questionnaire.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withOpacity(0.2)),

          // ✅ Contenu principal
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ✅ Carte d'information
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.block,
                            color: Colors.red,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Refus d\'enquête',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Le producteur a refusé de participer au questionnaire RDUE.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF616161),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✅ Carte de saisie du motif
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MOTIF DE REFUS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ✅ Liste des motifs
                        ..._motifs.map((motif) => RadioListTile<String>(
                          title: Text(motif),
                          value: motif,
                          groupValue: _motifRefus,
                          onChanged: _isSaving ? null : (value) {
                            setState(() => _motifRefus = value);
                          },
                          activeColor: Colors.red,
                          contentPadding: EdgeInsets.zero,
                        )),

                        // ✅ Champ pour "Autre"
                        if (_motifRefus == 'Autre (préciser)')
                          Padding(
                            padding: const EdgeInsets.only(top: 8, left: 16),
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Précisez le motif...',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              maxLines: 2,
                              onChanged: (value) => _autreMotif = value,
                              enabled: !_isSaving,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ✅ Carte des actions
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _isSaving
                                ? Container(
                              width: 20,
                              height: 20,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : const Icon(Icons.picture_as_pdf),
                            label: Text(
                              _isSaving ? 'GÉNÉRATION...' : 'GÉNÉRER LE PDF DE REFUS',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: _isSaving ? null : _enregistrerRefus,
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextButton.icon(
                          icon: const Icon(Icons.home, color: Colors.grey),
                          label: const Text(
                            'RETOUR À L\'ACCUEIL',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Text(
                    'Document confidentiel - RubberWay',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
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