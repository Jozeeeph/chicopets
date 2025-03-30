import 'package:caissechicopets/home_page.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/user.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateAdminAccountPage extends StatefulWidget {
  const CreateAdminAccountPage({super.key});

  @override
  _CreateAdminAccountPageState createState() => _CreateAdminAccountPageState();
}

class _CreateAdminAccountPageState extends State<CreateAdminAccountPage> {
  final SqlDb _sqlDb = SqlDb();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _confirmCodeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createAdminAccount() async {
    if (_usernameController.text.isEmpty || 
        _codeController.text.isEmpty || 
        _confirmCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }

    if (_codeController.text != _confirmCodeController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les codes ne correspondent pas')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final adminUser = User(
        username: _usernameController.text,
        code: _codeController.text,
        role: 'admin',
      );
      await _sqlDb.addUser(adminUser);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0056A6), Color(0xFF26A9E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Création du Compte Administrateur',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0056A6),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Première utilisation: veuillez créer un compte administrateur',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 16),
                    ),
                    const SizedBox(height: 32),
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
                    TextField(
                      controller: _confirmCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Confirmer le code',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 32),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _createAdminAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0056A6),
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: const Text(
                              'Créer le Compte',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}