import 'package:caissechicopets/models/order.dart';
import 'package:flutter/material.dart';
import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/sqldb.dart';
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

  void _toggleClientSelection(Client client) {
    setState(() {
      if (_selectedClients.contains(client)) {
        _selectedClients.remove(client);
      } else {
        _selectedClients.add(client);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedClients.length == _filteredClients.length) {
        _selectedClients.clear();
      } else {
        _selectedClients = List.from(_filteredClients);
      }
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
      width: 90, // Largeur fixe pour un meilleur alignement
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
        ),
      ),
    ),
  );
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
            // En-têtes du tableau
            Container(
              decoration: BoxDecoration(
                color: widget.deepBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                      flex: 2, child: Text('Code', style: _headerTextStyle())),
                  Expanded(
                      flex: 3,
                      child: Text('Nom & Prénom', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Téléphone', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Points', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Crédit', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Commandes', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Produits', style: _headerTextStyle())),
                  Expanded(
                      flex: 2,
                      child: Text('Actions', style: _headerTextStyle())),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Liste des clients
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredClients.length,
              itemBuilder: (context, index) {
                final client = _filteredClients[index];
                final isSelected = _selectedClients.contains(client);

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
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text(client.id.toString(),
                                  style: _cellTextStyle())),
                          Expanded(
                              flex: 3,
                              child: Text('${client.name} ${client.firstName}',
                                  style: _cellTextStyle())),
                          Expanded(
                              flex: 2,
                              child: Text(client.phoneNumber,
                                  style: _cellTextStyle())),
                          Expanded(
                              flex: 2,
                              child: Text(client.loyaltyPoints.toString(),
                                  style: _cellTextStyle())),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: _buildDebtCell(client),
                          ),
                          Expanded(
                            flex: 2,
                            child: IconButton(
                              icon: Icon(Icons.receipt, color: widget.deepBlue),
                              onPressed: () =>
                                  _showClientOrders(context, client),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: IconButton(
                              icon: Icon(Icons.shopping_basket,
                                  color: widget.softOrange),
                              onPressed: () =>
                                  _showClientProducts(context, client),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit,
                                      color: widget.softOrange),
                                  onPressed: () => _showClientForm(client),
                                ),
                                IconButton(
                                  icon:
                                      Icon(Icons.delete, color: widget.warmRed),
                                  onPressed: () =>
                                      _confirmDelete(singleClient: client),
                                  tooltip: 'Supprimer le client',
                                ),
                              ],
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
              ...order.orderLines.map((line) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('- ${line.productCode} x${line.quantity}'),
                  )),
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

  void _showClientProducts(BuildContext context, Client client) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      final products = await _sqlDb.getProductsPurchasedByClient(client.id!);

      Navigator.of(context).pop();

      if (products.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ce client n\'a acheté aucun produit')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Historique d\'achats'),
          content: Container(
            width: double.maxFinite,
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
                        Text('Quantité: ${product['total_quantity']}'),
                        Text(
                            'Total dépensé: ${product['total_spent']?.toStringAsFixed(2) ?? '0.00'} DT'),
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
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: widget.warmRed,
        ),
      );
    }
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
