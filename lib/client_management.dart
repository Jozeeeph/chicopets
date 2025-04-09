import 'package:flutter/material.dart';
import 'package:caissechicopets/client.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/client_form.dart';
import 'package:flutter/animation.dart';

class ClientManagementWidget extends StatefulWidget {
  final Function(Client)? onClientSelected;
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  const ClientManagementWidget({Key? key, this.onClientSelected}) : super(key: key);

  @override
  _ClientManagementWidgetState createState() => _ClientManagementWidgetState();
}

class _ClientManagementWidgetState extends State<ClientManagementWidget> with SingleTickerProviderStateMixin {
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
        title: Text('Confirmer la suppression', style: TextStyle(color: widget.darkBlue)),
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
                contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
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
                        Icon(Icons.people_outline, size: 60, color: widget.lightGray),
                        SizedBox(height: 16),
                        Text('Aucun client trouvé', style: TextStyle(color: widget.darkBlue)),
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
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text('Non'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: Text('Oui', style: TextStyle(color: widget.warmRed)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) => _deleteClient(client.id!),
                        child: Card(
                          elevation: 4,
                          margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: widget.tealGreen,
                                    child: Text(
                                      client.name.substring(0, 1).toUpperCase(),
                                      style: TextStyle(color: widget.white),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${client.name} ${client.firstName}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: widget.darkBlue,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          client.phoneNumber,
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.onClientSelected != null)
                                        IconButton(
                                          icon: Icon(Icons.check_circle, color: widget.tealGreen),
                                          onPressed: () {
                                            widget.onClientSelected?.call(client);
                                          },
                                        ),
                                      IconButton(
                                        icon: Icon(Icons.edit, color: widget.softOrange),
                                        onPressed: () => _showClientForm(client),
                                      ),
                                    ],
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
