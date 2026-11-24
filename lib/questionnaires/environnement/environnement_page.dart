import 'package:flutter/material.dart';

class EnvironnementPage extends StatelessWidget {
  const EnvironnementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Environnement")),
      body: const Center(
        child: Text("Début questionnaire Environnement"),
      ),
    );
  }
}