import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/supabase_auth_service.dart';
import 'data/database_helper.dart';
import 'informations_interlocuteur_page.dart';
import 'main.dart'; // Pour EnqueteDateHeurePage

class InformationsProducteurPage extends StatefulWidget {
  const InformationsProducteurPage({super.key});

  @override
  State<InformationsProducteurPage> createState() =>
      _InformationsProducteurPageState();
}

class _InformationsProducteurPageState
    extends State<InformationsProducteurPage> {
  final _formKey = GlobalKey<FormState>();

  final searchCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final nomCtrl = TextEditingController();
  final contactCtrl = TextEditingController();
  final villageCtrl = TextEditingController();

  List<Map<String, dynamic>> resultats = [];
  List<String> _villagesAutorises = [];
  bool saving = false;
  bool _isSearching = false;
  bool _isSyncingProducers = false;
  int _searchRevision = 0;
  bool _selectionEnCours = false;
  Timer? _debounce;

  // Variable pour stocker l'ID du producteur sélectionné
  int? _producteurId;

  // Variable pour savoir si c'est le producteur qui répond
  bool _estProducteurQuiRepond = true;

  // Contrôleur pour le choix OUI/NON
  String? _repondantChoice;

  // Couleurs professionnelles
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color accentOrange = Color(0xFFFF6F00);
  static const Color greyBackground = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _chargerVillagesAutorises();
  }

  Future<void> _chargerVillagesAutorises() async {
    final villages = await DatabaseHelper.assignedVillages;
    if (mounted) setState(() => _villagesAutorises = villages);
  }

  Future<void> _actualiserProducteurs() async {
    setState(() => _isSyncingProducers = true);
    try {
      await SupabaseAuthService.refreshSectionProducers();
      await _chargerVillagesAutorises();
      if (mounted && !_selectionEnCours) {
        _debounce?.cancel();
        await _chargerResultats(
          searchCtrl.text.trim(),
          ++_searchRevision,
          listWhenEmpty: true,
        );
      }
    } catch (error) {
      debugPrint('Actualisation des producteurs impossible : $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La synchronisation a échoué. Réessayez.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncingProducers = false);
    }
  }

  Future<void> _chargerPreferencesProducteur(int producteurId) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _estProducteurQuiRepond = prefs.getBool("INTERLOC_EST_PRODUCTEUR_$producteurId") ?? true;
      // Si l'interlocuteur a déjà été renseigné, on présélectionne "NON"
      if (!_estProducteurQuiRepond) {
        _repondantChoice = 'NON';
      } else {
        _repondantChoice = null; // On laisse l'utilisateur choisir
      }
    });
  }

  void _rechercher(String value) {
    if (_selectionEnCours) return;
    _debounce?.cancel();
    final revision = ++_searchRevision;
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _chargerResultats(value.trim(), revision);
    });
  }

  Future<void> _chargerResultats(
    String value,
    int revision, {
    bool listWhenEmpty = false,
  }) async {
    if (!mounted || _selectionEnCours || revision != _searchRevision) return;
    if (value.length < 2 && !(value.isEmpty && listWhenEmpty)) {
      setState(() {
        resultats = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await DatabaseHelper.searchGlobal(value);
      if (!mounted || _selectionEnCours || revision != _searchRevision) return;
      setState(() => resultats = results);
    } catch (error) {
      debugPrint('Recherche des producteurs impossible : $error');
      if (!mounted || revision != _searchRevision) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lire la liste des producteurs.')),
      );
    } finally {
      if (mounted && revision == _searchRevision) {
        setState(() => _isSearching = false);
      }
    }
  }

  // ✅ Sélection d'un producteur avec normalisation du contact
  void _selectionnerProducteur(Map<String, dynamic> p) {
    _selectionEnCours = true;

    _producteurId = p['id'];

    codeCtrl.text = p['code_phi'] ?? '';
    searchCtrl.clear();
    nomCtrl.text = p['nom'] ?? '';

    // 🔴 NORMALISATION À L'AFFICHAGE
    contactCtrl.text = DatabaseHelper.normalizeIvorianPhone(p['contact'] ?? '');

    villageCtrl.text = p['village'] ?? '';

    setState(() {
      resultats = [];
      _isSearching = false;
      _repondantChoice = null; // Réinitialiser le choix
    });

    // Charger les préférences pour ce producteur
    _chargerPreferencesProducteur(_producteurId!);

    // Feedback visuel de sélection
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Producteur "${p['nom']}" sélectionné'),
        backgroundColor: primaryGreen,
        duration: const Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      _selectionEnCours = false;
    });
  }

  // ✅ Fonction pour accéder à la page interlocuteur
  Future<void> _allerVersInterlocuteur() async {
    if (_producteurId == null || _producteurId! <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez d'abord sélectionner un producteur"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("INTERLOC_EST_PRODUCTEUR_${_producteurId!}", false);

    setState(() {
      _estProducteurQuiRepond = false;
    });

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InformationsInterlocuteurPage(
            producteurId: _producteurId!,
            onRetour: () {
              // Recharger la préférence quand on revient
              _chargerPreferencesProducteur(_producteurId!);
            },
          ),
        ),
      );
    }
  }

  // ✅ Fonction CONTINUER - maintenant gère le choix
  Future<void> _continuer() async {
    if (!_formKey.currentState!.validate()) return;

    // Vérifier qu'un choix a été fait
    if (_repondantChoice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez indiquer si c'est le producteur qui répond"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ Validation du format du numéro de téléphone
    final normalizedContact = DatabaseHelper.normalizeIvorianPhone(contactCtrl.text);
    if (normalizedContact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Numéro de téléphone invalide"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mettre à jour le champ avec le numéro normalisé
    contactCtrl.text = normalizedContact;

    setState(() => saving = true);
    try {
      _producteurId ??= await DatabaseHelper.createProducteur(
        codePhi: codeCtrl.text.trim(),
        nom: nomCtrl.text.trim(),
        contact: contactCtrl.text.trim(),
        village: villageCtrl.text.trim(),
      );
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’enregistrer le planteur : $error')),
        );
      }
      return;
    }


    final prefs = await SharedPreferences.getInstance();

    // Sauvegarder les infos du producteur
    await prefs.setString("PROD_CODE_PHI", codeCtrl.text.trim());
    await prefs.setString("PROD_NOM", nomCtrl.text.trim());
    await prefs.setString("PROD_CONTACT", contactCtrl.text.trim());
    await prefs.setString("PROD_VILLAGE", villageCtrl.text.trim());

    // Sauvegarder le choix du répondant
    bool estProducteurQuiRepond = _repondantChoice == 'OUI';
    await prefs.setBool("INTERLOC_EST_PRODUCTEUR_${_producteurId!}", estProducteurQuiRepond);

    debugPrint("✅ PRODUCTEUR ENREGISTRÉ - ID: $_producteurId");
    debugPrint("✅ C'EST LE PRODUCTEUR QUI RÉPOND: $estProducteurQuiRepond");

    setState(() => saving = false);

    if (mounted) {
      if (estProducteurQuiRepond) {
        // Si c'est le producteur qui répond, on continue directement
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EnqueteDateHeurePage(
              producteurId: _producteurId!,
            ),
          ),
        );
      } else {
        // Si c'est l'interlocuteur, on ouvre la page interlocuteur
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InformationsInterlocuteurPage(
              producteurId: _producteurId!,
              onRetour: () {
                // Après avoir enregistré l'interlocuteur, on continue
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EnqueteDateHeurePage(
                      producteurId: _producteurId!,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchCtrl.dispose();
    codeCtrl.dispose();
    nomCtrl.dispose();
    contactCtrl.dispose();
    villageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: greyBackground,
      appBar: AppBar(
        title: const Text(
          "Informations Producteur",
          style: TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
        ),
        backgroundColor: primaryGreen,
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
                // En-tête de section RECHERCHE
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "RECHERCHE PRODUCTEUR",
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

                // Champ de recherche stylisé
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextFormField(
                    controller: searchCtrl,
                    decoration: InputDecoration(
                      labelText: "Rechercher un planteur déjà enquêté",
                      hintText: "Saisissez au moins 2 caractères",
                      prefixIcon: const Icon(Icons.search, color: primaryGreen),
                      suffixIcon: _isSearching
                          ? Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.all(12),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                        ),
                      )
                          : (searchCtrl.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          searchCtrl.clear();
                          _debounce?.cancel();
                          _searchRevision++;
                          setState(() => resultats = []);
                        },
                      )
                          : null),
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
                        borderSide: BorderSide(color: primaryGreen, width: 1.5),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onChanged: (value) {
                      if (_producteurId != null) {
                        setState(() {
                          _producteurId = null;
                          codeCtrl.clear();
                          nomCtrl.clear();
                          contactCtrl.clear();
                          villageCtrl.clear();
                          _repondantChoice = null;
                        });
                      }
                      _rechercher(value);
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // Indicateur de recherche
                if (searchCtrl.text.isNotEmpty && searchCtrl.text.length < 2)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: Text(
                      "Saisissez au moins 2 caractères pour lancer la recherche",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Résultats de recherche
                if (resultats.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          "RÉSULTATS (${resultats.length})",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: resultats.length,
                        itemBuilder: (_, i) {
                          final p = resultats[i];
                          return InkWell(
                            onTap: () => _selectionnerProducteur(p),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: lightGreen,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        (p['nom'] ?? '?')[0].toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: primaryGreen,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['nom'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${p['village'] ?? ''} • ${p['code_phi'] ?? ''}",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _isSyncingProducers ? null : _actualiserProducteurs,
                    icon: const Icon(Icons.sync),
                    label: Text(_isSyncingProducers
                        ? 'Synchronisation en cours…'
                        : 'Synchroniser avec la plateforme'),
                  ),
                ),
                if (!_isSyncingProducers &&
                    SupabaseAuthService.producerSyncMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(SupabaseAuthService.producerSyncMessage!),
                  ),
                if (searchCtrl.text.trim().length >= 2 &&
                    resultats.isEmpty &&
                    !_isSearching)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 16),
                    child: Text(
                      "Aucun planteur trouvé sur cet appareil. Vous pouvez saisir ses informations ci-dessous.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),

                // En-tête de section Formulaire
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          color: primaryGreen,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "INFORMATIONS PRODUCTEUR",
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

                // Champs du formulaire stylisés
                _buildStyledTextField(
                  controller: codeCtrl,
                  label: "Code PHI",
                  icon: Icons.badge_outlined,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? "Code PHI requis"
                      : null,
                ),

                const SizedBox(height: 16),

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
                  validator: (v) => v == null || v.isEmpty ? "Requis" : null,
                ),

                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _villagesAutorises.contains(villageCtrl.text)
                      ? villageCtrl.text
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Village de la section',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _villagesAutorises
                      .map((village) => DropdownMenuItem(
                            value: village,
                            child: Text(village, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: _villagesAutorises.isEmpty
                      ? null
                      : (value) => setState(() => villageCtrl.text = value ?? ''),
                  validator: (value) => value == null || value.isEmpty
                      ? (_villagesAutorises.isEmpty
                          ? 'Aucun village attribué à votre compte.'
                          : 'Choisissez un village de votre section.')
                      : null,
                ),

                const SizedBox(height: 20),

                // ✅ NOUVELLE SECTION : CHOIX DU RÉPONDANT
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
                          "QUI RÉPOND AU QUESTIONNAIRE ?",
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

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                      children: [
                        // Option OUI (Producteur lui-même)
                        RadioListTile<String>(
                          title: Row(
                            children: [
                              Icon(Icons.person, color: primaryGreen, size: 22),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  "Le producteur lui-même",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: const Padding(
                            padding: EdgeInsets.only(left: 34),
                            child: Text(
                              "Le producteur répond directement aux questions",
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          value: 'OUI',
                          groupValue: _repondantChoice,
                          onChanged: (value) {
                            setState(() {
                              _repondantChoice = value;
                            });
                          },
                          activeColor: primaryGreen,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),

                        const Divider(height: 1, indent: 56, endIndent: 16),

                        // Option NON (Interlocuteur)
                        RadioListTile<String>(
                          title: Row(
                            children: [
                              Icon(Icons.group, color: accentOrange, size: 22),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  "Un interlocuteur",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: const Padding(
                            padding: EdgeInsets.only(left: 34),
                            child: Text(
                              "Une autre personne répond à la place du producteur",
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                          value: 'NON',
                          groupValue: _repondantChoice,
                          onChanged: (value) {
                            setState(() {
                              _repondantChoice = value;
                            });
                          },
                          activeColor: accentOrange,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Message d'information selon le choix
                  if (_repondantChoice == 'NON')
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentOrange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: accentOrange, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Vous serez redirigé vers le formulaire de l'interlocuteur après avoir cliqué sur CONTINUER",
                              style: TextStyle(
                                fontSize: 13,
                                color: accentOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                // Bouton CONTINUER stylisé
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: saving ? null : _continuer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shadowColor: primaryGreen.withOpacity(0.3),
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
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryGreen, size: 22),
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
            borderSide: BorderSide(color: primaryGreen, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        validator: validator,
      ),
    );
  }
}
