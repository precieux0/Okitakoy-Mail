import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import '../config/oauth_config.dart';

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  final _storage = const FlutterSecureStorage();
  final _google = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: OAuthConfig.googleWebClientId,
  );

  static const _kUserKey = 'current_user';
  static const _kUsersKey = 'users_db';

  Future<Map<String, dynamic>?> currentUser() async {
    final raw = await _storage.read(key: _kUserKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> signOut() async {
    await _storage.delete(key: _kUserKey);
    try { await _google.signOut(); } catch (_) {}
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

  Future<void> signUpEmail(String email, String password, String name) async {
    final users = await _users();
    if (users.containsKey(email)) {
      throw Exception('Un compte existe déjà avec cet e-mail.');
    }
    users[email] = [_hash(password), name];
    await _saveUsers(users);
    await _setUser({'email': email, 'name': name, 'provider': 'email'});
  }

  Future<void> signInEmail(String email, String password) async {
    final users = await _users();
    final entry = users[email];
    if (entry == null || entry[0] != _hash(password)) {
      throw Exception('Identifiants invalides.');
    }
    await _setUser({'email': email, 'name': entry[1], 'provider': 'email'});
  }

  Future<void> _setUser(Map<String, dynamic> u) async {
    await _storage.write(key: _kUserKey, value: jsonEncode(u));
  }

  Future<void> signInWithGoogle() async {
    final acc = await _google.signIn();
    if (acc == null) throw Exception('Connexion Google annulée.');
    await _setUser({
      'email': acc.email,
      'name': acc.displayName ?? acc.email,
      'photo': acc.photoUrl,
      'provider': 'google',
    });
  }

  Future<void> signInWithGitHub() async {
    if (OAuthConfig.githubClientId.isEmpty) {
      throw Exception('GitHub OAuth non configuré. Voir configuration.md');
    }
    final authUrl =
        'https://github.com/login/oauth/authorize'
        '?client_id=${OAuthConfig.githubClientId}'
        '&scope=read:user%20user:email'
        '&redirect_uri=${Uri.encodeComponent(OAuthConfig.githubRedirectUri)}';

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl,
      callbackUrlScheme: 'okitakoymail', // schéma personnalisé pour redirection après la page HTML
    );
    final code = Uri.parse(result).queryParameters['code'];
    if (code == null) throw Exception('Code GitHub manquant.');

    final tokenRes = await http.post(
      Uri.parse('https://github.com/login/oauth/access_token'),
      headers: {'Accept': 'application/json'},
      body: {
        'client_id': OAuthConfig.githubClientId,
        'client_secret': OAuthConfig.githubClientSecret,
        'code': code,
        'redirect_uri': OAuthConfig.githubRedirectUri,
      },
    );
    final token = (jsonDecode(tokenRes.body) as Map)['access_token'];
    if (token == null) throw Exception('Échec récupération token GitHub.');

    final userRes = await http.get(
      Uri.parse('https://api.github.com/user'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final user = jsonDecode(userRes.body) as Map<String, dynamic>;

    await _setUser({
      'email': user['email'] ?? '${user['login']}@users.noreply.github.com',
      'name': user['name'] ?? user['login'],
      'photo': user['avatar_url'],
      'provider': 'github',
    });
  }
}
