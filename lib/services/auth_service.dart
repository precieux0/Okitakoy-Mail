import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _storage = const FlutterSecureStorage();
  static const String _kUserKey = 'current_user';

  final String _supabaseUrl = 'https://ckhzttmzacsafkschtuv.supabase.co';
  final String _supabaseAnonKey = 'sb_publishable_WvPEgzcKbzIVZvNGQKlwzA_uBRhGOkS';

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

  // Inscription via API REST directe (contourne les problèmes du SDK)
  Future<void> signUpEmail(String email, String password, String name) async {
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      throw Exception('Tous les champs sont obligatoires.');
    }
    final url = Uri.parse('$_supabaseUrl/auth/v1/signup');
    final headers = {
      'apikey': _supabaseAnonKey,
      'Content-Type': 'application/json',
    };
    final body = jsonEncode({
      'email': email,
      'password': password,
      'data': {'full_name': name},
    });
    try {
      final response = await http.post(url, headers: headers, body: body);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (data['session'] != null) {
          // Session retournée (confirmation email désactivée) : l'utilisateur est automatiquement connecté
          // On ne fait rien de plus, le SDK gère déjà la session via les cookies HTTP?
          // Pour garantir la session, on peut laisser le SDK se mettre à jour automatiquement.
          // Mais pour éviter l'erreur de setSession, on ne fait rien ici.
          return;
        } else if (data['user'] != null) {
          throw Exception('Inscription réussie ! Veuillez confirmer votre email.');
        } else {
          throw Exception('Erreur inconnue lors de l\'inscription.');
        }
      } else {
        String errorMsg = data['error_description'] ?? data['msg'] ?? 'Erreur serveur.';
        throw Exception(errorMsg);
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
