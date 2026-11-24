import 'package:flutter/material.dart';

class MenagesPage extends StatelessWidget {
  const MenagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ménages")),
      body: const Center(
        child: Text("Début questionnaire Ménages"),
      ),
    );
  }
}