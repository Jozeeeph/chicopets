import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/user.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  _AccountsPageState createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final SqlDb _sqlDb = SqlDb();
  List<User> _users = [];
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String _selectedRole = 'cashier';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    _users = await _sqlDb.getAllUsers();
    setState(() => _isLoading = false);
  }

  Future<void> _addUser() async {
    if (_usernameController.text.isEmpty || _codeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    try {
      final newUser = User(
        username: _usernameController.text,
        code: _codeController.text,
        role: _selectedRole,
      );
      await _sqlDb.addUser(newUser);
      _usernameController.clear();
      _codeController.clear();
      await _loadUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur ajouté avec succès')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Comptes'),
        backgroundColor: const Color(0xFF0056A6),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0056A6), Color(0xFF26A9E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Ajouter un Utilisateur',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom d\'utilisateur',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Code d\'accès',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Text('Administrateur'),
                          ),
                          DropdownMenuItem(
                            value: 'cashier',
                            child: Text('Caissier'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Rôle',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _addUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0056A6),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Ajouter',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                          final user = _users[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              title: Text(user.username),
                              subtitle: Text('Rôle: ${user.role}'),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  // Implémentez la suppression ici
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
