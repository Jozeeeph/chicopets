import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CashDeskPage(),
    );
  }
}

class CashDeskPage extends StatelessWidget {
  final SqlDb sqldb = SqlDb();

  CashDeskPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash-Desk'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // Header Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Caissier : foulen ben foulen'),
                Text('Avec Ticket : Vrai'),
                Text('17/01/2025 15:08'),
              ],
            ),
            const SizedBox(height: 10),
            // Order Section
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.blue,
                    child: Row(
                      children: const [
                        Expanded(child: Text('Code Art')),
                        Expanded(child: Text('Designation')),
                        Expanded(child: Text('Quantité')),
                        Expanded(child: Text('Remise')),
                        Expanded(child: Text('Montant')),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text('Aucune commande'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Button Section
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Clients'),
                      ),
                      ElevatedButton(
                        onPressed: () => _showAddProductPopup(context),
                        child: const Text('Ajout Produit'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Recherche Produit'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: buildNumberButton('1')),
                          Expanded(child: buildNumberButton('2')),
                          Expanded(child: buildNumberButton('3')),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: buildNumberButton('4')),
                          Expanded(child: buildNumberButton('5')),
                          Expanded(child: buildNumberButton('6')),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: buildNumberButton('7')),
                          Expanded(child: buildNumberButton('8')),
                          Expanded(child: buildNumberButton('9')),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(child: buildNumberButton('0')),
                          Expanded(child: buildNumberButton('X')),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Impr Ticket'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Remise %'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Valider'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Annuler'),
                        style:
                            ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Bottom Section
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 3,
                      childAspectRatio: 1,
                      children: [
                        buildCategoryButton('Poisson', 'assets/images/poison.jpg'),
                        buildCategoryButton('Oiseaux', 'assets/images/oiseau.jpg'),
                        buildCategoryButton('Chien', 'assets/images/chien.jpg'),
                        buildCategoryButton('Chat', 'assets/images/chat.jpg'),
                        buildCategoryButton(
                            'Collier Laiss', 'assets/images/collier.jpg'),
                        buildCategoryButton('Brosse', 'assets/images/brosse.jpg'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      children: [
                        buildProductButton('Produit1'),
                        buildProductButton('Produit2'),
                        buildProductButton('Produit3'),
                        buildProductButton('Produit4'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildNumberButton(String text) {
    return ElevatedButton(
      onPressed: () {},
      child: Text(text),
    );
  }

  Widget buildCategoryButton(String label, String imagePath) {
    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget buildProductButton(String text) {
    return Container(
      margin: const EdgeInsets.all(4.0),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.blueGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _showAddProductPopup(BuildContext context) {
    final TextEditingController codeController = TextEditingController();
    final TextEditingController designationController = TextEditingController();
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController priceHTController = TextEditingController();
    final TextEditingController priceTTCController = TextEditingController();
    final TextEditingController dateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajouter un Produit'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Code Barre'),
                ),
                TextField(
                  controller: designationController,
                  decoration: const InputDecoration(labelText: 'Désignation'),
                ),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Quantité'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: priceHTController,
                  decoration: const InputDecoration(labelText: 'Prix HT'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: priceTTCController,
                  decoration: const InputDecoration(labelText: 'Taxe'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: 'Date Expiration'),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                // Add to database logic
                // await sqldb.addProducts(
                //     'INSERT INTO products (codeabarre, designation, quantite, prixHT, prixTTC, dateexpiration) VALUES (?, ?, ?, ?, ?, ?)',
                //     [
                //       codeController.text,
                //       designationController.text,
                //       quantityController.text,
                //       priceHTController.text,
                //       priceTTCController.text,
                //       dateController.text,
                //     ]);
                Navigator.of(context).pop();
              },
              child: const Text('Ajouter'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }
}
