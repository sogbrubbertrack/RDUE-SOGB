import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importer la page EnqueteDateHeurePage
import 'main.dart'; // Pour EnqueteDateHeurePage

class InformationsInterlocuteurPage extends StatefulWidget {
  final int producteurId;
  final VoidCallback? onRetour;

  const InformationsInterlocuteurPage({
    super.key,
    required this.producteurId,
    this.onRetour,
  });

  @override
  State<InformationsInterlocuteurPage> createState() =>
      _InformationsInterlocuteurPageState();
}

class _InformationsInterlocuteurPageState
    extends State<InformationsInterlocuteurPage> {
  final _formKey = GlobalKey<FormState>();

  final nomCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final lienCtrl = TextEditingController();

  bool saving = false;

  // Clés pour SharedPreferences avec préfixe producteur
  String get _prefKeyNom => 'INTERLOC_NOM_${widget.producteurId}';
  String get _prefKeyContact => 'INTERLOC_CONTACT_${widget.producteurId}';
  String get _prefKeyLien => 'INTERLOC_LIEN_${widget.producteurId}';
  String get _prefKeyEstProducteur => 'INTERLOC_EST_PRODUCTEUR_${widget.producteurId}';

  // Couleurs professionnelles
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color accentOrange = Color(0xFFFF6F00);
  static const Color greyBackground = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _chargerPreferences();
  }

  Future<void> _chargerPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      nomCtrl.text = prefs.getString(_prefKeyNom) ?? "";
      contactCtrl.text = prefs.getString(_prefKeyContact) ?? "";
      lienCtrl.text = prefs.getString(_prefKeyLien) ?? "";
    });
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => saving = true);

    final prefs = await SharedPreferences.getInstance();

    // Sauvegarder avec des clés spécifiques au producteur
    await prefs.setString(_prefKeyNom, nomCtrl.text.trim());
    await prefs.setString(_prefKeyContact, contactCtrl.text.trim());
    await prefs.setString(_prefKeyLien, lienCtrl.text.trim());
    await prefs.setBool(_prefKeyEstProducteur, false);

    setState(() => saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Interlocuteur enregistré avec succès"),
          backgroundColor: primaryGreen,
        ),
      );

      // ✅ Rediriger vers EnqueteDateHeurePage après enregistrement
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EnqueteDateHeurePage(
            producteurId: widget.producteurId,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    nomCtrl.dispose();
    contactCtrl.dispose();
    lienCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: greyBackground,
      appBar: AppBar(
        title: const Text(
          "Informations Interlocuteur",
          style: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
        ),
        backgroundColor: accentOrange,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête d'information
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentOrange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: accentOrange, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Interlocuteur",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: accentOrange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Renseignez les informations de la personne qui répond aux questions si ce n'est pas le producteur lui-même",
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF424242),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // En-tête de section
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: accentOrange,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "INFORMATIONS INTERLOCUTEUR",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                          color: Color(0xFF424242),
                        ),
                      ),
                    ],
                  ),
                ),

                // Champs du formulaire
                _buildStyledTextField(
                  controller: nomCtrl,
                  label: "Nom complet",
                  icon: Icons.person_outline,
                  validator: (v) => v == null || v.isEmpty ? "Requis" : null,
                ),

                const SizedBox(height: 16),

                _buildStyledTextField(
                  controller: contactCtrl,
                  label: "Contact",
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  helperText: "Format: 0708091011 ou +2250708091011",
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Requis";
                    // Validation simple du numéro ivoirien
                    final normalized = v.replaceAll(RegExp(r'[^0-9]'), '');
                    if (normalized.length != 10 && normalized.length != 12) {
                      return "Format invalide";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                _buildStyledTextField(
                  controller: lienCtrl,
                  label: "Lien avec le producteur",
                  icon: Icons.people_outline,
                  hintText: "Ex: Époux, Fils, Employé, etc.",
                  validator: (v) => v == null || v.isEmpty ? "Requis" : null,
                ),

                const SizedBox(height: 30),

                // Bouton ENREGISTRER
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: saving ? null : _enregistrer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentOrange,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: accentOrange.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: saving
                        ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "ENREGISTREMENT...",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    )
                        : const Text(
                      "CONTINUER",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget personnalisé pour les champs de texte stylisés
  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? hintText,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              labelText: label,
              hintText: hintText,
              helperText: helperText,
              prefixIcon: Icon(icon, color: accentOrange, size: 22),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentOrange, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            validator: validator,
          ),
        ],
      ),
    );
  }
}