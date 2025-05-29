import 'dart:convert';
import 'package:caissechicopets/views/cashdesk_views/cashDeskHome/cashier_home_page.dart';
import 'package:caissechicopets/views/user_views/code_verification_page.dart';
import 'package:caissechicopets/views/user_views/create_admin_account_page.dart';
import 'package:caissechicopets/views/dashboard_views/dashboard_page.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:caissechicopets/views/user_views/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SqlDb _sqlDb = SqlDb();
  bool _hasAdmin = false;
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAdminAccount();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user');

    if (mounted) {
      setState(() {
        _currentUser =
            userJson != null ? User.fromMap(jsonDecode(userJson)) : null;
      });
    }
  }

  Future<void> _checkAdminAccount() async {
    final hasAdmin = await _sqlDb.hasAdminAccount();
    setState(() {
      _hasAdmin = hasAdmin;
      _isLoading = false;
    });
  }

  void _navigateToPage(Widget page) async {
    // Si utilisateur déconnecté, demander le code en premier
    if (_currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CodeVerificationPage(
            pageName:
                page is DashboardPage ? 'Tableau de bord' : 'Partie Caissier',
            destinationPage: page,
            onVerificationSuccess: (user) {
              setState(() => _currentUser = user);
              // Après vérification, vérifier les droits si c'est le dashboard
              if (page is DashboardPage && user.role != 'admin') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Accès réservé aux administrateurs')),
                );
              } else {
                _handlePostVerificationNavigation(page);
              }
            },
          ),
        ),
      );
      return;
    }

    // Si utilisateur déjà connecté, vérifier les droits pour le dashboard
    if (page is DashboardPage && _currentUser!.role != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accès réservé aux administrateurs')),
      );
      return;
    }

    // Si tout est OK, gérer la navigation normalement
    _handlePostVerificationNavigation(page);
  }

  Future<void> _handlePostVerificationNavigation(Widget page) async {
    // Navigation normale pour toutes les pages
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Future<void> _logout() async {
    await SessionManager.clearSession();
    if (mounted) {
      setState(() {
        _currentUser = null;
      });
    }
    // Pas besoin de navigation car on est déjà sur la home page
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasAdmin) {
      return const CreateAdminAccountPage();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0056A6), Color(0xFF26A9E0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0056A6), Color(0xFF26A9E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Bienvenue à Votre Caisse',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  children: [
                    _buildCard(
                      context,
                      label: 'Tableau de bord',
                      icon: Icons.dashboard,
                      page: const DashboardPage(),
                      color: const Color(0xFF009688),
                    ),
                    _buildCard(
                      context,
                      label: 'Partie Caissier',
                      icon: Icons.point_of_sale,
                      page: const CashierHomePage(),
                      color: const Color(0xFFFF9800),
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

  Widget _buildCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Widget page,
    required Color color,
    VoidCallback? onTapOverride,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
      ),
      color: color,
      child: InkWell(
        onTap: onTapOverride ?? () => _navigateToPage(page),
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 30,
                color: Colors.white,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
