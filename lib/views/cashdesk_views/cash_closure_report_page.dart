// views/cashdesk_views/cash_closure_report_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:caissechicopets/models/cash_state.dart';

class CashClosureReportPage extends StatelessWidget {
  final CashState cashState;

  const CashClosureReportPage({super.key, required this.cashState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rapport de clôture'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text('Rapport de caisse',
                        style: GoogleFonts.poppins(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Divider(),
                    _buildReportRow('Ouverture', cashState.openingTime),
                    _buildReportRow('Clôture', DateTime.now()),
                    _buildReportRow('Fond initial',
                        '${cashState.initialAmount.toStringAsFixed(2)} €'),
                  ],
                ),
              ),
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Confirmer la clôture'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            // Dans la méthode build de CashClosureReportPage
            ElevatedButton(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: Text('Retour à l\'accueil'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          if (value is DateTime)
            Text('${value.hour}:${value.minute.toString().padLeft(2, '0')}'),
          if (value is String) Text(value),
        ],
      ),
    );
  }
}
