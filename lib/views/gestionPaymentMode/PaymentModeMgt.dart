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
            // Formulaire pour ajouter un nouveau mode de paiement
            Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _newMethodController,
                      decoration: const InputDecoration(
                        labelText: 'Nouveau mode de paiement',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un nom';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _addPaymentMethod,
                    child: const Text('Ajouter'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                              IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteMethod(method),
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

  Future<void> _addPaymentMethod() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _newMethodController.text.trim();
    try {
      final method = PaymentMethod(
        name: name,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await SqlDb().addPaymentMethod(method);
      _newMethodController.clear();
      _refreshPaymentMethods();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mode de paiement ajouté avec succès')),
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

  Future<void> _deleteMethod(PaymentMethod method) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: Text('Supprimer le mode de paiement "${method.name}" ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && mounted) {
      try {
        await SqlDb().deletePaymentMethod(method.id!);
        _refreshPaymentMethods();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mode de paiement supprimé')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    }
  }
}
