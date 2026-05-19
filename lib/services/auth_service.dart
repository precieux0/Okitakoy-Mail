import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _storage = const FlutterSecureStorage();
  final _supabase = Supabase.instance.client;

  static const _kUserKey = 'current_user';
  static const _kUsersKey = 'users_db';

  Future<Map<String, dynamic>?> currentUser() async {
    final raw = await _storage.read(key: _kUserKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> signOut() async {
    await _storage.delete(key: _kUserKey);
    await _supabase.auth.signOut();
  }

  String _hash(String pwd) =>
      sha256.convert(utf8.encode('okitakoy::$pwd')).toString();

  Future<Map<String, List<String>>> _users() async {
    final raw = await _storage.read(key: _kUsersKey);
    if (raw == null) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(k, List<String>.from(v as List)));
  }

  Future<void> _saveUsers(Map<String, List<String>> users) async {
    await _storage.write(key: _kUsersKey, value: jsonEncode(users));
  }

  /// Synchronise un utilisateur local avec Supabase (table public.profiles)
  Future<void> _syncUserToSupabase(String email, String name) async {
    try {
      // Vérifier si un profil existe déjà
      final existing = await _supabase
          .from('profiles')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (existing == null) {
        // Créer le profil (l'id sera généré automatiquement par trigger ? Non, on utilise l'id de auth.users)
        // On doit d'abord avoir un utilisateur dans auth.users. Ici on utilise l'email comme clé.
        // Pour éviter la complexité, on insère avec un id fictif ? Mieux : on utilise l'email comme PK temporaire.
        // Mais la table profiles attend une foreign key vers auth.users. On va modifier la table : supprimer la FK ou la rendre nullable.
        // Solution rapide : on insère sans l'id (la colonne id est UUID NOT NULL). On va plutôt utiliser l'email comme PK.
        // Pour l'instant, on contourne : on ne sync que si l'utilisateur existe déjà dans auth.users (via Supabase Auth).
        // Comme on n'utilise pas Supabase Auth, on peut créer une table 'profiles' sans FK.
        // Je vais plutôt créer une fonction SQL plus tard. Ici on va juste logger.
        print("Sync Supabase non implémentée car pas d'utilisateur Supabase Auth. Créez un trigger SQL.");
      } else {
        // Mettre à jour le nom
        await _supabase
            .from('profiles')
            .update({'full_name': name})
            .eq('email', email);
      }
    } catch (e) {
      print("Erreur sync Supabase: $e");
    }
  }

  Future<void> signUpEmail(String email, String password, String name) async {
    final users = await _users();
    if (users.containsKey(email)) {
      throw Exception('Un compte existe déjà avec cet e-mail.');
    }
    users[email] = [_hash(password), name];
    await _saveUsers(users);
    await _setUser({'email': email, 'name': name, 'provider': 'email'});
    await _syncUserToSupabase(email, name);
  }

  Future<void> signInEmail(String email, String password) async {
    final users = await _users();
    final entry = users[email];
    if (entry == null || entry[0] != _hash(password)) {
      throw Exception('Identifiants invalides.');
    }
    await _setUser({'email': email, 'name': entry[1], 'provider': 'email'});
    await _syncUserToSupabase(email, entry[1]);
  }

  Future<void> _setUser(Map<String, dynamic> u) async {
    await _storage.write(key: _kUserKey, value: jsonEncode(u));
  }
}
