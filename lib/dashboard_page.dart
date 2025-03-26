import 'package:caissechicopets/gallery_page.dart';
import 'package:caissechicopets/gestioncommande/managecommande.dart';
import 'package:caissechicopets/gestionproduit/manage_categorie.dart';
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
          padding: const EdgeInsets.all(8.0), // Padding global ajusté
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12), // Espacement ajusté
              Expanded(
                child: GridView.count(
                  crossAxisCount: 5, // 3 cartes par ligne
                  crossAxisSpacing: 31, // Espacement horizontal entre les cartes
                  mainAxisSpacing: 10, // Espacement vertical entre les cartes
                  childAspectRatio: 0.8, // Ratio pour des cartes rectangulaires
                  children: [
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
                      label: 'Galerie de photos',
                      icon: Icons.photo_library,
                      page: const GalleryPage(),
                      color: const Color(0xFFE91E63),
                    ),
                     _buildCard(
                      context,
                      label: 'Gestion de comptes',
                      icon: Icons.people,
                      page: const GalleryPage(),
                      color: const Color.fromARGB(255, 0, 164, 201),
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
      elevation: 3, // Élévation légèrement augmentée
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(29), // Border radius augmenté
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
          padding: const EdgeInsets.all(8.0), // Padding ajusté
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 30, // Taille de l'icône augmentée
                color: Colors.white,
              ),
              const SizedBox(height: 8), // Espacement entre l'icône et le texte
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 20, // Taille de la police augmentée
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2, // Limite le texte à 2 lignes
                overflow: TextOverflow.ellipsis, // Ajoute des points de suspension si nécessaire
              ),
            ],
          ),
        ),
      ),
    );
  }
}