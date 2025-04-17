import 'dart:convert';

import 'package:caissechicopets/sqldb.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CodeVerificationPage extends StatefulWidget {
  final String pageName;
  final Widget destinationPage; // Nouveau paramètre pour la page de destination

  const CodeVerificationPage({
    super.key,
    required this.pageName,
    required this.destinationPage, // Paramètre requis
  });

  @override
  _CodeVerificationPageState createState() => _CodeVerificationPageState();
}

class _CodeVerificationPageState extends State<CodeVerificationPage> {
  final SqlDb _sqlDb = SqlDb();
  String _enteredCode = "";
  bool _showError = false;
  bool _isLoading = false;

  // Couleurs optimisées
  final Color lightBlue = const Color(0xFF26A9E0);
  final Color darkBlue = const Color(0xFF0056A6);
  final Color lightText = const Color(0xFFF5F5F5);
  final Color buttonColor = const Color(0xFFE3F2FD);
  final Color errorColor = const Color(0xFFFFCDD2);

  void _onNumberPressed(String number) async {
    if (_isLoading) return;

    setState(() {
      if (_enteredCode.length < 4) {
        _enteredCode += number;
        _showError = false;
      }

      if (_enteredCode.length == 4) {
        _verifyCode();
      }
    });
  }

// Dans la méthode _verifyCode de code_verification_page.dart
  Future<void> _verifyCode() async {
    setState(() => _isLoading = true);

    final user = await _sqlDb.getUserByCode(_enteredCode);

    if (user != null && user.isActive) {
      // Sauvegarder la session utilisateur
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', jsonEncode(user.toMap()));

      // Vérifier les autorisations
      if (widget.pageName == 'Tableau de bord') {
        if (user.role == 'admin') {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => widget.destinationPage),
          );
        } else {
          setState(() {
            _showError = true;
            _enteredCode = "";
            _isLoading = false;
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Accès réservé aux administrateurs')),
          );
        }
      }
      // Pour la page de commande, tous les utilisateurs actifs peuvent accéder
      else if (widget.pageName == 'Passage de commande') {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => widget.destinationPage),
        );
      }
    } else {
      setState(() {
        _showError = true;
        _enteredCode = "";
        _isLoading = false;
      });
    }
  }

  void _onBackspacePressed() {
    setState(() {
      if (_enteredCode.isNotEmpty) {
        _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1);
        _showError = false;
      }
    });
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 60,
                  color: const Color.fromARGB(255, 1, 42, 79),
                ),
                const SizedBox(height: 24),
                Text(
                  'Accès sécurisé',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: lightText,
                    shadows: [
                      Shadow(
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entrez votre code pour accéder à ${widget.pageName}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color.fromARGB(255, 1, 42, 79),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Indicateurs de code
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < _enteredCode.length
                            ? lightText
                            : lightText.withOpacity(0.3),
                        border: Border.all(
                          color: lightText.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    );
                  }),
                ),
                if (_showError)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: errorColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              color: errorColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Code incorrect',
                            style: GoogleFonts.poppins(
                              color: errorColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
                // Clavier numérique
                SizedBox(
                  width: 280,
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    childAspectRatio: 1.2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      for (int i = 1; i <= 9; i++)
                        _buildNumberButton(i.toString()),
                      const SizedBox.shrink(),
                      _buildNumberButton("0"),
                      _buildBackspaceButton(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0056A6),
        title: Text(
          'Accès ${widget.pageName}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: lightText,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: IconThemeData(color: lightText),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: () => _onNumberPressed(number),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: buttonColor.withOpacity(0.2),
            border: Border.all(
              color: lightText.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: lightText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(50),
        onTap: _onBackspacePressed,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: buttonColor.withOpacity(0.2),
            border: Border.all(
              color: lightText.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              size: 26,
              color: lightText,
            ),
          ),
        ),
      ),
    );
  }
}
