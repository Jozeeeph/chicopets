import 'package:caissechicopets/gestioncommande/managecommande.dart';
import 'package:caissechicopets/import_product.dart'; // Importez le nouveau fichier
import 'package:caissechicopets/gestionproduit/manage_product.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0056A6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Tableau de bord', style: TextStyle(color: Colors.white)),
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
                'Tableau de bord',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _buildButton(
                context,
                label: 'Gestion de produit',
                icon: Icons.inventory,
                page: const ManageProductPage(),
                color: const Color(0xFF009688),
              ),
              const SizedBox(height: 20),
              _buildButton(
                context,
                label: 'Gestion de commandes',
                icon: Icons.inventory,
                page: const ManageCommand(),
                color: const Color.fromARGB(255, 86, 0, 207),
              ),
              const SizedBox(height: 20),
              _buildButton(
                context,
                label: 'Importer des produits',
                icon: Icons.upload_file,
                page: const ImportProductPage(),
                color: const Color(0xFFFF9800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(BuildContext context, {
    required String label,
    required IconData icon,
    required Widget page,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 5,
      ),
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
