import 'package:caissechicopets/controllers/fidelity_controller.dart';
import 'package:caissechicopets/models/order.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/views/client_views/client_form.dart';
import 'package:intl/intl.dart';

class ClientManagementWidget extends StatefulWidget {
  final Function(Client)? onClientSelected;
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  const ClientManagementWidget({Key? key, this.onClientSelected})
      : super(key: key);

  @override
  _ClientManagementWidgetState createState() => _ClientManagementWidgetState();
}

class _ClientManagementWidgetState extends State<ClientManagementWidget> {
  final SqlDb _sqlDb = SqlDb();
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  final TextEditingController _searchController = TextEditingController();
  List<Client> _selectedClients = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final clients = await _sqlDb.getAllClients();
      setState(() {
        _clients = clients;
        _filteredClients = clients;
      });
    } catch (e) {
      print('Error loading clients: $e');
    }
  }

  void _filterClients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClients = _clients.where((client) {
        return client.name.toLowerCase().contains(query) ||
            client.firstName.toLowerCase().contains(query) ||
            client.phoneNumber.contains(query);
      }).toList();
    });
  }



 

  Future<void> _deleteClients(List<Client> clients) async {
    for (var client in clients) {
      await _sqlDb.deleteClient(client.id!);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${clients.length} clients supprimés avec succès"),
        backgroundColor: widget.tealGreen,
      ),
    );
    _selectedClients.clear();
    _loadClients();
  }

  Future<void> _confirmDelete({Client? singleClient}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(singleClient != null
            ? 'Voulez-vous vraiment supprimer définitivement le client ${singleClient.name} ${singleClient.firstName} ?'
            : 'Voulez-vous vraiment supprimer les ${_selectedClients.length} clients sélectionnés ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (singleClient != null) {
          await _deleteClients([singleClient]);
        } else {
          await _deleteClients(_selectedClients);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: ${e.toString()}'),
            backgroundColor: widget.warmRed,
          ),
        );
      }
    }
  }

  Future<void> _convertPointsToVoucher(Client client) async {
    try {
      final db = await _sqlDb.db;
      final fidelityRules = await FidelityController().getFidelityRules(db);

      if (client.loyaltyPoints < fidelityRules.minPointsToUse) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Le client doit avoir au moins ${fidelityRules.minPointsToUse} points pour les convertir'),
            backgroundColor: widget.warmRed,
          ),
        );
        return;
      }

      final maxVoucherAmount =
          client.loyaltyPoints * fidelityRules.dinarPerPoint;
      final amountController = TextEditingController(
        text: maxVoucherAmount.toStringAsFixed(2),
      );

      final result = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Convertir les points en bon d\'achat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Points disponibles: ${client.loyaltyPoints}'),
              Text('Taux: ${fidelityRules.dinarPerPoint} DT/point'),
              Text(
                  'Valeur maximale: ${maxVoucherAmount.toStringAsFixed(2)} DT'),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montant du bon (DT)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Entrez un montant';
                  final amount = double.tryParse(value) ?? 0;
                  if (amount <= 0) return 'Le montant doit être positif';
                  if (amount > maxVoucherAmount) return 'Montant trop élevé';
                  return null;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0 || amount > maxVoucherAmount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Montant invalide')),
                  );
                  return;
                }
                Navigator.pop(context, amount);
              },
              child: const Text('Confirmer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.tealGreen,
              ),
            ),
          ],
        ),
      );

      if (result != null && result > 0) {
        // Calculate points to deduct
        final pointsToDeduct = (result / fidelityRules.dinarPerPoint).toInt();

        // Create voucher map (without ID)
        final voucherMap = {
          'client_id': client.id!,
          'amount': result,
          'remaining_amount': result,
          'points_used': pointsToDeduct,
          'created_at': DateTime.now().toIso8601String(),
          'is_used': 0,
          'code': 'VOUCH-${DateTime.now().millisecondsSinceEpoch}',
        };

        // Update database in transaction
        await db.transaction((txn) async {
          // Insert voucher (don't specify ID)
          await txn.insert('vouchers', voucherMap);

          // Update client points
          await txn.update(
            'clients',
            {'loyalty_points': client.loyaltyPoints - pointsToDeduct},
            where: 'id = ?',
            whereArgs: [client.id],
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Bon d\'achat de ${result.toStringAsFixed(2)} DT créé avec succès'),
            backgroundColor: widget.tealGreen,
          ),
        );

        // Refresh client list
        _loadClients();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: widget.warmRed,
        ),
      );
    }
  }

  Future<void> _showClientVouchers(BuildContext context, Client client) async {
    final vouchers = await _sqlDb.getClientVouchers(client.id!);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bons d\'achat de ${client.name} ${client.firstName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: vouchers.isEmpty
              ? Center(child: Text('Aucun bon d\'achat pour ce client'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: vouchers.length,
                  itemBuilder: (context, index) {
                    final voucher = vouchers[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading:
                            Icon(Icons.card_giftcard, color: widget.tealGreen),
                        title: Text('Bon #${voucher['id']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${voucher['amount']} DT'),
                            Text('Points utilisés: ${voucher['points_used']}'),
                            Text(
                                'Statut: ${voucher['is_used'] == 1 ? 'Utilisé' : 'Disponible'}'),
                            if (voucher['created_at'] != null)
                              Text(
                                  'Créé le: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(voucher['created_at']))}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showVoucherOptions(BuildContext context, Client client) async {
    final action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 4,
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: widget.white,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Options de bon d\'achat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.darkBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Convert Option
                Material(
                  color: widget.lightGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: () {
                      Navigator.pop(context, 'convert');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 16.0,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.currency_exchange,
                            color: widget.tealGreen,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Convertir les points',
                            style: TextStyle(
                              fontSize: 16,
                              color: widget.darkBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // View Option
                Material(
                  color: widget.lightGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: () {
                      Navigator.pop(context, 'view');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 16.0,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.list_alt,
                            color: widget.deepBlue,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Voir les bons existants',
                            style: TextStyle(
                              fontSize: 16,
                              color: widget.darkBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Cancel Button
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, 'cancel');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: widget.warmRed,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text('Annuler'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (action == 'convert') {
      await _convertPointsToVoucher(client);
    } else if (action == 'view') {
      await _showClientVouchers(context, client);
    }
  }

  void _showClientForm([Client? client]) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: widget.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ClientForm(
            client: client,
            onSubmit: (client) async {
              try {
                if (client.id == null) {
                  await _sqlDb.addClient(client);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Client ajouté avec succès'),
                      backgroundColor: widget.tealGreen,
                    ),
                  );
                } else {
                  await _sqlDb.updateClient(client);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Client mis à jour avec succès'),
                      backgroundColor: widget.tealGreen,
                    ),
                  );
                }
                _loadClients();
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: widget.warmRed,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Future<void> _updateDebt(Client client) async {
    final amountController = TextEditingController(
      text: client.debt.abs().toStringAsFixed(2),
    );

    final isPayment = client.debt > 0;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(isPayment ? 'Enregistrer un paiement' : 'Ajouter une dette'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Client: ${client.name} ${client.firstName}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Montant (DT)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Le montant doit être positif')),
                );
                return;
              }

              final newDebt =
                  isPayment ? client.debt - amount : client.debt + amount;

              try {
                await _sqlDb.updateClientDebt(client.id!, newDebt);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isPayment
                        ? 'Paiement enregistré avec succès'
                        : 'Dette mise à jour'),
                    backgroundColor: widget.tealGreen,
                  ),
                );
                _loadClients();
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: widget.warmRed,
                  ),
                );
              }
            },
            child: Text(isPayment ? 'Enregistrer paiement' : 'Ajouter dette'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPayment ? widget.tealGreen : widget.softOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtCell(Client client) {
  return InkWell(
    onTap: () => _updateDebt(client),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: client.debt > 0
            ? widget.warmRed.withOpacity(0.1)
            : widget.tealGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          '${client.debt.toStringAsFixed(2)} DT',
          style: _cellTextStyle().copyWith(
            color: client.debt > 0 ? widget.warmRed : widget.tealGreen,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}
  Future<void> _showClientOrders(BuildContext context, Client client) async {
    final orders = await _sqlDb.getClientOrders(client.id!);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Commandes de ${client.name} ${client.firstName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: orders.isEmpty
              ? Center(child: Text('Aucune commande pour ce client'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(Icons.receipt, color: widget.deepBlue),
                        title: Text('Commande #${order.idOrder}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${order.total.toStringAsFixed(2)} DT'),
                            Text(order.status),
                            Text(order.date),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.info, color: widget.softOrange),
                          onPressed: () => _showOrderDetails(context, order),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails de la commande #${order.idOrder}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: ${order.date}'),
              Text('Total: ${order.total.toStringAsFixed(2)} DT'),
              Text('Statut: ${order.status}'),
              Text('Mode de paiement: ${order.modePaiement}'),
              if (order.remainingAmount > 0)
                Text(
                    'Reste à payer: ${order.remainingAmount.toStringAsFixed(2)} DT'),
              SizedBox(height: 16),
              Text('Articles:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...order.orderLines.map((line) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('- ${line.productName} x ${line.quantity}'),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showClientProducts(BuildContext context, Client client) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Fetch client's purchased products
      final products = await _sqlDb.getProductsPurchasedByClient(client.id!);

      // Close loading dialog
      Navigator.of(context).pop();

      if (products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ce client n\'a acheté aucun produit')),
        );
        return;
      }

      // Show products dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title:
              Text('Historique d\'achats - ${client.name} ${client.firstName}'),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading:
                        Icon(Icons.shopping_basket, color: widget.tealGreen),
                    title: Text(product['designation'] ?? 'Produit inconnu'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Code: ${product['product_code'] ?? 'N/A'}'),
                        Text(
                            'Quantité totale: ${product['total_quantity'] ?? 0}'),
                        Text(
                            'Dernier achat: ${product['last_purchase_date'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(product['last_purchase_date'])) : 'N/A'}'),
                        Text(
                            'Total dépensé: ${(product['total_spent'] ?? 0).toStringAsFixed(2)} DT'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Erreur lors de la récupération des produits: ${e.toString()}'),
          backgroundColor: widget.warmRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Rechercher...',
                      hintText: 'Nom, prénom ou téléphone',
                      prefixIcon: Icon(Icons.search, color: widget.deepBlue),
                      filled: true,
                      fillColor: widget.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              FloatingActionButton(
                backgroundColor: widget.deepBlue,
                child: Icon(Icons.add, color: widget.white),
                onPressed: () => _showClientForm(),
                heroTag: 'addClient',
              ),
            ],
          ),
        ),
        if (_selectedClients.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('${_selectedClients.length} sélectionné(s)'),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.delete, color: widget.warmRed),
                  onPressed: () => _confirmDelete(),
                ),
              ],
            ),
          ),
        Expanded(
          child: _filteredClients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 60, color: widget.lightGray),
                      const SizedBox(height: 16),
                      Text('Aucun client trouvé',
                          style: TextStyle(color: widget.darkBlue)),
                    ],
                  ),
                )
              : _buildClientTable(),
        ),
      ],
    );
  }

 Widget _buildClientTable() {
  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: widget.deepBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Code',
                      style: _headerTextStyle(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Text(
                      'Nom & Prénom',
                      style: _headerTextStyle(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Téléphone',
                      style: _headerTextStyle(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Points',
                      style: _headerTextStyle(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Crédit',
                      style: _headerTextStyle(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Commandes',
                      style: _headerTextStyle(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Produits',
                      style: _headerTextStyle(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Text(
                      'Actions',
                      style: _headerTextStyle(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _filteredClients.length,
            itemBuilder: (context, index) {
              final client = _filteredClients[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    if (widget.onClientSelected != null) {
                      widget.onClientSelected!(client);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              client.id.toString(),
                              style: _cellTextStyle(),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: Text(
                              '${client.name} ${client.firstName}',
                              style: _cellTextStyle(),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              client.phoneNumber,
                              style: _cellTextStyle(),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              client.loyaltyPoints.toString(),
                              style: _cellTextStyle(),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: _buildDebtCell(client),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: IconButton(
                              icon: Icon(Icons.receipt, color: widget.deepBlue),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showClientOrders(context, client),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: IconButton(
                              icon: Icon(Icons.shopping_basket, color: widget.softOrange),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => _showClientProducts(context, client),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.card_giftcard,
                                    color: client.loyaltyPoints > 0
                                        ? widget.tealGreen
                                        : Colors.grey,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  onPressed: client.loyaltyPoints > 0
                                      ? () => _showVoucherOptions(context, client)
                                      : null,
                                  tooltip: 'Options de bon d\'achat',
                                ),
                                IconButton(
                                  icon: Icon(Icons.edit, color: widget.softOrange),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showClientForm(client),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: widget.warmRed),
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _confirmDelete(singleClient: client),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
  TextStyle _headerTextStyle() {
    return TextStyle(
      fontWeight: FontWeight.bold,
      color: widget.deepBlue,
      fontSize: 14,
    );
  }

  TextStyle _cellTextStyle() {
    return TextStyle(
      fontWeight: FontWeight.normal,
      color: widget.darkBlue,
      fontSize: 14,
    );
  }
}
