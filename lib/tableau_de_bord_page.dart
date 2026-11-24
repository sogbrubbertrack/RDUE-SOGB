import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'informations_producteur_page.dart';
import 'dossier_rubberway_page.dart';
import 'export_csv_page.dart';
import 'formation_page.dart';
import 'statistiques_page.dart';
import 'data/database_helper.dart';
import 'auth/supabase_auth_service.dart';

class TableauDeBordPage extends StatefulWidget {
  const TableauDeBordPage({super.key});

  @override
  State<TableauDeBordPage> createState() => _TableauDeBordPageState();
}

class _TableauDeBordPageState extends State<TableauDeBordPage>
    with SingleTickerProviderStateMixin {
  String _agentNom = "";
  String _agentPrenom = "";
  String _agentFonction = "";
  String _agentZone = "Zone";
  String _agentContact = "";
  int _enquetesRealisees = 0;
  bool _deconnexionEnCours = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _chargerInfosAgent();
    _compterEnquetesReelles();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _chargerInfosAgent() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final nomComplet = prefs.getString('agent_nom') ?? 'Agent';
      final parts = nomComplet.split(' ');

      String prenom = parts.isNotEmpty ? parts[0] : '';
      prenom = prenom.replaceAll(RegExp(r'^K\s*'), '').trim();

      _agentPrenom = prenom;
      _agentNom = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      _agentFonction = prefs.getString('agent_fonction') ?? '';
      _agentZone = prefs.getString('agent_zone') ?? 'Zone';
      _agentContact = prefs.getString('agent_contact') ?? '';
    });
  }

  Future<void> _compterEnquetesReelles() async {
    try {
      final count = await DatabaseHelper.getNombreEnquetesAvecPdf();
      if (!mounted) return;
      setState(() => _enquetesRealisees = count);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('enquetes_realisees', count);
    } catch (e) {
      debugPrint('Erreur comptage enquêtes PDF: $e');
      if (mounted) setState(() => _enquetesRealisees = 0);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Bonjour";
    if (hour < 17) return "Bon après-midi";
    return "Bonsoir";
  }

  // Navigation
  Future<void> _nouvelleEnquete() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InformationsProducteurPage()),
    );
  }

  Future<void> _voirCsv() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExportCsvPage()),
    );
  }

  void _voirFormations() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FormationPage()),
    );
  }

  void _voirStatistiques() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StatistiquesPage()),
    );
  }

  Future<void> _ouvrirDossierPdf() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DossierRubberwayPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Image de fond
          Positioned.fill(
            child: Image.asset(
              "assets/images/fond_questionnaire.jpg",
              fit: BoxFit.cover,
            ),
          ),

          // Overlay élégant avec gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                    Colors.green.withOpacity(0.2),
                  ],
                ),
              ),
            ),
          ),

          // Contenu principal
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    _buildHeader(),

                    // Carte agent
                    _buildAgentCard(),

                    const SizedBox(height: 10),

                    // Statistiques en ligne
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.assignment_turned_in,
                              label: "Enquêtes réalisées",
                              value: "$_enquetesRealisees",
                              color: Colors.green,
                              onTap: null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.folder_open,
                              label: "Documents PDF",
                              value: "Consulter",
                              color: Colors.orange,
                              onTap: _ouvrirDossierPdf,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Section actions
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "ACTIONS RAPIDES",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Première ligne : Nouvelle enquête et Export CSV (largeur réduite de 3 points)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.add_circle_outline,
                              title: "NOUVELLE\nENQUÊTE",
                              color: Colors.green,
                              height: 92,
                              iconSize: 29,
                              fontSize: 12,
                              padding: 10, // ✅ Padding réduit de 16 à 13 (-3)
                              onTap: _nouvelleEnquete,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.insert_drive_file,
                              title: "EXPORTER\nCSV",
                              color: Colors.blue,
                              height: 92,
                              iconSize: 29,
                              fontSize: 12,
                              padding: 10, // ✅ Padding réduit de 16 à 13 (-3)
                              onTap: _voirCsv,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.school,
                              title: 'FORMATION',
                              color: Colors.deepOrange,
                              height: 76,
                              iconSize: 23,
                              fontSize: 12,
                              padding: 10,
                              onTap: _voirFormations,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionCard(
                              icon: Icons.bar_chart,
                              title: 'STATISTIQUES',
                              color: Colors.teal,
                              height: 76,
                              iconSize: 23,
                              fontSize: 12,
                              padding: 10,
                              onTap: _voirStatistiques,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),

                    // Footer épuré
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Header design épuré
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _agentPrenom.isNotEmpty ? _agentPrenom : _agentNom,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: _deconnexionEnCours ? null : _deconnecter,
            icon: _deconnexionEnCours
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _deconnecter() async {
    setState(() => _deconnexionEnCours = true);
    try {
      await SupabaseAuthService.signOut();
      rubberwayAuthenticated.value = false;
    } catch (_) {
      if (!mounted) return;
      setState(() => _deconnexionEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Déconnexion impossible. Réessayez.')),
      );
    }
  }

  // Carte agent
  Widget _buildAgentCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.green, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$_agentPrenom $_agentNom".trim(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (_agentFonction.isNotEmpty)
                      Text(
                        _agentFonction,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip(Icons.location_on, _agentZone),
              const SizedBox(width: 12),
              if (_agentContact.isNotEmpty)
                _buildInfoChip(Icons.phone, _agentContact),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Carte statistique (peut être cliquable ou non)
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: value == "Consulter" ? 15 : 19,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Carte d'action verticale (format carte classique) avec paramètres ajustables
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required double height,
    required double iconSize,
    required double fontSize,
    required double padding,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: height,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withBlue(color.blue + 20).withGreen(color.green + 20),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: iconSize),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Footer épuré
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            "RubberWay • Enquête RDUE",
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
