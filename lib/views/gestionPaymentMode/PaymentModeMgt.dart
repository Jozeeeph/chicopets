import 'package:caissechicopets/models/paymentMode.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/sqldb.dart';

// Couleurs de la palette
final Color deepBlue = const Color(0xFF0056A6);
final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
final Color white = Colors.white;
final Color lightGray = const Color(0xFFE0E0E0);
final Color tealGreen = const Color(0xFF009688);
final Color softOrange = const Color(0xFFFF9800);
final Color warmRed = const Color(0xFFE53935);

class PaymentMethodManagement extends StatefulWidget {
  const PaymentMethodManagement({super.key});

  @override
  _PaymentMethodManagementState createState() =>
      _PaymentMethodManagementState();
}

class _PaymentMethodManagementState extends State<PaymentMethodManagement> {
  late Future<List<PaymentMethod>> _paymentMethodsFuture;

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
      backgroundColor: lightGray,
      appBar: AppBar(
        title: const Text('Gestion des Modes de Paiement'),
        backgroundColor: deepBlue,
        foregroundColor: white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(Icons.restore, color: warmRed),
                label: Text(
                  'Restaurer les méthodes par défaut',
                  style: TextStyle(color: warmRed),
                ),
                onPressed: _resetToDefaultMethods,
              ),
            ),
            const SizedBox(height: 10),
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
                    return Center(
                      child: Text(
                        'Aucun mode de paiement trouvé',
                        style: TextStyle(color: darkBlue),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: methods.length,
                    itemBuilder: (context, index) {
                      final method = methods[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 8),
                        child: Card(
                          color: white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: deepBlue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.payment,
                                      color: deepBlue, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        method.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: darkBlue,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        method.isActive
                                            ? 'Activé'
                                            : 'Désactivé',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: method.isActive
                                              ? tealGreen
                                              : warmRed,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: method.isActive,
                                  onChanged: (value) =>
                                      _toggleMethodStatus(method, value),
                                  activeColor: tealGreen,
                                  inactiveTrackColor: lightGray,
                                ),
                              ],
                            ),
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
                child: Text('Annuler', style: TextStyle(color: deepBlue)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Confirmer', style: TextStyle(color: warmRed)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      try {
        final sqlDb = SqlDb();
        final db = await sqlDb.db;

        await db.delete('payment_methods');
        await sqlDb.insertDefaultPaymentMethods(db);

        _refreshPaymentMethods();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  const Text('Méthodes de paiement réinitialisées avec succès'),
              backgroundColor: softOrange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: warmRed,
            ),
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
          SnackBar(
            content: const Text('Erreur lors de la mise à jour'),
            backgroundColor: warmRed,
          ),
        );
      }
    }
  }
}
