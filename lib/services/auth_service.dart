import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _storage = const FlutterSecureStorage();
  static const String _kUserKey = 'current_user';

  Future<Map<String, dynamic>?> currentUser() async {
    try {
      final session = supabase.auth.currentSession;
      if (session == null) return null;
      final user = session.user;
      if (user == null) return null;
      return {
        'email': user.email,
        'name': user.userMetadata?['full_name'] ?? user.email,
        'provider': 'supabase',
        'id': user.id,
      };
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    await _storage.delete(key: _kUserKey);
  }

  Future<void> signUpEmail(String email, String password, String name) async {
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      throw Exception('Tous les champs sont obligatoires.');
    }
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
      // Vérification : si une session est présente, l'utilisateur est connecté
      if (response.session != null) {
        return; // succès sans message
      } else if (response.user != null) {
        // L'utilisateur est créé mais pas de session (confirmation email activée)
        throw Exception('Inscription réussie ! Veuillez confirmer votre email.');
      } else {
        // Aucun utilisateur ni session -> erreur (ex: email déjà utilisé)
        throw Exception('Erreur lors de l\'inscription. Vérifiez votre email ou mot de passe.');
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'inscription : ${e.toString()}');
    }
  }

  Future<void> signInEmail(String email, String password) async {
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      throw Exception('Email ou mot de passe incorrect.');
    }
  }
}
