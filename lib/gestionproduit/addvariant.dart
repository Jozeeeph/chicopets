import 'package:caissechicopets/variantprod.dart';
import 'package:flutter/material.dart';



class AddVariant {
  static Widget buildVariantFields(
    BuildContext context,
    VariantProd variant,
    Function(VariantProd) onUpdate,
  ) {
    TextEditingController sizeController = TextEditingController(text: variant.size);
    TextEditingController prixHTController = TextEditingController(text: variant.prixHT.toString());
    TextEditingController taxController = TextEditingController(text: variant.taxe.toString());
    TextEditingController prixTTCController = TextEditingController(text: variant.prixTTC.toStringAsFixed(2));

    void updateVariant() {
      double prixHT = double.tryParse(prixHTController.text) ?? 0.0;
      double taxe = double.tryParse(taxController.text) ?? 0.0;
      double prixTTC = prixHT + (prixHT * taxe / 100);

      onUpdate(VariantProd(
        id: variant.id,
        productCode: variant.productCode,
        size: sizeController.text,
        prixHT: prixHT,
        taxe: taxe,
        prixTTC: prixTTC,
      ));
    }

    return Column(
      children: [
        TextField(
          controller: sizeController,
          decoration: InputDecoration(labelText: 'Taille'),
          onChanged: (value) => updateVariant(),
        ),
        TextField(
          controller: prixHTController,
          decoration: InputDecoration(labelText: 'Prix HT'),
          keyboardType: TextInputType.number,
          onChanged: (value) => updateVariant(),
        ),
        TextField(
          controller: taxController,
          decoration: InputDecoration(labelText: 'Taxe (%)'),
          keyboardType: TextInputType.number,
          onChanged: (value) => updateVariant(),
        ),
        TextField(
          controller: prixTTCController,
          decoration: InputDecoration(labelText: 'Prix TTC'),
          enabled: false,
        ),
        SizedBox(height: 10),
      ],
    );
  }
}