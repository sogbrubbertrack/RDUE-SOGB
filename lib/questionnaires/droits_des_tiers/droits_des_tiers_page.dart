import 'package:flutter/material.dart';

class DroitsDesTiersPage extends StatelessWidget {
  const DroitsDesTiersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Droits des tiers")),
      body: const Center(
        child: Text("Début questionnaire Droits des tiers"),
      ),
    );
  }
}