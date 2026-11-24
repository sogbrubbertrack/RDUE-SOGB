import 'package:flutter/material.dart';

class DroitsFonciersPage extends StatelessWidget {
  const DroitsFonciersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Droits fonciers"),
        backgroundColor: Colors.green,
      ),
      body: const Center(
        child: Text(
          "Début questionnaire Droits fonciers",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}