import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database_helper.dart';
import 'formation_notification_service.dart';

class FormationPage extends StatefulWidget {
  const FormationPage({super.key});

  @override
  State<FormationPage> createState() => _FormationPageState();
}

class _FormationPageState extends State<FormationPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _dateTimeFormat = DateFormat('dd/MM/yyyy à HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await DatabaseHelper.getEnquetesPourFormation();
      rows.sort((a, b) {
        final aCompleted = a['date_formation'] != null;
        final bCompleted = b['date_formation'] != null;
        if (aCompleted != bCompleted) return aCompleted ? 1 : -1;

        final aDate = DateTime.tryParse('${a['date_programmee'] ?? ''}');
        final bDate = DateTime.tryParse('${b['date_programmee'] ?? ''}');
        if (aDate == null) return bDate == null ? 0 : 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });
      if (mounted) setState(() => _items = rows);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _planifier(Map<String, dynamic> item) async {
    final now = DateTime.now();
    final currentDate = DateTime(now.year, now.month, now.day);
    final existingDate = DateTime.tryParse('${item['date_programmee'] ?? ''}');
    final initialDate =
        existingDate != null && !existingDate.isBefore(currentDate)
        ? existingDate
        : currentDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: currentDate,
      lastDate: DateTime(now.year + 3),
      helpText: 'Choisir la date de formation',
      cancelText: 'ANNULER',
      confirmText: 'CHOISIR',
    );
    if (selected == null) return;

    final scheduledDate = DateTime(
      selected.year,
      selected.month,
      selected.day,
      8,
    );
    final reminderAt = scheduledDate.isAfter(now)
        ? scheduledDate
        : now.add(const Duration(seconds: 10));

    try {
      await DatabaseHelper.planifierFormation(
        enqueteId: item['id'] as int,
        dateProgrammee: scheduledDate,
      );
      final permissionGranted =
          await FormationNotificationService.scheduleReminder(
            id: item['id'] as int,
            scheduledAt: reminderAt,
            producerName: '${item['nom_producteur'] ?? 'Planteur'}',
            codePhi: '${item['code_phi'] ?? ''}',
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              permissionGranted
                  ? 'Formation programmée le ${_dateFormat.format(selected)}. Le rappel sera envoyé à 08 h.'
                  : 'Date enregistrée. Autorisez les notifications RubberWay dans les paramètres du téléphone pour recevoir le rappel.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de programmer la formation : $e')),
        );
      }
    }
  }

  Future<void> _markTrained(Map<String, dynamic> item) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final agentName = (prefs.getString('agent_nom') ?? '').trim();
    if (agentName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Le nom de l'agent est introuvable. Complétez d'abord le profil de l'agent.",
            ),
          ),
        );
      }
      return;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _TrainingCompletionDialog(agentName: agentName),
    );
    if (result == null) return;

    try {
      await DatabaseHelper.enregistrerFormation(
        enqueteId: item['id'] as int,
        formateur: agentName,
        remarques: result['resume']!,
      );
      await FormationNotificationService.cancelReminder(item['id'] as int);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’enregistrer la formation : $e')),
        );
      }
    }
  }

  Future<void> _startRetake(Map<String, dynamic> item) async {
    final count = (item['nombre_enquetes_annee'] as num?)?.toInt() ?? 0;
    final firstSurveyDate = DateTime.tryParse('${item['date_debut'] ?? ''}');
    final mayRetake =
        item['date_formation'] != null &&
        count == 1 &&
        firstSurveyDate?.year == DateTime.now().year;
    if (!mayRetake) return;

    await Navigator.pushNamed(
      context,
      '/reprendre-enquete',
      arguments: item['producteur_id'] as int,
    );
    await _load();
  }

  Widget _buildCriteria(List<String> criteria) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Critères à reprendre',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      ...criteria.map(
        (criterion) => Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.deepOrange,
              ),
              const SizedBox(width: 7),
              Expanded(child: Text(criterion)),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildItem(Map<String, dynamic> item) {
    final criteria = (item['criteres_non_conformes'] as List).cast<String>();
    final plannedDate = DateTime.tryParse('${item['date_programmee'] ?? ''}');
    final completedDate = DateTime.tryParse('${item['date_formation'] ?? ''}');
    final completed = completedDate != null;
    final yearCount = (item['nombre_enquetes_annee'] as num?)?.toInt() ?? 0;
    final surveyStart = DateTime.tryParse('${item['date_debut'] ?? ''}');
    final canRetake =
        completed && yearCount == 1 && surveyStart?.year == DateTime.now().year;

    if (completed) {
      return _buildCompletedItem(
        item,
        criteria: criteria,
        completedDate: completedDate,
        yearCount: yearCount,
        canRetake: canRetake,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.person, color: Colors.green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['nom_producteur'] ?? 'Planteur'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${item['code_phi'] ?? ''} · ${item['village'] ?? '-'}',
                      ),
                      Text('Zone : ${item['nom_zone'] ?? '-'}'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(completed, plannedDate != null),
              ],
            ),
            const SizedBox(height: 14),
            _buildCriteria(criteria),
            const Divider(height: 24),
            if (completed) ...[
              Row(
                children: [
                  const Icon(
                    Icons.event_available,
                    color: Colors.green,
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Réalisée le ${_dateTimeFormat.format(completedDate)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if ('${item['formateur'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Formateur : ${item['formateur']}'),
                ),
              if ('${item['remarques'] ?? ''}'.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Résumé de la formation',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('${item['remarques']}'),
                    ],
                  ),
                ),
              if (canRetake) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _startRetake(item),
                    icon: const Icon(Icons.assignment_turned_in_outlined),
                    label: const Text('DÉMARRER LA REPRISE DE L’ENQUÊTE'),
                  ),
                ),
              ] else if (yearCount >= 2)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'La reprise autorisée pour cette année a déjà été effectuée.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ] else ...[
              if (plannedDate != null) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Colors.deepOrange,
                      size: 19,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Programmée le ${_dateFormat.format(plannedDate)} à 08 h',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _planifier(item),
                    icon: Icon(
                      plannedDate == null
                          ? Icons.calendar_month
                          : Icons.edit_calendar,
                    ),
                    label: Text(
                      plannedDate == null ? 'Planifier' : 'Modifier la date',
                    ),
                  ),
                  if (plannedDate != null &&
                      !plannedDate.isAfter(DateTime.now()))
                    FilledButton.icon(
                      onPressed: () => _markTrained(item),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Marquer réalisée'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedItem(
    Map<String, dynamic> item, {
    required List<String> criteria,
    required DateTime completedDate,
    required int yearCount,
    required bool canRetake,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFE8F5E9),
        child: Icon(Icons.person, color: Colors.green),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${item['nom_producteur'] ?? 'Planteur'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          _statusChip(true, item['date_programmee'] != null),
        ],
      ),
      subtitle: Text(
        '${item['code_phi'] ?? ''} · ${item['village'] ?? '-'}\nZone : ${item['nom_zone'] ?? '-'}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 16),
        _buildCriteria(criteria),
        const Divider(height: 24),
        Row(
          children: [
            const Icon(Icons.event_available, color: Colors.green, size: 19),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Réalisée le ${_dateTimeFormat.format(completedDate)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if ('${item['formateur'] ?? ''}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Formateur : ${item['formateur']}'),
          ),
        if ('${item['remarques'] ?? ''}'.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Résumé de la formation',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('${item['remarques']}'),
              ],
            ),
          ),
        if (canRetake) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _startRetake(item),
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: const Text('DÉMARRER LA REPRISE DE L’ENQUÊTE'),
            ),
          ),
        ] else if (yearCount >= 2)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'La reprise autorisée pour cette année a déjà été effectuée.',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    ),
  );

  Widget _statusChip(bool completed, bool planned) {
    final color = completed
        ? Colors.green
        : planned
        ? Colors.blue
        : Colors.orange;
    final text = completed
        ? 'Réalisée'
        : planned
        ? 'Programmée'
        : 'À former';
    return Chip(
      label: Text(text, style: TextStyle(color: color, fontSize: 11)),
      backgroundColor: color.withOpacity(0.10),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Formation des planteurs'),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucune enquête non conforme enregistrée pour une formation.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: _items.length,
              itemBuilder: (context, index) => _buildItem(_items[index]),
            ),
          ),
  );
}

class _TrainingCompletionDialog extends StatefulWidget {
  const _TrainingCompletionDialog({required this.agentName});

  final String agentName;

  @override
  State<_TrainingCompletionDialog> createState() =>
      _TrainingCompletionDialogState();
}

class _TrainingCompletionDialogState extends State<_TrainingCompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _summaryController = TextEditingController();

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({'resume': _summaryController.text.trim()});
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirmer la formation réalisée'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: widget.agentName,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Nom du formateur',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _summaryController,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Résumé de la formation',
                hintText: 'Sujets abordés et mesures à appliquer',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes),
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Saisissez le résumé de la formation.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('ANNULER'),
      ),
      FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.check),
        label: const Text('MARQUER RÉALISÉE'),
      ),
    ],
  );
}
