import 'dart:convert';

import 'package:caissechicopets/views/cashdesk_views/cash_desk_page.dart';
import 'package:caissechicopets/views/user_views/code_verification_page.dart';
import 'package:caissechicopets/views/user_views/create_admin_account_page.dart';
import 'package:caissechicopets/views/dashboard_views/dashboard_page.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/models/user.dart';
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
    if (userJson != null) {
      setState(() {
        _currentUser = User.fromMap(jsonDecode(userJson));
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

  void _navigateToPage(Widget page) {
    if (_currentUser != null) {
      // Vérification supplémentaire pour le tableau de bord
      if (page is DashboardPage && _currentUser!.role != 'admin') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accès réservé aux administrateurs')),
        );
        return;
      }
      // Si l'utilisateur est déjà connecté, naviguer directement
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => page),
      );
    } else {
      // Sinon, demander le code
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CodeVerificationPage(
            pageName: page is DashboardPage
                ? 'Tableau de bord'
                : 'Passage de commande',
            destinationPage: page,
          ),
        ),
      );
    }
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
                      label: 'Passage de commande',
                      icon: Icons.shopping_cart,
                      page: const CashDeskPage(),
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
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
      ),
      color: color,
      child: InkWell(
        onTap: () => _navigateToPage(page),
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
