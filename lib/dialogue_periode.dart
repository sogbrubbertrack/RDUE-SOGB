import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DialoguePeriode extends StatefulWidget {
  final Function(DateTime, DateTime) onValider;

  const DialoguePeriode({super.key, required this.onValider});

  @override
  State<DialoguePeriode> createState() => _DialoguePeriodeState();
}

class _DialoguePeriodeState extends State<DialoguePeriode> {
  DateTime? _dateDebut;
  DateTime? _dateFin;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  Future<void> _selectDate(BuildContext context, bool isDebut) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sélectionner une période'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date de début
          ListTile(
            title: const Text('Date de début'),
            subtitle: Text(
              _dateDebut != null
                  ? _dateFormat.format(_dateDebut!)
                  : 'Non sélectionnée',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(context, true),
          ),
          const Divider(),

          // Date de fin
          ListTile(
            title: const Text('Date de fin'),
            subtitle: Text(
              _dateFin != null
                  ? _dateFormat.format(_dateFin!)
                  : 'Non sélectionnée',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDate(context, false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ANNULER'),
        ),
        ElevatedButton(
          onPressed: (_dateDebut != null && _dateFin != null)
              ? () {
            widget.onValider(_dateDebut!, _dateFin!);
            Navigator.pop(context);
          }
              : null,
          child: const Text('EXPORTER'),
        ),
      ],
    );
  }
}