import 'dart:convert';

import 'package:caissechicopets/views/analysis_views/stock_movement_analysis_page.dart';
import 'package:caissechicopets/views/fidelity_views/fidelity_rules_page.dart';
import 'package:caissechicopets/views/attribute_views/listAttributs.dart';
import 'package:caissechicopets/views/paymentmode_views/PaymentModeMgt.dart';
import 'package:caissechicopets/views/reports_views/financial_report_page.dart';
import 'package:caissechicopets/views/reports_views/sales_report_page.dart';
import 'package:caissechicopets/views/stock_views/stock_management_page.dart';
import 'package:caissechicopets/views/stock_views/stock_prediction_page.dart';
import 'package:caissechicopets/views/synchronisation_view/synchronisation.dart';
import 'package:caissechicopets/views/user_views/accounts_page.dart';
import 'package:caissechicopets/views/gallery_views/gallery_page.dart';
import 'package:caissechicopets/views/order_views/managecommande.dart';
import 'package:caissechicopets/views/category_views/manage_categorie.dart';
import 'package:caissechicopets/views/product_views/manage_product.dart';
import 'package:caissechicopets/views/home_views/home_page.dart';
import 'package:caissechicopets/views/product_views/import_product.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('current_user');
    if (userJson != null) {
      final user = User.fromMap(jsonDecode(userJson));
      setState(() {
        _userRole = user.role;
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userRole == 'admin';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0056A6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
        title: const Text('Tableau de bord',
            style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0056A6), Color(0xFF26A9E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 6,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  childAspectRatio: 0.71,
                  children: [
                    if (isAdmin) ...[
                      _buildCard(
                        context,
                        label: 'Gestion de produit',
                        icon: Icons.inventory,
                        page: const ManageProductPage(),
                        color: const Color(0xFF009688),
                      ),
                      _buildCard(
                        context,
                        label: 'Gestion de commandes',
                        icon: Icons.shopping_cart,
                        page: const ManageCommand(),
                        color: const Color.fromARGB(255, 86, 0, 207),
                      ),
                      _buildCard(
                        context,
                        label: 'Importer des produits',
                        icon: Icons.upload_file,
                        page: const ImportProductPage(),
                        color: const Color(0xFFFF9800),
                      ),
                      _buildCard(
                        context,
                        label: 'Gestion de catégorie',
                        icon: Icons.category,
                        page: const ManageCategoriePage(),
                        color: const Color(0xFF673AB7),
                      ),
                      _buildCard(
                        context,
                        label: 'Gestion de comptes',
                        icon: Icons.people,
                        page: const AccountsPage(),
                        color: const Color.fromARGB(255, 0, 164, 201),
                      ),
                      _buildCard(
                        context,
                        label: 'Gestion de stock',
                        icon: Icons.warehouse,
                        page: const StockManagementPage(),
                        color: const Color(0xFF795548),
                      ),
                      _buildCard(
                        context,
                        label: 'Modes de paiement',
                        icon: Icons.payment,
                        page: PaymentMethodManagement(),
                        color: const Color(0xFF4CAF50),
                      ),
                      _buildCard(
                        context,
                        label: 'Rapports des ventes',
                        icon: Icons.bar_chart,
                        page: SalesReportPage(), // Updated this line
                        color: const Color(0xFF3F51B5),
                      ),
                      _buildCard(
                        context,
                        label: 'Rapports financiers',
                        icon: Icons.attach_money,
                        page: const FinancialReportPage(),
                        color: const Color(0xFF8BC34A),
                      ),
                      _buildCard(
                        context,
                        label: 'Gestion des Attributs',
                        icon: Icons.tune,
                        page: const ListAttributs(),
                        color: const Color(0xFF9C27B0),
                      ),
                      _buildCard(
                        context,
                        label: 'Statistiques',
                        icon: Icons.show_chart,
                        page: StockMovementAnalysisPage(),
                        color: const Color(0xFFF44336),
                      ),
                    ],
                    _buildCard(
                      context,
                      label: 'Galerie de photos',
                      icon: Icons.photo_library,
                      page: const GalleryPage(),
                      color: const Color(0xFFE91E63),
                    ),
                    _buildCard(
                      context,
                      label: 'Programme de fidélité',
                      icon: Icons.loyalty,
                      page: FidelityRulesPage(),
                      color: Color(0xFF9C27B0),
                    ),
                    _buildCard(
                      context,
                      label: 'Prédictions avec IA',
                      icon: Icons.batch_prediction,
                      page: StockPredictionPage(),
                      color: Color.fromARGB(255, 1, 166, 249),
                    ),
                    _buildCard(
                      context,
                      label: 'Synchronisation',
                      icon: Icons.sync,
                      page: const SyncPage(),
                      color: const Color(0xFF6A1B9A),
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
    required Widget? page,
    required Color color,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(29),
      ),
      color: color,
      child: InkWell(
        onTap: page != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => page),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
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
