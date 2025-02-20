import 'package:caissechicopets/cash_desk_page.dart';
import 'package:caissechicopets/dashboard_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Naviguer vers le tableau de bord
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DashboardPage()),
                );
              },
              child: const Text('Tableau de bord'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Naviguer vers le passage de commande
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CashDeskPage()),
                );
              },
              child: const Text('Passage de commande'),
            ),
          ],
        ),
      ),
    );
  }
}