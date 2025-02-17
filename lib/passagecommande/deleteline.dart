import 'package:caissechicopets/product.dart';
import 'package:flutter/material.dart';

class Deleteline {
  static void showDeleteConfirmation(
      int index,
      BuildContext context,
      List<Product> selectedProducts,
      List<int> quantityProducts,
      VoidCallback onUpdate) { // Add callback parameter
    
    if (index < 0 || index >= selectedProducts.length) {
      _showMessage(context, "Aucun produit sélectionné !");
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmation'),
          content: const Text(
              'Êtes-vous sûr de vouloir supprimer cette ligne de la commande ?'),
          actions: [
            ElevatedButton(
              onPressed: () {
                // Perform deletion
                if (index >= 0 && index < selectedProducts.length) {
                  selectedProducts.removeAt(index);
                  quantityProducts.removeAt(index);
                  onUpdate(); // Update UI after deletion
                }
                Navigator.of(context).pop(); // Close popup
              },
              child: const Text('Oui'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close popup
              },
              child: const Text('Non'),
            ),
          ],
        );
      },
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
