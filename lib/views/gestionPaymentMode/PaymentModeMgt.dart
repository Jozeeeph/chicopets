import 'package:caissechicopets/models/paymentMode.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';

class PaymentMethodManagement extends StatefulWidget {
  const PaymentMethodManagement({super.key});

  @override
  _PaymentMethodManagementState createState() =>
      _PaymentMethodManagementState();
}

class _PaymentMethodManagementState extends State<PaymentMethodManagement> {
  late Future<List<PaymentMethod>> _paymentMethodsFuture;
  final TextEditingController _newMethodController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _refreshPaymentMethods();
  }

  void _refreshPaymentMethods() {
    setState(() {
      _paymentMethodsFuture = SqlDb().getPaymentMethods(activeOnly: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Modes de Paiement'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.restore),
                  label: const Text('Restaurer les méthodes par défaut'),
                  onPressed: _resetToDefaultMethods,
                ),
              ],
            ),
            // Liste des modes de paiement
            Expanded(
              child: FutureBuilder<List<PaymentMethod>>(
                future: _paymentMethodsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Erreur: ${snapshot.error}'));
                  }

                  final methods = snapshot.data ?? [];

                  if (methods.isEmpty) {
                    return const Center(
                        child: Text('Aucun mode de paiement trouvé'));
                  }

                  return ListView.builder(
                    itemCount: methods.length,
                    itemBuilder: (context, index) {
                      final method = methods[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(method.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: method.isActive,
                                onChanged: (value) =>
                                    _toggleMethodStatus(method, value),
                                activeColor: Colors.green,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetToDefaultMethods() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmer la réinitialisation'),
            content: const Text(
                'Cette action va supprimer tous les modes de paiement personnalisés et restaurer les méthodes par défaut. Continuer?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmer',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      try {
        final sqlDb = SqlDb();
        final db = await sqlDb.db;

        // Clear existing methods
        await db.delete('payment_methods');

        // Insert default methods
        await sqlDb.insertDefaultPaymentMethods(db);

        _refreshPaymentMethods();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Méthodes de paiement réinitialisées avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _toggleMethodStatus(PaymentMethod method, bool isActive) async {
    try {
      await SqlDb().togglePaymentMethodStatus(method.id!, isActive);
      _refreshPaymentMethods();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la mise à jour')),
        );
      }
    }
  }
}
