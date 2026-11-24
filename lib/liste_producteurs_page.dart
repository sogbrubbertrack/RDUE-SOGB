import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class ListeProducteursPage extends StatefulWidget {
  const ListeProducteursPage({super.key});

  @override
  State<ListeProducteursPage> createState() => _ListeProducteursPageState();
}

class _ListeProducteursPageState extends State<ListeProducteursPage> {
  final TextEditingController searchCtrl = TextEditingController();
  List<Map<String, dynamic>> results = [];

  Future<void> rechercher(String value) async {
    if (value.trim().isEmpty) {
      setState(() => results = []);
      return;
    }

    List<Map<String, dynamic>> data;

    if (value.trim().length >= 6) {
      data = await DatabaseHelper.searchByCode(value);

      if (data.isEmpty) {
        data = await DatabaseHelper.searchGlobal(value);
      }
    } else {
      data = await DatabaseHelper.searchGlobal(value);
    }

    setState(() {
      results = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Base des producteurs"),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchCtrl,
              decoration: const InputDecoration(
                labelText: "Rechercher par code ou nom",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: rechercher,
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (_, index) {
                final p = results[index];

                return ListTile(
                  title: Text(p["nom"] ?? ""),
                  subtitle: Text(
                      "Code: ${p["code_phi"]} | ${p["village"]}"),
                  onTap: () {
                    Navigator.pop(context, p);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
