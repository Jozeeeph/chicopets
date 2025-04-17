import 'package:caissechicopets/home_page.dart';
import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Couleurs
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  Future<void> _createAdminAccount() async {
    if (_usernameController.text.isEmpty || 
        _codeController.text.isEmpty || 
        _confirmCodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez remplir tous les champs'),
          backgroundColor: warmRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    if (_codeController.text != _confirmCodeController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Les codes ne correspondent pas'),
          backgroundColor: warmRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
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
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: warmRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [darkBlue, deepBlue],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo/Icon en haut
                Icon(
                  Iconsax.security_user,
                  size: 80,
                  color: white,
                ),
                const SizedBox(height: 20),
                Text(
                  'Chicopets',
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: white,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Carte de formulaire
                Card(
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  shadowColor: Colors.black.withOpacity(0.2),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Création du Compte Admin',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: darkBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Première utilisation: veuillez créer un compte administrateur',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Champ Nom d'utilisateur
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Nom d\'utilisateur',
                            labelStyle: TextStyle(color: darkBlue),
                            prefixIcon: Icon(Iconsax.user, color: deepBlue),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: lightGray),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: deepBlue, width: 2),
                            ),
                            filled: true,
                            fillColor: lightGray.withOpacity(0.3),
                          ),
                          style: GoogleFonts.poppins(),
                        ),
                        const SizedBox(height: 16),
                        
                        // Champ Code d'accès
                        TextField(
                          controller: _codeController,
                          decoration: InputDecoration(
                            labelText: 'Code d\'accès',
                            labelStyle: TextStyle(color: darkBlue),
                            prefixIcon: Icon(Iconsax.lock, color: deepBlue),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Iconsax.eye_slash : Iconsax.eye,
                                color: deepBlue,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: lightGray),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: deepBlue, width: 2),
                            ),
                            filled: true,
                            fillColor: lightGray.withOpacity(0.3),
                          ),
                          obscureText: _obscurePassword,
                          style: GoogleFonts.poppins(),
                        ),
                        const SizedBox(height: 16),
                        
                        // Champ Confirmation code
                        TextField(
                          controller: _confirmCodeController,
                          decoration: InputDecoration(
                            labelText: 'Confirmer le code',
                            labelStyle: TextStyle(color: darkBlue),
                            prefixIcon: Icon(Iconsax.lock_1, color: deepBlue),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Iconsax.eye_slash : Iconsax.eye,
                                color: deepBlue,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: lightGray),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: deepBlue, width: 2),
                            ),
                            filled: true,
                            fillColor: lightGray.withOpacity(0.3),
                          ),
                          obscureText: _obscureConfirmPassword,
                          style: GoogleFonts.poppins(),
                        ),
                        const SizedBox(height: 32),
                        
                        // Bouton de création
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _createAdminAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tealGreen,
                              foregroundColor: white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Iconsax.user_add, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Créer le Compte',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Texte en bas
                const SizedBox(height: 30),
                Text(
                  'Cette action est irréversible. Assurez-vous de bien mémoriser vos identifiants.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}