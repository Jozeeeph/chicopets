import 'package:caissechicopets/gestionproduit/add_product_screen.dart';
import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddProductScreen(
                  refreshData: () {
                    // Rafraîchir les données si nécessaire
                  },
                ),
              ),
            );
          },
          child: const Text('Gestion de produit'),
        ),
      ),
    );
  }
}