import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database_helper.dart';
import 'lecteur_pdf_page.dart';

class StatistiquesPage extends StatefulWidget {
  const StatistiquesPage({super.key});

  @override
  State<StatistiquesPage> createState() => _StatistiquesPageState();
}

class _StatistiquesPageState extends State<StatistiquesPage> {
  DateTime _debut = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _fin = DateTime.now();
  int? _zoneId;
  List<Map<String, dynamic>> _zones = [];
  String _agentName = 'Agent de terrain';
  String _configuredZoneName = '';
  List<Map<String, dynamic>> _activites = [];
  Map<String, int> _stats = {};
  Map<String, int> _villages = {};
  Map<String, int> _criteres = {};
  bool _loading = true;
  bool _sharing = false;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final zones = await DatabaseHelper.getZones();
      final prefs = await SharedPreferences.getInstance();
      final agentName = (prefs.getString('agent_nom') ?? '').trim();
      final configuredZone = (prefs.getString('agent_zone') ?? '').trim();
      final normalizedZone = configuredZone.toLowerCase();
      final configuredZoneRows = zones.where(
        (item) =>
            '${item['nom_zone'] ?? ''}'.trim().toLowerCase() == normalizedZone,
      );
      final zoneId = configuredZoneRows.isEmpty
          ? null
          : (configuredZoneRows.first['id'] as num).toInt();
      final nameParts = agentName.split(RegExp(r'\s+'));
      final familyName = nameParts.length > 1 ? nameParts.last : agentName;
      final enqueteur = familyName.isEmpty
          ? null
          : await DatabaseHelper.getEnqueteurByNom(familyName);
      final enqueteurId = (enqueteur?['id'] as num?)?.toInt();
      final stats = await DatabaseHelper.getStatistiquesActivite(
        debut: _debut,
        fin: _fin,
        zoneId: zoneId,
        enqueteurId: enqueteurId,
      );
      final activities = await DatabaseHelper.getDetailsStatistiquesActivite(
        debut: _debut,
        fin: _fin,
        zoneId: zoneId,
        enqueteurId: enqueteurId,
      );
      final nonConformities = await DatabaseHelper.getEnquetesPourFormation();

      final villageCounts = <String, int>{};
      for (final activity in activities) {
        final village = '${activity['village'] ?? ''}'.trim();
        if (village.isNotEmpty) {
          villageCounts.update(
            village,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }

      final criterionCounts = <String, int>{};
      for (final item in nonConformities) {
        final date = DateTime.tryParse('${item['date_fin'] ?? ''}');
        if (date == null ||
            date.isBefore(_debut) ||
            !date.isBefore(_fin.add(const Duration(days: 1))) ||
            (zoneId != null && (item['zone_id'] as num?)?.toInt() != zoneId) ||
            (enqueteurId != null &&
                (item['enqueteur_id'] as num?)?.toInt() != enqueteurId)) {
          continue;
        }
        final criteria = (item['criteres_non_conformes'] as List? ?? const [])
            .map((criterion) => '$criterion');
        for (final criterion in criteria) {
          criterionCounts.update(
            criterion,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _zones = zones;
        _agentName = agentName.isEmpty ? 'Agent de terrain' : agentName;
        _configuredZoneName = configuredZone;
        _zoneId = zoneId;
        _stats = stats;
        _activites = activities;
        _villages = villageCounts;
        _criteres = criterionCounts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? _debut : _fin,
      firstDate: start ? DateTime(2020) : _debut,
      lastDate: start ? _fin : now,
      helpText: start ? 'Début de la période' : 'Fin de la période',
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _debut = selected;
      } else {
        _fin = selected;
      }
    });
    await _load();
  }

  String get _zoneName {
    if (_configuredZoneName.isNotEmpty) return _configuredZoneName;
    if (_zoneId == null) return 'Zone non renseignée';
    final zone = _zones.where((item) => item['id'] == _zoneId);
    return zone.isEmpty ? 'Zone attribuée' : '${zone.first['nom_zone']}';
  }

  int get _enquetesTerminees =>
      _activites.where((item) => item['is_realisee'] == true).length;

  int get _enquetesNonConformes => _activites
      .where(
        (item) =>
            item['is_realisee'] == true && item['is_non_conforme'] == true,
      )
      .length;

  int get _enquetesConformes => _enquetesTerminees - _enquetesNonConformes;

  String get _tauxConformite => _enquetesTerminees == 0
      ? '0,0'
      : (_enquetesConformes * 100 / _enquetesTerminees)
            .toStringAsFixed(1)
            .replaceAll('.', ',');

  double get _tauxRealisation => (_stats['total'] ?? 0) == 0
      ? 0
      : ((_stats['realisees'] ?? 0) / (_stats['total'] ?? 1))
            .clamp(0.0, 1.0)
            .toDouble();

  Widget _performanceSummary() => Card(
    margin: const EdgeInsets.only(top: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Taux de réalisation',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${(_tauxRealisation * 100).toStringAsFixed(0)} %',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _tauxRealisation,
              minHeight: 9,
              backgroundColor: Colors.green.shade50,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_stats['realisees'] ?? 0} enquête(s) terminée(s) avec PDF sur ${_stats['total'] ?? 0} démarrée(s).',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  pw.Widget _pdfCell(
    String value, {
    bool header = false,
    PdfColor? background,
  }) => pw.Container(
    color: background,
    padding: const pw.EdgeInsets.all(5),
    child: pw.Text(
      value,
      style: pw.TextStyle(
        fontSize: header ? 8 : 7.5,
        fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: header ? PdfColors.white : PdfColors.grey900,
      ),
    ),
  );

  pw.Widget _pdfTable(
    List<String> headers,
    List<List<String>> rows, {
    List<double>? flexes,
  }) {
    if (rows.isEmpty) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Text(
          'Aucune donnée pour cette période.',
          style: const pw.TextStyle(fontSize: 9),
        ),
      );
    }
    final widths = <int, pw.TableColumnWidth>{};
    if (flexes != null) {
      for (var index = 0; index < flexes.length; index++) {
        widths[index] = pw.FlexColumnWidth(flexes[index]);
      }
    }
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
      columnWidths: widths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green700),
          children: headers
              .map((header) => _pdfCell(header, header: true))
              .toList(),
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: row.map((value) => _pdfCell(value)).toList(),
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfSection(String title, pw.Widget content) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 13),
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.green800,
        ),
      ),
      pw.SizedBox(height: 5),
      content,
    ],
  );

  Future<void> _partagerParWhatsApp() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final generatedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final agentName = (prefs.getString('agent_nom') ?? '').trim();
      final configuredZone = (prefs.getString('agent_zone') ?? '').trim();
      final reportZoneName = _zoneId == null && configuredZone.isNotEmpty
          ? configuredZone
          : _zoneName;
      final validatorName = [
        prefs.getString('VALIDATEUR_PRENOMS') ?? '',
        prefs.getString('VALIDATEUR_NOM') ?? '',
      ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
      final signaturePath = prefs.getString('agent_signature_path');
      pw.ImageProvider? agentSignature;
      if (signaturePath != null && signaturePath.isNotEmpty) {
        final signatureFile = File(signaturePath);
        if (await signatureFile.exists()) {
          agentSignature = pw.MemoryImage(await signatureFile.readAsBytes());
        }
      }
      final sogbLogo = pw.MemoryImage(
        (await rootBundle.load(
          'assets/images/logo_sogb.jpg',
        )).buffer.asUint8List(),
      );
      final conformities = [
        ['Enquêtes démarrées', '${_stats['total'] ?? 0}'],
        ['Enquêtes réalisées avec PDF', '${_stats['realisees'] ?? 0}'],
        ['Enquêtes en cours / attente du PDF', '${_stats['en_cours'] ?? 0}'],
        ['Enquêtes refusées', '${_stats['refusees'] ?? 0}'],
        ['Enquêtes conformes', '$_enquetesConformes'],
        ['Enquêtes non conformes', '$_enquetesNonConformes'],
        ['Taux de conformité', '$_tauxConformite %'],
        ['Formations planifiées', '${_stats['formations_planifiees'] ?? 0}'],
        ['Formations réalisées', '${_stats['formations_realisees'] ?? 0}'],
      ];

      final villages = _villages.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final villageRows = villages
          .map((entry) => [entry.key, '${entry.value}'])
          .toList();

      final criteria = _criteres.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final criterionRows = criteria
          .map((entry) => [entry.key, '${entry.value}'])
          .toList();

      final activityRows = _activites.map((item) {
        final date = DateTime.tryParse(
          '${item['date_fin'] ?? item['date_debut'] ?? ''}',
        );
        return [
          date == null ? '-' : _dateFormat.format(date),
          '${item['code_phi'] ?? '-'}',
          '${item['nom_producteur'] ?? 'Planteur'}',
          '${item['village'] ?? '-'}',
          '${item['nom_zone'] ?? '-'}',
          _statusLabel(item),
        ];
      }).toList();

      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 34),
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.green700, width: 1.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Image(
                      sogbLogo,
                      height: 34,
                      width: 78,
                      fit: pw.BoxFit.contain,
                    ),
                    pw.SizedBox(width: 12),
                    pw.Text(
                      'RUBBERWAY',
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'SUIVI DES ENQUÊTES RDUE',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.only(top: 7),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey400, width: .5),
              ),
            ),
            child: pw.Text(
              'Page ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ),
          build: (context) => [
            pw.SizedBox(height: 12),
            pw.Text(
              "RAPPORT D'ENQUÊTE RDUE",
              style: pw.TextStyle(
                fontSize: 19,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green900,
              ),
            ),
            pw.SizedBox(height: 9),
            _pdfTable(
              ['Période', 'Zone', 'Émis le'],
              [
                [
                  '${_dateFormat.format(_debut)} au ${_dateFormat.format(_fin)}',
                  reportZoneName,
                  DateFormat('dd/MM/yyyy à HH:mm').format(generatedAt),
                ],
              ],
              flexes: [2, 1.5, 1.5],
            ),
            _pdfSection(
              'Synthèse de l’activité',
              _pdfTable(
                ['Indicateur', 'Résultat'],
                conformities,
                flexes: [4, 1],
              ),
            ),
            _pdfSection(
              'Répartition des enquêtes par village',
              _pdfTable(
                ['Village', 'Nombre d’enquêtes'],
                villageRows,
                flexes: [4, 1],
              ),
            ),
            _pdfSection(
              'Critères de non-conformité relevés',
              _pdfTable(
                ['Critère', 'Nombre de cas'],
                criterionRows,
                flexes: [4, 1],
              ),
            ),
            _pdfSection(
              'Détail des enquêtes de la période',
              _pdfTable(
                [
                  'Date',
                  'Code planteur',
                  'Planteur',
                  'Village',
                  'Zone',
                  'Statut',
                ],
                activityRows,
                flexes: [1, 1.4, 2.2, 1.5, 1.3, 2],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Moniteur : ${agentName.isEmpty ? 'Non renseigné' : agentName}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 6),
                      if (agentSignature != null)
                        pw.SizedBox(
                          height: 48,
                          width: 180,
                          child: pw.Image(
                            agentSignature,
                            fit: pw.BoxFit.contain,
                          ),
                        )
                      else
                        pw.SizedBox(height: 48),
                      pw.Container(width: 220, child: pw.Divider()),
                      pw.Text('Signature de l’agent'),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Validateur : ${validatorName.isEmpty ? 'Non renseigné' : validatorName}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 54),
                      pw.Container(width: 220, child: pw.Divider()),
                      pw.Text('Visa du validateur'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final appDirectory = await getApplicationDocumentsDirectory();
      final reportDirectory = Directory(
        '${appDirectory.path}/Rubberway/Rapports',
      );
      await reportDirectory.create(recursive: true);
      final safeAgentName = (agentName.isEmpty ? 'Agent' : agentName)
          .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_');
      final file = File(
        '${reportDirectory.path}/Rapport_${safeAgentName}_${DateFormat('yyyyMMdd_HHmmss').format(generatedAt)}.pdf',
      );
      await file.writeAsBytes(await document.save(), flush: true);
      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Rapport officiel d’activité RubberWay pour la période du ${_dateFormat.format(_debut)} au ${_dateFormat.format(_fin)}. Choisissez WhatsApp pour l’envoyer.',
        subject:
            'Rapport officiel RubberWay - ${_dateFormat.format(_debut)} au ${_dateFormat.format(_fin)}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de créer le rapport PDF : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _statusLabel(Map<String, dynamic> item) {
    if (item['is_realisee'] == true) {
      return item['is_non_conforme'] == true
          ? 'réalisée, non conforme'
          : 'réalisée, conforme';
    }
    switch ('${item['statut'] ?? ''}') {
      case 'refuse':
        return 'refusée';
      case 'en_attente_pdf':
        return 'en attente du PDF';
      default:
        return 'en cours';
    }
  }

  String _formatOptionalDate(dynamic value) {
    final date = DateTime.tryParse('${value ?? ''}');
    return date == null ? 'Non renseignée' : _dateFormat.format(date);
  }

  Future<void> _ouvrirPdf(String path) async {
    if (!await File(path).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le fichier PDF de cette enquête est introuvable.')),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LecteurPdfPage(path: path)),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  Widget _sectionTitle(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Row(
      children: [
        Icon(icon, color: Colors.green.shade700),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _metric(String title, int value, IconData icon, Color color) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: color.withValues(alpha: .12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 12))),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _breakdownList(Map<String, int> values, {String suffix = ''}) {
    if (values.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Text('Aucune donnée pour cette période.'),
        ),
      );
    }
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final entry in entries.take(8))
            ListTile(
              dense: true,
              title: Text(entry.key),
              trailing: Text('${entry.value}$suffix'),
            ),
        ],
      ),
    );
  }

  Widget _filters() => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(start: true),
                  icon: const Icon(Icons.calendar_month),
                  label: Text('Du ${_dateFormat.format(_debut)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(start: false),
                  icon: const Icon(Icons.event),
                  label: Text('Au ${_dateFormat.format(_fin)}'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Performance et enquêtes'),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                const Text(
                  "Performance de l'agent",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Card(
                  margin: const EdgeInsets.only(top: 8, bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.badge_outlined, color: Colors.green),
                    ),
                    title: Text(
                      _agentName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Zone attribuée : $_zoneName'),
                    trailing: IconButton(
                      tooltip: 'Actualiser les statistiques',
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ),
                ),
                const Text(
                  'Période des enquêtes',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                _filters(),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _sharing ? null : _partagerParWhatsApp,
                    icon: _sharing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf),
                    label: Text(
                      _sharing
                          ? 'Préparation du partage…'
                          : 'Envoyer le rapport PDF par WhatsApp',
                    ),
                  ),
                ),
                const Text(
                  'Le PDF officiel sera créé. Choisissez WhatsApp dans le menu de partage.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                _sectionTitle('Résultats de la période', Icons.insights),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.0,
                  children: [
                    _metric(
                      'Enquêtes démarrées',
                      _stats['total'] ?? 0,
                      Icons.assignment,
                      Colors.blue,
                    ),
                    _metric(
                      'Réalisées avec PDF',
                      _stats['realisees'] ?? 0,
                      Icons.picture_as_pdf,
                      Colors.green,
                    ),
                    _metric(
                      'En cours / attente PDF',
                      _stats['en_cours'] ?? 0,
                      Icons.pending_actions,
                      Colors.orange,
                    ),
                    _metric(
                      'Refusées',
                      _stats['refusees'] ?? 0,
                      Icons.block,
                      Colors.blueGrey,
                    ),
                    _metric(
                      'Conformes',
                      _enquetesConformes,
                      Icons.verified,
                      Colors.teal,
                    ),
                    _metric(
                      'Non conformes',
                      _enquetesNonConformes,
                      Icons.warning_amber,
                      Colors.red,
                    ),
                    _metric(
                      'Formations planifiées',
                      _stats['formations_planifiees'] ?? 0,
                      Icons.event,
                      Colors.deepOrange,
                    ),
                    _metric(
                      'Formations réalisées',
                      _stats['formations_realisees'] ?? 0,
                      Icons.school,
                      Colors.purple,
                    ),
                  ],
                ),
                _performanceSummary(),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child: Icon(Icons.percent, color: Colors.green),
                    ),
                    title: const Text('Taux de conformité'),
                    subtitle: const Text(
                      'Parmi les enquêtes réalisées avec PDF',
                    ),
                    trailing: Text(
                      '$_tauxConformite %',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                _sectionTitle('Enquêtes par village', Icons.location_on),
                _breakdownList(_villages, suffix: ' enquête(s)'),
                _sectionTitle('Critères de non-conformité', Icons.rule),
                _breakdownList(_criteres, suffix: ' cas'),
                _sectionTitle(
                  'Détail des enquêtes (${_activites.length})',
                  Icons.list_alt,
                ),
                if (_activites.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Aucune activité pour cette période.'),
                    ),
                  )
                else
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final item in _activites.take(30))
                          ExpansionTile(
                            leading: Icon(
                              item['is_realisee'] == true
                                  ? (item['is_non_conforme'] == true
                                        ? Icons.warning_amber
                                        : Icons.check_circle)
                                  : Icons.pending_actions,
                              color: item['is_non_conforme'] == true
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            title: Text(
                              '${item['nom_producteur'] ?? 'Planteur'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${item['code_phi'] ?? 'Sans code'} · '
                              '${item['village'] ?? 'Village non renseigné'}\n'
                              '${_statusLabel(item)}',
                            ),
                            trailing: const Icon(Icons.expand_more),
                            childrenPadding: const EdgeInsets.fromLTRB(72, 0, 16, 14),
                            children: [
                              _detailRow('Code enquête', '${item['code_enquete'] ?? '-'}'),
                              _detailRow('Début', _formatOptionalDate(item['date_debut'])),
                              _detailRow('Fin', _formatOptionalDate(item['date_fin'])),
                              _detailRow('Zone', '${item['nom_zone'] ?? _zoneName}'),
                              if ('${item['pdf_path'] ?? ''}'.isNotEmpty)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => _ouvrirPdf('${item['pdf_path']}'),
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: const Text("Consulter le PDF de l'enquête"),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                if (_activites.length > 30)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Les 30 activités les plus récentes sont affichées. Le partage inclut jusqu’à 40 lignes.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  '${_activites.length} enquête(s) de $_agentName pour la période sélectionnée.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
  );
}
