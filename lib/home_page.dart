import 'dart:convert';

import 'package:caissechicopets/controllers/cash_service.dart';
import 'package:caissechicopets/models/cash_state.dart';
import 'package:caissechicopets/views/cashdesk_views/cash_closure_report_page.dart';
import 'package:caissechicopets/views/cashdesk_views/cash_desk_page.dart';
import 'package:caissechicopets/views/cashdesk_views/cash_initial_amount_page.dart';
import 'package:caissechicopets/views/user_views/code_verification_page.dart';
import 'package:caissechicopets/views/user_views/create_admin_account_page.dart';
import 'package:caissechicopets/views/dashboard_views/dashboard_page.dart';
import 'package:caissechicopets/sqldb.dart';
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
      _currentUser = userJson != null ? User.fromMap(jsonDecode(userJson)) : null;
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
  // Vérification des droits pour le tableau de bord
  if (page is DashboardPage && (_currentUser == null || _currentUser!.role != 'admin')) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Accès réservé aux administrateurs')),
    );
    return;
  }

  // Si utilisateur déconnecté, demander le code
  if (_currentUser == null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CodeVerificationPage(
          pageName: page is DashboardPage 
              ? 'Tableau de bord' 
              : 'Passage de commande',
          destinationPage: page,
          onVerificationSuccess: (user) {
            setState(() => _currentUser = user);
            _handlePostVerificationNavigation(page);
          },
        ),
      ),
    );
    return;
  }

  // Si utilisateur déjà connecté, gérer la navigation normalement
  _handlePostVerificationNavigation(page);
}

Future<void> _handlePostVerificationNavigation(Widget page) async {
  // Cas spécial pour la page de caisse
  if (page is CashDeskPage) {
    final cashService = CashService();
    final cashState = await cashService.getCashState();

    // Cas 1: Caisse fermée ou jamais ouverte -> demande montant initial
    if (cashState == null || cashState.isClosed) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CashInitialAmountPage(
            onAmountSubmitted: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => page),
              );
            },
          ),
        ),
      );
      return;
    }
    // Cas 2: Caisse déjà ouverte -> accès direct
  }

  // Navigation normale pour les autres pages
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => page),
  );
}

  Future<void> _closeCashRegister() async {
  final cashService = CashService();
  final cashState = await cashService.getCashState();
  
  final shouldClose = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Confirmer la clôture'),
      content: Text('Voulez-vous vraiment clôturer la caisse ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Confirmer', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  ) ?? false;

  if (shouldClose) {
    // Sauvegarder l'état clôturé
    await cashService.saveCashState(CashState(
      initialAmount: cashState?.initialAmount ?? 0,
      openingTime: cashState?.openingTime,
      closingTime: DateTime.now(),
      isClosed: true,
    ));

    // Déconnecter l'utilisateur
    await SessionManager.clearSession();
    
    // Afficher le rapport
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CashClosureReportPage(
            cashState: cashState ?? CashState(initialAmount: 0, isClosed: true),
          ),
        ),
      );
    }

    // Mettre à jour l'état
    if (mounted) {
      setState(() => _currentUser = null);
    }
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
                  crossAxisCount: 3,
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
                    if (_currentUser != null && _currentUser!.role == 'admin')
                      _buildCard(
                        context,
                        label: 'Clôturer la caisse',
                        icon: Icons.close,
                        page: Container(), // page factice
                        color: Colors.red,
                        onTapOverride: _closeCashRegister,
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
    VoidCallback? onTapOverride, // Nouveau paramètre
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50),
      ),
      color: color,
      child: InkWell(
        onTap: onTapOverride ??
            () => _navigateToPage(page), // Utilise override si présent
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
