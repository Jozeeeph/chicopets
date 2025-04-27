import 'package:flutter/material.dart';
import 'package:caissechicopets/models/client.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/views/client_views/client_form.dart';
import 'package:flutter/animation.dart';
import 'package:caissechicopets/models/order.dart';
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

class _ClientManagementWidgetState extends State<ClientManagementWidget>
    with SingleTickerProviderStateMixin {
  final SqlDb _sqlDb = SqlDb();
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_filterClients);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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

  void _showPointsInfo(BuildContext context, Client client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Informations client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${client.name} ${client.firstName}'),
            SizedBox(height: 8),
            Text('Téléphone: ${client.phoneNumber}'),
            SizedBox(height: 16),
            Text('Points de fidélité: ${client.loyaltyPoints} points',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Dette: ${client.debt.toStringAsFixed(2)} DT',
                style: TextStyle(
                    color: client.debt > 0 ? widget.warmRed : widget.tealGreen,
                    fontWeight: FontWeight.bold)),
            if (client.lastPurchaseDate != null)
              Text(
                  'Dernier achat: ${DateFormat('dd/MM/yyyy').format(client.lastPurchaseDate!)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDebt(BuildContext context, Client client) async {
    final amountController = TextEditingController(
      text: client.debt.abs().toStringAsFixed(2),
    );

    final isPayment = client.debt > 0; // True if client owes money

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(isPayment ? 'Enregistrer un paiement' : 'Ajouter une dette'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Client: ${client.name} ${client.firstName}'),
            SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Montant (DT)',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Entrez un montant';
                if (double.tryParse(value) == null) return 'Montant invalide';
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Le montant doit être positif')),
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

  void _showClientOrders(BuildContext context, Client client) async {
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
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      final products = await _sqlDb.getProductsPurchasedByClient(client.id!);

      // Fermer l'indicateur de chargement
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
              child: Text('Fermer', style: TextStyle(color: widget.deepBlue)),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context)
          .pop(); // Fermer l'indicateur de chargement en cas d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: widget.warmRed,
        ),
      );
    }
  }

  void _showClientForm([Client? client]) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: widget.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ClientForm(
            client: client,
            onSubmit: (client) async {
              try {
                if (client.id == null) {
                  final id = await _sqlDb.addClient(client);
                  if (id > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Client ajouté avec succès'),
                        backgroundColor: widget.tealGreen,
                      ),
                    );
                  }
                } else {
                  await _sqlDb.updateClient(client);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Client mis à jour avec succès'),
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

  void _deleteClient(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Confirmer la suppression',
            style: TextStyle(color: widget.darkBlue)),
        content: Text('Voulez-vous vraiment supprimer ce client ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: widget.deepBlue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer', style: TextStyle(color: widget.warmRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _sqlDb.deleteClient(id);
      _loadClients();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Client supprimé'),
          backgroundColor: widget.tealGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Container(
            margin: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                hintText: 'Rechercher un client...',
                prefixIcon: Icon(Icons.search, color: widget.deepBlue),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: widget.warmRed),
                        onPressed: () {
                          _searchController.clear();
                          _filterClients();
                        },
                      )
                    : null,
              ),
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  backgroundColor: widget.deepBlue,
                  child: Icon(Icons.add, color: widget.white),
                  onPressed: () => _showClientForm(),
                  heroTag: 'addClient',
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: _filteredClients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline,
                            size: 60, color: widget.lightGray),
                        SizedBox(height: 16),
                        Text('Aucun client trouvé',
                            style: TextStyle(color: widget.darkBlue)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredClients.length,
                    itemBuilder: (context, index) {
                      final client = _filteredClients[index];
                      return Dismissible(
                        key: Key(client.id.toString()),
                        background: Container(
                          color: widget.warmRed,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 20),
                          child: Icon(Icons.delete, color: widget.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Confirmer'),
                              content: Text('Supprimer ce client ?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text('Non'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: Text('Oui',
                                      style: TextStyle(color: widget.warmRed)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) => _deleteClient(client.id!),
                        child: Card(
                          elevation: 4,
                          margin:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              if (widget.onClientSelected != null) {
                                widget.onClientSelected?.call(client);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: widget.tealGreen,
                                      child: Text(
                                        client.name
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: TextStyle(color: widget.white),
                                      ),
                                    ),
                                    title: Text(
                                      '${client.name} ${client.firstName}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: widget.darkBlue,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(client.phoneNumber),
                                        Row(
                                          children: [
                                            Text(
                                              '${client.loyaltyPoints} pts',
                                              style: TextStyle(
                                                color: widget.deepBlue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(width: 16),
                                            Text(
                                              '${client.debt.toStringAsFixed(2)} DT',
                                              style: TextStyle(
                                                color: client.debt > 0
                                                    ? widget.warmRed
                                                    : widget.tealGreen,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(Icons.info_outline),
                                      onPressed: () {
                                        _showPointsInfo(context, client);
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (client.debt != 0)
                                          InkWell(
                                            onTap: () =>
                                                _updateDebt(context, client),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: client.debt > 0
                                                    ? widget.tealGreen
                                                        .withOpacity(0.2)
                                                    : widget.softOrange
                                                        .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    client.debt > 0
                                                        ? Icons.payment
                                                        : Icons.money_off,
                                                    size: 16,
                                                    color: client.debt > 0
                                                        ? widget.tealGreen
                                                        : widget.softOrange,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    client.debt > 0
                                                        ? 'Payer'
                                                        : 'Ajouter dette',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: client.debt > 0
                                                          ? widget.tealGreen
                                                          : widget.softOrange,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        if (client.debt != 0)
                                          SizedBox(width: 8),
                                        if (widget.onClientSelected != null)
                                          InkWell(
                                            onTap: () => _showClientOrders(
                                                context, client),
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: widget.lightGray,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.receipt,
                                                      size: 16,
                                                      color: widget.deepBlue),
                                                  SizedBox(width: 4),
                                                  Text('Commandes',
                                                      style: TextStyle(
                                                          fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => _showClientProducts(
                                              context, client),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: widget.lightGray,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.shopping_basket,
                                                    size: 16,
                                                    color: widget.softOrange),
                                                SizedBox(width: 4),
                                                Text('Produits',
                                                    style: TextStyle(
                                                        fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        IconButton(
                                          icon: Icon(Icons.edit,
                                              color: widget.softOrange),
                                          onPressed: () =>
                                              _showClientForm(client),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
