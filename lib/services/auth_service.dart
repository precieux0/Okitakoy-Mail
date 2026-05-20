import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _storage = const FlutterSecureStorage();
  static const String _kUserKey = 'current_user';

  Future<Map<String, dynamic>?> currentUser() async {
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
      // Si la confirmation par email est activée, response.user et response.session sont null
      // Mais l'utilisateur a bien été créé.
      if (response.user == null && response.session == null) {
        // On lève une exception avec un message clair pour l'utilisateur
        throw Exception('Un email de confirmation vous a été envoyé. Veuillez vérifier votre boîte de réception.');
      }
      // Si une session est retournée (confirmation désactivée), on est déjà connecté
      // Le SDK gère automatiquement la session.
    } catch (e) {
      // Ré-émettre l'erreur avec un message compréhensible
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
