import 'package:flutter/material.dart';
import 'package:rubberway/data/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
class DebugDatabasePage extends StatefulWidget {
  final int? enqueteId; // Optionnel : pour filtrer une enquête spécifique

  const DebugDatabasePage({super.key, this.enqueteId});

  @override
  State<DebugDatabasePage> createState() => _DebugDatabasePageState();
}

class _DebugDatabasePageState extends State<DebugDatabasePage> {
  bool _loading = false;
  String? _errorMessage;

  // Données
  List<Map<String, dynamic>> _enquetes = [];
  List<Map<String, dynamic>> _reponses = [];
  List<Map<String, dynamic>> _producteurs = [];
  List<Map<String, dynamic>> _questions = [];
  List<Map<String, dynamic>> _photos = [];

  // Statistiques
  Map<String, int> _stats = {};

  // Contrôleurs pour les requêtes SQL personnalisées
  final TextEditingController _sqlController = TextEditingController();
  List<Map<String, dynamic>> _sqlResults = [];
  bool _showSqlResults = false;

  @override
  void initState() {
    super.initState();
    _chargerToutesLesDonnees();
  }

  @override
  void dispose() {
    _sqlController.dispose();
    super.dispose();
  }

  Future<void> _chargerToutesLesDonnees() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final db = await DatabaseHelper.database;

      // Compter les enregistrements dans chaque table
      _stats = {
        'enquetes': Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM enquetes')) ?? 0,
        'reponses': Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM reponses')) ?? 0,
        'producteurs': Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM producteurs')) ?? 0,
        'questions': Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM questions')) ?? 0,
        'photos': Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM photos')) ?? 0,
        'enqueteurs': Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM enqueteurs')) ?? 0,
        'zones': Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM zones')) ?? 0,
      };

      // Récupérer les données
      if (widget.enqueteId != null) {
        // Si une enquête spécifique est demandée
        _enquetes = await db.query(
          'enquetes',
          where: 'id = ?',
          whereArgs: [widget.enqueteId],
        );

        _reponses = await db.query(
          'reponses',
          where: 'enquete_id = ?',
          whereArgs: [widget.enqueteId],
          orderBy: 'date_reponse DESC',
        );

        // Récupérer les infos du producteur
        if (_enquetes.isNotEmpty) {
          final producteurId = _enquetes.first['producteur_id'];
          _producteurs = await db.query(
            'producteurs',
            where: 'id = ?',
            whereArgs: [producteurId],
          );
        }
      } else {
        // Sinon, charger tout avec limite
        _enquetes = await db.query('enquetes', orderBy: 'date_debut DESC', limit: 20);
        _reponses = await db.query('reponses', orderBy: 'date_reponse DESC', limit: 50);
        _producteurs = await db.query('producteurs', limit: 20);
      }

      // Charger les questions
      _questions = await db.query('questions', limit: 50);

      // Charger les photos récentes
      _photos = await db.query('photos', orderBy: 'date_prise DESC', limit: 20);

      setState(() {
        _loading = false;
      });

      _showSuccessMessage('Données chargées avec succès');

    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _executerRequeteSQL() async {
    final sql = _sqlController.text.trim();
    if (sql.isEmpty) {
      _showErrorMessage('Veuillez entrer une requête SQL');
      return;
    }

    setState(() {
      _loading = true;
      _showSqlResults = true;
    });

    try {
      final db = await DatabaseHelper.database;
      _sqlResults = await db.rawQuery(sql);

      setState(() {
        _loading = false;
      });

      _showSuccessMessage('Requête exécutée: ${_sqlResults.length} résultats');

    } catch (e) {
      setState(() {
        _loading = false;
        _sqlResults = [];
      });
      _showErrorMessage('Erreur SQL: $e');
    }
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ $message'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.enqueteId != null
            ? '🔍 Enquête #${widget.enqueteId}'
            : '🔍 Debug Base de Données'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerToutesLesDonnees,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: _loading && _enquetes.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorWidget()
            : _buildContent(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Erreur: $_errorMessage',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _chargerToutesLesDonnees,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('RÉESSAYER'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatsCards(),
        const SizedBox(height: 20),

        // Requête SQL personnalisée
        _buildSqlQuerySection(),
        const SizedBox(height: 20),

        // Résultats SQL si affichés
        if (_showSqlResults) ...[
          _buildSqlResults(),
          const SizedBox(height: 20),
        ],

        // Enquêtes
        _buildSectionTitle('ENQUÊTES (${_enquetes.length})', Icons.assignment),
        ..._enquetes.map((e) => _buildEnqueteCard(e)).toList(),

        const SizedBox(height: 16),

        // Réponses
        _buildSectionTitle('RÉPONSES (${_reponses.length})', Icons.question_answer),
        ..._reponses.take(20).map((r) => _buildReponseCard(r)).toList(),
        if (_reponses.length > 20)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '... et ${_reponses.length - 20} autres réponses',
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ),

        const SizedBox(height: 16),

        // Producteurs
        _buildSectionTitle('PRODUCTEURS (${_producteurs.length})', Icons.person),
        ..._producteurs.map((p) => _buildProducteurCard(p)).toList(),

        const SizedBox(height: 16),

        // Questions
        _buildSectionTitle('QUESTIONS (${_questions.length})', Icons.help),
        ..._questions.take(10).map((q) => _buildQuestionCard(q)).toList(),
        if (_questions.length > 10)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('... et plus', style: TextStyle(fontStyle: FontStyle.italic)),
          ),

        const SizedBox(height: 16),

        // Photos
        if (_photos.isNotEmpty) ...[
          _buildSectionTitle('PHOTOS (${_photos.length})', Icons.photo),
          ..._photos.map((p) => _buildPhotoCard(p)).toList(),
        ],

        const SizedBox(height: 30),

        // Boutons d'actions
        _buildActionButtons(),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'STATISTIQUES',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _stats.entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    '${entry.key}: ${entry.value}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade800,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSqlQuerySection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'REQUÊTE SQL PERSONNALISÉE',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sqlController,
              decoration: InputDecoration(
                hintText: 'Ex: SELECT * FROM reponses WHERE question_id = "12"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.play_arrow, color: Colors.green),
                  onPressed: _executerRequeteSQL,
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _sqlController.text = 'SELECT * FROM reponses ORDER BY date_reponse DESC LIMIT 10';
                    },
                    child: const Text('Dernières réponses'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      _sqlController.text = 'SELECT * FROM enquetes WHERE statut = "en_cours"';
                    },
                    child: const Text('Enquêtes en cours'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSqlResults() {
    if (_sqlResults.isEmpty) {
      return const Card(
        color: Colors.orange,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Aucun résultat'),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RÉSULTATS (${_sqlResults.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sqlResults.length,
                itemBuilder: (context, index) {
                  final result = _sqlResults[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: result.entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    '${e.key}:',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    e.value?.toString() ?? 'null',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade800),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnqueteCard(Map<String, dynamic> enquete) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: enquete['statut'] == 'termine'
              ? Colors.green
              : Colors.orange,
          radius: 12,
          child: Text(
            enquete['id'].toString(),
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        ),
        title: Text('Enquête #${enquete['id']}'),
        subtitle: Text(
          'Début: ${_formatDate(enquete['date_debut'])} | Statut: ${enquete['statut']}',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Code enquête', enquete['code_enquete']),
                _buildInfoRow('Producteur ID', enquete['producteur_id']),
                _buildInfoRow('Enquêteur ID', enquete['enqueteur_id']),
                _buildInfoRow('Zone ID', enquete['zone_id']),
                _buildInfoRow('Date fin', _formatDate(enquete['date_fin'])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReponseCard(Map<String, dynamic> reponse) {
    // Trouver la question correspondante
    final question = _questions.firstWhere(
          (q) => q['id'] == reponse['question_id'],
      orElse: () => {},
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.grey.shade50,
      child: ListTile(
        leading: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              reponse['id'].toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        title: Text(
          question['code_question'] ?? reponse['question_id'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reponse['code_reponse'] != null)
              Text('Code: ${reponse['code_reponse']}'),
            if (reponse['valeur'] != null && reponse['valeur'].toString().isNotEmpty)
              Text('Valeur: ${reponse['valeur']}'),
            if (reponse['precision_text'] != null)
              Text('Précision: ${reponse['precision_text']}',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            Text(_formatDate(reponse['date_reponse']),
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildProducteurCard(Map<String, dynamic> producteur) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(producteur['nom'] ?? 'Sans nom'),
        subtitle: Text('Code PHI: ${producteur['code_phi']}'),
        trailing: Text('ID: ${producteur['id']}'),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              question['numero']?.toString() ?? '?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        title: Text(question['code_question'] ?? ''),
        subtitle: Text(
          question['texte'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(question['type'] ?? ''),
      ),
    );
  }

  Widget _buildPhotoCard(Map<String, dynamic> photo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: const Icon(Icons.photo, color: Colors.amber),
        title: Text('Photo #${photo['id']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Réponse ID: ${photo['reponse_id']}'),
            Text('Chemin: ${photo['chemin']}',
                style: const TextStyle(fontSize: 10)),
            Text(_formatDate(photo['date_prise']),
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? '—',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () async {
              final dbPath = await _getDatabasePath();
              _showErrorMessage('Chemin: $dbPath');
            },
            icon: const Icon(Icons.info),
            label: const Text('Chemin BD'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showExportOptions,
            icon: const Icon(Icons.download),
            label: const Text('Exporter CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Future<String> _getDatabasePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/rubberway.db';
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Exporter les données',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.blue),
                title: const Text('Toutes les données'),
                onTap: () {
                  Navigator.pop(context);
                  _exporterCSV();
                },
              ),
              if (widget.enqueteId != null)
                ListTile(
                  leading: const Icon(Icons.assignment, color: Colors.green),
                  title: Text('Enquête #${widget.enqueteId}'),
                  onTap: () {
                    Navigator.pop(context);
                    _exporterEnquete(widget.enqueteId!);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exporterCSV() async {
    // À implémenter avec votre ExportCsvService
    _showErrorMessage('Fonction à connecter avec ExportCsvService');
  }

  Future<void> _exporterEnquete(int enqueteId) async {
    // À implémenter avec votre ExportCsvService
    _showErrorMessage('Fonction à connecter avec ExportCsvService');
  }
}