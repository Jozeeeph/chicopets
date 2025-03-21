import 'package:caissechicopets/cash_desk_page.dart';
import 'package:caissechicopets/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
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
                  fontSize: 22, // Taille de la police réduite
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30), // Espacement réduit
              // Utilisation d'un GridView pour les cartes
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.6, // Largeur réduite
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2, // 2 cartes par ligne
                  crossAxisSpacing: 12, // Espacement horizontal entre les cartes
                  mainAxisSpacing: 12, // Espacement vertical entre les cartes
                  childAspectRatio: 1.0, // Ratio pour des cartes carrées
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
      elevation: 4, // Élévation légère
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(50), // Border radius réduit
      ),
      color: color,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.all(12.0), // Padding réduit
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 30, // Taille de l'icône
                color: Colors.white,
              ),
              const SizedBox(height: 8), // Espacement entre l'icône et le texte
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 20, // Taille de la police réduite
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2, // Limite le texte à 2 lignes
                overflow: TextOverflow.ellipsis, // Points de suspension si nécessaire
              ),
            ],
          ),
        ),
      ),
    );
  }
}