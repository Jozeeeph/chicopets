import 'package:caissechicopets/services/sqldb.dart';
import 'package:caissechicopets/models/user.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

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
  final TextEditingController _newCodeController = TextEditingController();
  final TextEditingController _confirmNewCodeController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _selectedRole = 'cashier';
  bool _isLoading = true;
  bool _showPassword = false;
  final _formKey = GlobalKey<FormState>();

  // Define the color palette
  final Color deepBlue = const Color(0xFF0056A6);
  final Color darkBlue = const Color.fromARGB(255, 1, 42, 79);
  final Color white = Colors.white;
  final Color lightGray = const Color(0xFFE0E0E0);
  final Color tealGreen = const Color(0xFF009688);
  final Color softOrange = const Color(0xFFFF9800);
  final Color warmRed = const Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      _users = await _sqlDb.getAllUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Liste des utilisateurs actualisée', tealGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Erreur lors du chargement: ${e.toString()}', warmRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  SnackBar _buildSnackBar(String message, Color color) {
    return SnackBar(
      content: Text(message, style: GoogleFonts.poppins(color: white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
    );
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer $fieldName';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Adresse email invalide';
    }
    return null;
  }

  String? _validateCode(String? value) {
    if (value == null || value.isEmpty) return 'Code requis';
    if (value.length != 4) return 'Le code doit contenir 4 chiffres';
    final digitsOnly = RegExp(r'^[0-9]+$');
    if (!digitsOnly.hasMatch(value)) {
      return 'Uniquement des chiffres autorisés';
    }
    return null;
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Veuillez corriger les erreurs', warmRed),
      );
      return;
    }

    try {
      final code = _codeController.text.trim();
      // Check if code already exists
      final existingUser = await _sqlDb.getUserByCode(code);
      if (existingUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Ce code d\'accès est déjà utilisé', warmRed),
        );
        return;
      }

      final newUser = User(
        username: _usernameController.text.trim(),
        code: code,
        role: _selectedRole,
        mail: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
      );

      await _sqlDb.addUser(newUser);
      _usernameController.clear();
      _codeController.clear();
      _emailController.clear();
      await _loadUsers();

      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Utilisateur ajouté avec succès', tealGreen),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Erreur: ${e.toString()}', warmRed),
      );
    }
  }

  Future<void> _showResetCodeDialog(User user) async {
    _newCodeController.clear();
    _confirmNewCodeController.clear();
    bool isValid = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                'Réinitialiser le code',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: darkBlue),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pour ${user.username}',
                      style: GoogleFonts.poppins(color: darkBlue)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _newCodeController,
                    decoration: InputDecoration(
                      labelText: 'Nouveau code (4 chiffres)',
                      labelStyle: TextStyle(color: darkBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.lock, color: deepBlue),
                      errorText: _validateCode(_newCodeController.text),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _showPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: deepBlue),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    obscureText: !_showPassword,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(4),
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    onChanged: (value) => setState(() {
                      isValid =
                          _validateCode(_newCodeController.text) == null &&
                              _newCodeController.text ==
                                  _confirmNewCodeController.text;
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmNewCodeController,
                    decoration: InputDecoration(
                      labelText: 'Confirmer le code',
                      labelStyle: TextStyle(color: darkBlue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: Icon(Icons.lock_outline, color: deepBlue),
                      errorText: _newCodeController.text.isNotEmpty &&
                              _newCodeController.text !=
                                  _confirmNewCodeController.text
                          ? 'Les codes ne correspondent pas'
                          : null,
                    ),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(4),
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    onChanged: (value) => setState(() {
                      isValid =
                          _validateCode(_newCodeController.text) == null &&
                              _newCodeController.text ==
                                  _confirmNewCodeController.text;
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Annuler', style: TextStyle(color: warmRed))),
                ElevatedButton(
                  onPressed: isValid
                      ? () async {
                          try {
                            await _sqlDb.updateUserCode(
                                user.username, _newCodeController.text);
                            await _loadUsers();
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              _buildSnackBar(
                                  'Code mis à jour avec succès', tealGreen),
                            );
                          } catch (e) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              _buildSnackBar(
                                  'Erreur: ${e.toString()}', warmRed),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? tealGreen : Colors.grey,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Valider',
                      style: GoogleFonts.poppins(
                          color: white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditEmailDialog(User user) async {
    _emailController.text = user.mail ?? '';
    bool isValid = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              title: Text(
                'Modifier l\'email',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: darkBlue),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Pour ${user.username}',
                      style: GoogleFonts.poppins(color: darkBlue)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Nouvel email',
                      labelStyle: TextStyle(color: darkBlue),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      prefixIcon: Icon(Icons.email, color: deepBlue),
                      errorText: _validateEmail(_emailController.text),
                    ),
                    onChanged: (value) => setState(() {
                      isValid = _validateEmail(_emailController.text) == null;
                    }),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Annuler', style: TextStyle(color: warmRed))),
                ElevatedButton(
                  onPressed: isValid
                      ? () async {
                          try {
                            await _sqlDb.updateUserEmail(
                                user.username, _emailController.text.trim());
                            await _loadUsers();
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              _buildSnackBar(
                                  'Email mis à jour avec succès', tealGreen),
                            );
                          } catch (e) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              _buildSnackBar(
                                  'Erreur: ${e.toString()}', warmRed),
                            );
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? tealGreen : Colors.grey,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Valider',
                      style: GoogleFonts.poppins(
                          color: white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteUser(int userId, String username) async {
    bool confirm = await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              title: Text(
                'Confirmer la suppression',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, color: darkBlue),
              ),
              content: Text(
                  'Voulez-vous vraiment supprimer l\'utilisateur "$username"? Cette action est irréversible.',
                  style: GoogleFonts.poppins()),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Annuler', style: TextStyle(color: darkBlue))),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: warmRed,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Supprimer',
                      style: GoogleFonts.poppins(color: white)),
                ),
              ],
            );
          },
        ) ??
        false;

    if (confirm) {
      try {
        await _sqlDb.deleteUser(userId);
        await _loadUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Utilisateur supprimé avec succès', tealGreen),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Erreur: ${e.toString()}', warmRed),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _codeController.dispose();
    _newCodeController.dispose();
    _confirmNewCodeController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gestion des Comptes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: darkBlue,
        elevation: 10,
        iconTheme: IconThemeData(color: white),
        actions: [
          IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadUsers,
              tooltip: 'Actualiser'),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [lightGray.withOpacity(0.9), white]),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Add User Card
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                color: white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_add, color: deepBlue, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              'Ajouter un Utilisateur',
                              style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: 'Nom d\'utilisateur',
                            labelStyle: TextStyle(color: darkBlue),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.person, color: deepBlue),
                            filled: true,
                            fillColor: lightGray.withOpacity(0.3),
                          ),
                          validator: (value) =>
                              _validateRequired(value, 'un nom d\'utilisateur'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _codeController,
                          decoration: InputDecoration(
                            labelText: 'Code d\'accès (4 chiffres)',
                            labelStyle: TextStyle(color: darkBlue),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.lock, color: deepBlue),
                            filled: true,
                            fillColor: lightGray.withOpacity(0.3),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _showPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: deepBlue),
                              onPressed: () => setState(
                                  () => _showPassword = !_showPassword),
                            ),
                          ),
                          validator: _validateCode,
                          obscureText: !_showPassword,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(4),
                            FilteringTextInputFormatter.digitsOnly
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email (optionnel)',
                            labelStyle: TextStyle(color: darkBlue),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.email, color: deepBlue),
                            filled: true,
                            fillColor: lightGray.withOpacity(0.3),
                          ),
                          validator: _validateEmail,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          items: [
                            DropdownMenuItem(
                              value: 'admin',
                              child: Row(
                                children: [
                                  Icon(Icons.admin_panel_settings,
                                      color: deepBlue),
                                  const SizedBox(width: 10),
                                  Text('Administrateur',
                                      style:
                                          GoogleFonts.poppins(color: darkBlue)),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'cashier',
                              child: Row(
                                children: [
                                  Icon(Icons.point_of_sale, color: deepBlue),
                                  const SizedBox(width: 10),
                                  Text('Caissier',
                                      style:
                                          GoogleFonts.poppins(color: darkBlue)),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedRole = value!),
                          decoration: InputDecoration(
                            labelText: 'Rôle',
                            labelStyle: TextStyle(color: darkBlue),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            prefixIcon:
                                Icon(Icons.assignment_ind, color: deepBlue),
                            filled: true,
                            fillColor: lightGray.withOpacity(0.3),
                          ),
                          dropdownColor: white,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: IntrinsicWidth(
                            child: ElevatedButton(
                              onPressed: _addUser,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: tealGreen,
                                  minimumSize: const Size.fromHeight(50)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, color: white),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Ajouter Utilisateur',
                                    style: GoogleFonts.poppins(
                                        color: white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Users List Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Liste des Utilisateurs',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: darkBlue),
                ),
              ),
              // Users List
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: deepBlue, strokeWidth: 3),
                      )
                    : _users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 60, color: lightGray),
                                const SizedBox(height: 16),
                                Text(
                                  'Aucun utilisateur trouvé',
                                  style: GoogleFonts.poppins(
                                    color: darkBlue.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return Card(
                                elevation: 3,
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                color: white,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: user.role == 'admin'
                                        ? deepBlue.withOpacity(0.2)
                                        : tealGreen.withOpacity(0.2),
                                    child: Icon(
                                        user.role == 'admin'
                                            ? Icons.admin_panel_settings
                                            : Icons.point_of_sale,
                                        color: user.role == 'admin'
                                            ? deepBlue
                                            : tealGreen),
                                  ),
                                  title: Text(
                                    user.username,
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: darkBlue),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Rôle: ${user.role == 'admin' ? 'Administrateur' : 'Caissier'}',
                                        style: GoogleFonts.poppins(
                                            color: darkBlue.withOpacity(0.7)),
                                      ),
                                      if (user.mail != null &&
                                          user.mail!.isNotEmpty)
                                        Text(
                                          'Email: ${user.mail}',
                                          style: GoogleFonts.poppins(
                                              color: darkBlue.withOpacity(0.7),
                                              fontSize: 12),
                                        ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon:
                                            Icon(Icons.email, color: deepBlue),
                                        onPressed: () =>
                                            _showEditEmailDialog(user),
                                        tooltip: 'Modifier l\'email',
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.vpn_key,
                                            color: tealGreen),
                                        onPressed: () =>
                                            _showResetCodeDialog(user),
                                        tooltip: 'Réinitialiser le code',
                                      ),
                                      IconButton(
                                        icon:
                                            Icon(Icons.delete, color: warmRed),
                                        onPressed: () => _deleteUser(
                                            user.id!, user.username),
                                        tooltip: 'Supprimer l\'utilisateur',
                                      ),
                                    ],
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