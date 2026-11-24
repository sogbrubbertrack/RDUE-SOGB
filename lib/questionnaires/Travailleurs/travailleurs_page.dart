import 'package:flutter/material.dart';

class TravailleursPage extends StatelessWidget {
  const TravailleursPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Travailleurs")),
      body: const Center(
        child: Text("Début questionnaire Travailleurs"),
      ),
    );
  }
}