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
    try {
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
    } catch (e) {
      throw Exception('Erreur lors de l\'inscription : $e');
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
