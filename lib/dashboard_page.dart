import 'package:caissechicopets/import_product.dart'; // Importez le nouveau fichier
import 'package:caissechicopets/gestionproduit/manage_product.dart';
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageProductPage(),
                  ),
                );
              },
              child: const Text('Gestion de produit'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImportProductPage(),
                  ),
                );
              },
              child: const Text('Importer des produits'),
            ),
          ],
        ),
      ),
    );
  }
}