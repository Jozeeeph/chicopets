import 'dart:convert';

import 'package:caissechicopets/accounts_page.dart';
import 'package:caissechicopets/cash_desk_page.dart';
import 'package:caissechicopets/gallery_page.dart';
import 'package:caissechicopets/gestioncommande/managecommande.dart';
import 'package:caissechicopets/gestionproduit/manage_categorie.dart';
import 'package:caissechicopets/gestionproduit/manage_product.dart';
import 'package:caissechicopets/home_page.dart';
import 'package:caissechicopets/import_product.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/user.dart';
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
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
                  crossAxisCount: 5,
                  crossAxisSpacing: 31,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.8,
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
                      label: 'Passage de commande',
                      icon: Icons.point_of_sale,
                      page: const CashDeskPage(),
                      color: const Color(0xFF4CAF50),
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
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(29),
      ),
      color: color,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
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