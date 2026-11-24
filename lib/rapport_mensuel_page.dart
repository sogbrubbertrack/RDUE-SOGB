// lib/pages/rapport_mensuel_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../generer_pdf_page.dart';
import '../pdf_type.dart';

class RapportMensuelPage extends StatefulWidget {
  const RapportMensuelPage({super.key});

  @override
  State<RapportMensuelPage> createState() => _RapportMensuelPageState();
}

class _RapportMensuelPageState extends State<RapportMensuelPage> {
  DateTime selectedMonth = DateTime.now();
  Map<String, dynamic>? reportData;
  bool _isLoading = false;
  int? _selectedZoneId; // ✅ Maintenant int, pas String
  List<Map<String, dynamic>> _zones = [];

  @override
  void initState() {
    super.initState();
    _loadZones();
    _loadReport();
  }

  Future<void> _loadZones() async {
    try {
      final zones = await DatabaseHelper.getZones();
      if (mounted) {
        setState(() {
          _zones = zones;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement zones: $e');
    }
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final data = await DatabaseHelper.getRapportMensuel(
        annee: selectedMonth.year,
        mois: selectedMonth.month,
      );

      if (mounted) {
        setState(() {
          reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de chargement: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadReportByZone() async {
    if (_selectedZoneId == null) {
      _loadReport();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ Appel correct avec int
      final data = await DatabaseHelper.getRapportMensuelParZone(
        annee: selectedMonth.year,
        mois: selectedMonth.month,
        zoneId: _selectedZoneId!,
      );

      if (mounted) {
        setState(() {
          reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur de chargement: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _previousMonth() {
    setState(() {
      selectedMonth = DateTime(
        selectedMonth.year,
        selectedMonth.month - 1,
        1,
      );
    });
    _loadReport();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final nextMonth = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      1,
    );

    if (nextMonth.isBefore(DateTime(now.year, now.month + 1, 1))) {
      setState(() {
        selectedMonth = nextMonth;
      });
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Rapport mensuel RDUE",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.white.withOpacity(0.2),
            height: 1,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            // Sélecteur de mois
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _previousMonth,
                        icon: const Icon(Icons.chevron_left, size: 28),
                        color: Colors.green,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          DateFormat('MMMM yyyy', 'fr_FR').format(selectedMonth),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _nextMonth,
                        icon: const Icon(Icons.chevron_right, size: 28),
                        color: Colors.green,
                      ),
                    ],
                  ),

                  // ✅ Filtre par zone avec int (CORRIGÉ)
                  if (_zones.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          const Text(
                            "Filtrer par zone: ",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              value: _selectedZoneId,
                              hint: const Text("Toutes les zones"),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text("Toutes les zones"),
                                ),
                                ..._zones.map((zone) => DropdownMenuItem<int?>(
                                  value: zone['id'] as int, // ✅ int direct
                                  child: Text(zone['nom_zone'] as String),
                                )),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedZoneId = value;
                                });
                                if (value == null) {
                                  _loadReport();
                                } else {
                                  _loadReportByZone();
                                }
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Contenu
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.green))
                  : reportData == null
                  ? const Center(child: Text("Aucune donnée disponible"))
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildActiviteGenerale(),
                    const SizedBox(height: 20),
                    _buildRepartitionVillages(),
                    const SizedBox(height: 20),
                    _buildNonConformite(),
                    const SizedBox(height: 20),
                    _buildRefus(),
                    const SizedBox(height: 20),
                    _buildEnqueteurValidateur(),
                    const SizedBox(height: 30),
                    OutlinedButton.icon(
                      onPressed: () {
                        if (reportData == null) return;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GenererPdfPage(
                              enqueteId: 0,
                              producteurId: 0,
                              pdfType: PdfType.rapportMensuel,
                              reportData: reportData!,
                              mois: selectedMonth,
                              zone: null,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text("Exporter en PDF"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
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
      ),
    );
  }

  // En-tête du rapport
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Rapport mensuel des enquêtes RDUE",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Période : ${DateFormat('MMMM yyyy', 'fr_FR').format(selectedMonth)}",
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          Text(
            "Généré le : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}",
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            "Zone : ${reportData!['zone_agent'] ?? 'Non définie'}",
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // 1. Activité générale
  Widget _buildActiviteGenerale() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "📊 ACTIVITÉ GÉNÉRALE",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _infoRow(
              "Enquêtes réalisées",
              reportData!['total_enquetes'] as int? ?? 0,
            ),
            const Divider(height: 16),
            _infoRow(
              "Enquêtes conformes",
              reportData!['enquetes_conformes'] as int? ?? 0,
              icon: Icons.check_circle,
              color: Colors.green,
            ),
            const Divider(height: 16),
            _infoRow(
              "Enquêtes non conformes",
              reportData!['enquetes_non_conformes'] as int? ?? 0,
              icon: Icons.warning,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  // 2. Répartition par village
  Widget _buildRepartitionVillages() {
    final villages = reportData!['villages_list'] as List? ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "📍 RÉPARTITION PAR VILLAGE",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...villages.map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(v['nom'] ?? '', style: const TextStyle(fontSize: 14)),
                  Text(
                    '${v['total']} enquête${v['total'] > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            )),
            if (villages.isEmpty)
              const Text("Aucune donnée disponible"),
          ],
        ),
      ),
    );
  }

  // 3. Éléments de non-conformité
  Widget _buildNonConformite() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "⚠️ ÉLÉMENTS DE NON-CONFORMITÉ",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Travail des enfants
            const Text(
              "👶 TRAVAIL DES ENFANTS",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _infoRowIndent(
              "Présence 16-17 ans",
              reportData!['presence_16_17'] as int? ?? 0,
            ),
            _infoRowIndent(
              "Présence 13-15 ans",
              reportData!['presence_13_15'] as int? ?? 0,
            ),
            _infoRowIndent(
              "Présence moins de 13 ans",
              reportData!['presence_moins_13'] as int? ?? 0,
            ),

            const Divider(height: 24),

            // Litiges fonciers
            const Text(
              "⚖️ LITIGES FONCIERS",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _infoRowIndent(
              "Litiges détectés",
              reportData!['litiges'] as int? ?? 0,
            ),

            const Divider(height: 24),

            // Produits chimiques interdits
            const Text(
              "🧪 PRODUITS CHIMIQUES INTERDITS",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _infoRowIndent(
              "Paraquat",
              reportData!['produit_paraquat'] as int? ?? 0,
            ),
            _infoRowIndent(
              "Glyphosate",
              reportData!['produit_glyphosate'] as int? ?? 0,
            ),
            _infoRowIndent(
              "2-4D",
              reportData!['produit_24d'] as int? ?? 0,
            ),
            _infoRowIndent(
              "Autres produits",
              reportData!['produit_autres'] as int? ?? 0,
            ),

            const Divider(height: 24),

            // Exploitation humaine
            const Text(
              "👥 EXPLOITATION HUMAINE",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _infoRowIndent(
              "Travailleurs mineurs",
              reportData!['travailleurs_mineurs'] as int? ?? 0,
            ),
            _infoRowIndent(
              "Absence de consentement",
              reportData!['absence_consentement'] as int? ?? 0,
            ),
            _infoRowIndent(
              "Documents conservés",
              reportData!['documents_conserves'] as int? ?? 0,
            ),
            _infoRowIndent(
              "Frais exigés",
              reportData!['frais_exiges'] as int? ?? 0,
            ),
          ],
        ),
      ),
    );
  }

  // 4. Refus d'enquête
  Widget _buildRefus() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "🚫 REFUS D'ENQUÊTE",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _infoRow(
              "Planteurs ayant refusé",
              reportData!['refus_enquetes'] as int? ?? 0,
              icon: Icons.block,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  // 5. Informations enquêteur et validateur
  Widget _buildEnqueteurValidateur() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "👤 INFORMATIONS",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Enquêteur
            Row(
              children: [
                Icon(Icons.person, size: 20, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  "ENQUÊTEUR",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                children: [
                  _infoRowSimple("Nom", reportData!['enqueteur_nom'] as String? ?? '—'),
                  _infoRowSimple("Contact", reportData!['enqueteur_contact'] as String? ?? '—'),
                  _infoRowSimple("Zone", reportData!['enqueteur_zone'] as String? ?? '—'),
                ],
              ),
            ),

            const Divider(height: 24),

            // Validateur
            Row(
              children: [
                Icon(Icons.verified_user, size: 20, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                const Text(
                  "VALIDATEUR",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                children: [
                  _infoRowSimple("Nom", reportData!['validateur_nom'] as String? ?? '—'),
                  _infoRowSimple("Contact", reportData!['validateur_contact'] as String? ?? '—'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, dynamic value, {IconData? icon, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) Icon(icon, size: 18, color: color),
            if (icon != null) const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 14)),
          ],
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _infoRowIndent(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("  • $label", style: const TextStyle(fontSize: 13)),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _infoRowSimple(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$label :", style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}