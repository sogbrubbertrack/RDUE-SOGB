import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'auth/login_page.dart';
import 'auth/supabase_auth_service.dart';

// Imports des pages
import 'enregistrement_validateur_page.dart';
import 'tableau_de_bord_page.dart';
import 'resume_refus_page.dart';

// Imports pour la base de données et les questionnaires
import 'data/database_helper.dart';
import 'questionnaires/questionnaire_start_page.dart' as questionnaire;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.database;
  await initRubberwayFolderOnce();
  runApp(const RubberWayApp());
}

class RubberWayApp extends StatelessWidget {
  const RubberWayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "RUBBERWAY - Gestion des enquêtes RDUE",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      locale: const Locale('fr', 'FR'),
      home: const AuthGate(),
      onGenerateRoute: (settings) {
        if (settings.name == '/reprendre-enquete') {
          final producteurId = settings.arguments as int;
          return MaterialPageRoute(
            builder: (_) => EnqueteDateHeurePage(producteurId: producteurId),
          );
        }
        return null;
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    rubberwayAuthenticated.addListener(_onAuthenticationChanged);
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    var authenticated = false;
    try {
      authenticated = await SupabaseAuthService.restoreSession();
    } catch (error) {
      debugPrint('Restauration de session impossible : $error');
    }
    if (!mounted) return;
    rubberwayAuthenticated.value = authenticated;
    setState(() => _loading = false);
  }

  void _onAuthenticationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    rubberwayAuthenticated.removeListener(_onAuthenticationChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }
    if (rubberwayAuthenticated.value) return const StartPage();
    return LoginPage(
      onAuthenticated: () => rubberwayAuthenticated.value = true,
    );
  }
}

// ===============================
// PAGE DE DÉMARRAGE
// ===============================
class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  Future<int> _etatApp() async {
    final prefs = await SharedPreferences.getInstance();
    final agentExiste = prefs.containsKey("agent_nom");
    final validateurExiste = prefs.containsKey("VALIDATEUR_NOM");
    if (!agentExiste) return 0;
    final signatureAgent = prefs.getString('agent_signature_path');
    if (signatureAgent == null || !await File(signatureAgent).exists()) {
      return 3;
    }
    if (!validateurExiste) return 1;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _etatApp(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == 0) {
          return const AgentRegisterPage();
        } else if (snapshot.data == 3) {
          return const AgentRegisterPage(updateExisting: true);
        } else if (snapshot.data == 1) {
          return const EnregistrementValidateurPage();
        } else {
          return const TableauDeBordPage();
        }
      },
    );
  }
}

// ===============================
// PAGE 1 : ENREGISTREMENT AGENT
// ===============================
class AgentRegisterPage extends StatefulWidget {
  final bool updateExisting;

  const AgentRegisterPage({super.key, this.updateExisting = false});

  @override
  State<AgentRegisterPage> createState() => _AgentRegisterPageState();
}

class _AgentRegisterPageState extends State<AgentRegisterPage> {
  final _nomController = TextEditingController();
  final _contactController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  String fonction = "Moniteur";
  String zone = "MEAGUI";
  bool saving = false;
  bool _loadingProfile = false;

  final List<String> fonctions = [
    "Moniteur",
    "Contrôleur",
    "Vérificateur de pesée",
    "Surveillant DAMP",
    "Chef-secteur",
    "DEPV",
    "DAMP",
  ];

  final List<String> zones = [
    "GABIADJI",
    "MEAGUI",
    "TABOU",
    "OLODIO",
    "GRABO",
    "DJOUROUTOU",
    "KLOTOU",
    "DOGBO",
    "GRAND-BEREBY",
    "DOBA",
    "LOBAKOUYA",
    "GNANMANGUI",
    "OUPOYO",
    "BALOKOUYA",
    "GRIHIRI",
    "MENEKE",
    "ADJAMENE",
    "DJAMADJOKE",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.updateExisting) {
      _loadingProfile = true;
      _chargerProfilExistant();
    } else {
      _chargerNomCompteConnecte();
    }
  }

  Future<void> _chargerNomCompteConnecte() async {
    final savedAgentName = await SupabaseAuthService.savedAgentName;
    if (!mounted || savedAgentName == null || savedAgentName.trim().isEmpty) {
      return;
    }
    setState(() => _nomController.text = savedAgentName.trim());
  }

  Future<void> _chargerProfilExistant() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _nomController.text = prefs.getString('agent_nom') ?? '';
    _contactController.text = prefs.getString('agent_contact') ?? '';
    final savedFunction = prefs.getString('agent_fonction');
    final savedZone = prefs.getString('agent_zone');
    setState(() {
      if (savedFunction != null && fonctions.contains(savedFunction)) {
        fonction = savedFunction;
      }
      if (savedZone != null && zones.contains(savedZone)) zone = savedZone;
      _loadingProfile = false;
    });
  }

  Future<void> _enregistrerAgent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez enregistrer la signature de l'agent."),
        ),
      );
      return;
    }
    setState(() => saving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final nomComplet = _nomController.text.trim();
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes == null) {
        throw Exception("Impossible de générer la signature de l'agent.");
      }
      final appDir = await getApplicationDocumentsDirectory();
      final signatureDir = Directory('${appDir.path}/signatures');
      if (!await signatureDir.exists()) {
        await signatureDir.create(recursive: true);
      }
      final signatureFile = File(
        '${signatureDir.path}/signature_agent_profil.png',
      );
      await signatureFile.writeAsBytes(signatureBytes, flush: true);

      await prefs.setString("agent_nom", nomComplet);
      await prefs.setString("agent_contact", _contactController.text.trim());
      await prefs.setString("agent_fonction", fonction);
      await prefs.setString("agent_zone", zone);
      await prefs.setString('agent_signature_path', signatureFile.path);

      if (!widget.updateExisting) {
        final parts = nomComplet.split(' ');
        await DatabaseHelper.saveEnqueteur(
          codeEnqueteur: "ENQ${DateTime.now().millisecondsSinceEpoch}",
          nom: parts.length > 1 ? parts.last : nomComplet,
          prenom: parts.first,
          telephone: _contactController.text.trim(),
        );
      }

      if (mounted) {
        final validateurExiste = prefs.containsKey('VALIDATEUR_NOM');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => validateurExiste
                ? const TableauDeBordPage()
                : const EnregistrementValidateurPage(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/fond_dashboard.jpg",
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withOpacity(0.2)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          "assets/images/logo_rubberway.jpg",
                          height: 100,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "ENREGISTREMENT AGENT",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        TextFormField(
                          controller: _nomController,
                          decoration: InputDecoration(
                            labelText: "Nom et prénom",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.person),
                          ),
                          validator: (v) =>
                              v?.isEmpty ?? true ? "Requis" : null,
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _contactController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: "Contact",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.phone),
                          ),
                          validator: (v) =>
                              v?.isEmpty ?? true ? "Requis" : null,
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: fonction,
                          items: fonctions
                              .map(
                                (f) =>
                                    DropdownMenuItem(value: f, child: Text(f)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => fonction = v!),
                          decoration: InputDecoration(
                            labelText: "Fonction",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.work),
                          ),
                        ),
                        const SizedBox(height: 12),

                        DropdownButtonFormField<String>(
                          value: zone,
                          items: zones
                              .map(
                                (z) =>
                                    DropdownMenuItem(value: z, child: Text(z)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => zone = v!),
                          decoration: InputDecoration(
                            labelText: "Zone",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.map),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Signature de l'agent",
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Signature(
                              controller: _signatureController,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: saving
                                ? null
                                : _signatureController.clear,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Effacer la signature'),
                          ),
                        ),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: saving ? null : _enregistrerAgent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    "CONTINUER",
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _contactController.dispose();
    _signatureController.dispose();
    super.dispose();
  }
}

// ===============================
// INIT DOSSIER RUBBERWAY
// ===============================
Future<void> initRubberwayFolderOnce() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool("RUBBERWAY_DIR_CREATED") == true) return;

  final dir = await getApplicationDocumentsDirectory();
  final rubberwayDir = Directory("${dir.path}/Rubberway");
  if (!await rubberwayDir.exists()) await rubberwayDir.create(recursive: true);

  await Directory("${rubberwayDir.path}/df").create(recursive: true);
  await Directory("${rubberwayDir.path}/env").create(recursive: true);
  await Directory("${rubberwayDir.path}/dt").create(recursive: true);
  await Directory("${rubberwayDir.path}/men").create(recursive: true);
  await Directory("${rubberwayDir.path}/trav").create(recursive: true);
  await Directory("${rubberwayDir.path}/rev").create(recursive: true);

  await prefs.setBool("RUBBERWAY_DIR_CREATED", true);
}

// ===============================
// PAGE : DATE & HEURE DE L'ENQUÊTE
// ===============================
class EnqueteDateHeurePage extends StatefulWidget {
  final int producteurId;

  const EnqueteDateHeurePage({super.key, required this.producteurId});

  @override
  State<EnqueteDateHeurePage> createState() => _EnqueteDateHeurePageState();
}

class _EnqueteDateHeurePageState extends State<EnqueteDateHeurePage> {
  String dateStr = "", heureStr = "";
  int? _enqueteId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _enregistrerDateHeure();
    await _creerEnquete();
    setState(() => _isLoading = false);
  }

  Future<void> _enregistrerDateHeure() async {
    final now = DateTime.now();
    final date =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    final heure =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("enquete_date", date);
    await prefs.setString("enquete_heure", heure);
    setState(() {
      dateStr = date;
      heureStr = heure;
    });
  }

  Future<void> _creerEnquete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final producteurId = widget.producteurId;

      final zoneNom = prefs.getString("agent_zone") ?? "MEAGUI";
      final zoneId = await DatabaseHelper.getOrCreateZone(zoneNom);

      final enqueteurNom = prefs.getString("agent_nom") ?? "Agent";
      final parts = enqueteurNom.split(' ');
      final enqueteurNomFamille = parts.length > 1 ? parts.last : enqueteurNom;

      var enqueteur = await DatabaseHelper.getEnqueteurByNom(
        enqueteurNomFamille,
      );
      int enqueteurId = enqueteur == null
          ? await DatabaseHelper.saveEnqueteur(
              codeEnqueteur: "ENQ${DateTime.now().millisecondsSinceEpoch}",
              nom: enqueteurNomFamille,
              prenom: parts.first,
              telephone: prefs.getString("agent_contact") ?? "",
            )
          : enqueteur['id'] as int;

      _enqueteId = await DatabaseHelper.createEnquete(
        producteurId: producteurId,
        enqueteurId: enqueteurId,
        zoneId: zoneId,
      );

      if (_enqueteId == null) {
        throw StateError("La création de l'enquête a échoué. Réessayez.");
      }

      if (_enqueteId != null) {
        await prefs.setInt("enquete_id", _enqueteId!);
      }
    } catch (e) {
      setState(
        () => _errorMessage = e is StateError
            ? e.message.toString()
            : "Erreur: $e",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Date et heure"),
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset("assets/images/fond_inf.png", fit: BoxFit.cover),
          ),
          Container(color: Colors.black.withOpacity(0.2)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule, size: 50, color: Colors.green),
                    const SizedBox(height: 10),
                    const Text(
                      "ENREGISTREMENT",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_isLoading)
                      const Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 20),
                          Text("Création en cours..."),
                        ],
                      )
                    else if (_errorMessage != null)
                      Column(
                        children: [
                          Icon(Icons.error, color: Colors.red, size: 40),
                          const SizedBox(height: 10),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _initPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text("RÉESSAYER"),
                          ),
                        ],
                      )
                    else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          const SizedBox(width: 8),
                          Text(dateStr, style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.access_time, size: 20),
                          const SizedBox(width: 8),
                          Text(heureStr, style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _enqueteId != null
                              ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ConsentementPage(
                                      enqueteId:
                                          _enqueteId!, // ✅ Passage de l'enqueteId
                                      producteurId: widget
                                          .producteurId, // ✅ Passage du producteurId
                                    ),
                                  ),
                                )
                              : null,
                          child: const Text("CONTINUER"),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================
// CONSENTEMENT PRODUCTEUR (VERSION CORRECTE)
// ===============================
class ConsentementPage extends StatelessWidget {
  // ✅ PARAMÈTRES OBLIGATOIRES
  final int enqueteId;
  final int producteurId;

  const ConsentementPage({
    super.key,
    required this.enqueteId,
    required this.producteurId,
  });

  // ✅ Navigation vers ResumeRefusPage en cas de refus
  Future<void> _refuser(BuildContext context) async {
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ResumeRefusPage()),
      );
    }
  }

  // ✅ Version corrigée - Sans SharedPreferences et avec validation
  Future<void> _accepter(BuildContext context) async {
    // 🔴 Vérification obligatoire des IDs
    if (enqueteId <= 0 || producteurId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erreur critique : enquête ou producteur manquant"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ Navigation directe avec les paramètres
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => questionnaire.QuestionnaireStartPage(
          enqueteId: enqueteId,
          producteurId: producteurId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Consentement"),
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/fond_questionnaire.jpg",
              fit: BoxFit.cover,
            ),
          ),
          Container(color: Colors.black.withOpacity(0.2)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200, width: 1),
                ),
                child: Column(
                  children: [
                    // Logo
                    Image.asset("assets/images/logo_sogb.jpg", height: 80),
                    const SizedBox(height: 20),

                    // Titre
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "CONSENTEMENT DU PRODUCTEUR",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Texte de consentement complet
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Je soussigné(e) ci-dessous :",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Par la présente, je donne mon consentement et j'autorise SOGB et ses partenaires à utiliser toute "
                            "information confidentielle, y compris les informations personnelles, que j'ai fournies lors de la collecte de "
                            "données liées à la cartographie de mes parcelles et à la réalisation d'enquêtes de légalité.\n\n"
                            "Les informations collectées peuvent inclure des données personnelles relatives au nom de l'agriculteur"
                            ", à son identité, à sa date de naissance, à son adresse, à ses coordonnées, à sa photo, aux détails de "
                            "sa parcelle, aux données de base sur son foyer et ses employés, ainsi qu'à des données économiques.\n\n"
                            "Je comprends que les données personnelles que je fournis sont des données confidentielles"
                            ", où ces données seront stockées correctement pour maintenir la confidentialité et ne peuvent être "
                            "consultées que par des personnes autorisées. SOGB peut autoriser ses partenaires à accéder à certaines "
                            "données sur la base d'un accord de confidentialité.\n\n"
                            "Je comprends que je peux retirer mon accord à tout moment en envoyant une notification écrite par"
                            "courrier électronique à SOGB. Je m'engage à ne pas soumettre de réclamations, de demandes "
                            "de compensation, de demandes d'exécution d'obligations ou d'autres actions légales en raison"
                            "de l'utilisation d'informations confidentielles par SOGB sur la base de cette lettre d'accord. Cet accord est"
                            "valable à compter de la date du présent consentement et restera en vigueur jusqu'à son retrait.\n\n"
                            "Fait pour valoir ce que de droit.",
                            style: TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Boutons REFUSER / ACCEPTER
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _refuser(context),
                            child: const Text(
                              "REFUSER",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () => _accepter(context),
                            child: const Text(
                              "ACCEPTER",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Mention légale
                    Text(
                      "En cliquant sur ACCEPTER, vous confirmez avoir lu et compris les termes de ce consentement.",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
