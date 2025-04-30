// views/cashdesk_views/cash_initial_amount_page.dart
import 'package:caissechicopets/controllers/cash_service.dart';
import 'package:caissechicopets/models/cash_state.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CashInitialAmountPage extends StatefulWidget {
  final VoidCallback onAmountSubmitted;

  const CashInitialAmountPage({super.key, required this.onAmountSubmitted});

  @override
  _CashInitialAmountPageState createState() => _CashInitialAmountPageState();
}

class _CashInitialAmountPageState extends State<CashInitialAmountPage> {
  final TextEditingController _amountController = TextEditingController();
  final CashService _cashService = CashService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fond de caisse initial', style: GoogleFonts.poppins()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Veuillez saisir le montant initial de la caisse',
              style: GoogleFonts.poppins(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.euro),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _submitAmount,
              child: Text('Valider', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAmount() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Veuillez saisir un montant valide')),
      );
      return;
    }

    await _cashService.saveCashState(CashState(
      initialAmount: amount,
      openingTime: DateTime.now(),
      isClosed: false,
    ));

    widget.onAmountSubmitted();
  }
}