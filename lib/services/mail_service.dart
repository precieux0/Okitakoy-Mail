import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MailService {
  MailService._();
  static final instance = MailService._();

  static const _base = 'https://api.mail.tm';
  String? _token;
  String? _accountId;
  String? _address;

  String? get address => _address;

  Future<List<String>> _domains() async {
    final r = await http.get(Uri.parse('$_base/domains'));
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final list = (data['hydra:member'] as List).cast<Map>();
    return list.map((d) => d['domain'].toString()).toList();
  }

  String _rand(int n) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random.secure();
    return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Crée une boîte avec une adresse aléatoire (comportement actuel)
  Future<String> createInbox() async {
    return _createInboxWithLocalPart(null);
  }

  /// Crée une boîte avec une partie locale personnalisée
  /// Lance une exception si l'adresse est déjà prise ou invalide
  Future<String> createInboxWithCustomLocalPart(String customLocalPart) async {
    if (customLocalPart.isEmpty) {
      throw Exception('Le nom local ne peut pas être vide');
    }
    // Nettoyage simple : pas d'espaces, pas de caractères spéciaux sauf . et _
    final cleaned = customLocalPart.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    if (cleaned.isEmpty) {
      throw Exception('Nom local invalide (caractères autorisés : a-z 0-9 . _ -)');
    }
    return _createInboxWithLocalPart(cleaned);
  }

  /// Interne : si localPart est null → aléatoire
  Future<String> _createInboxWithLocalPart(String? localPart) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('mail_session');
    if (saved != null) {
      final m = jsonDecode(saved) as Map<String, dynamic>;
      _token = m['token']; _accountId = m['id']; _address = m['address'];
      return _address!;
    }

    final domains = await _domains();
    if (domains.isEmpty) throw Exception('Aucun domaine disponible');
    final selectedDomain = domains.first; // tu peux aussi permettre à l'utilisateur de choisir

    final local = localPart ?? _rand(10);
    final address = '$local@$selectedDomain';
    final password = _rand(16);

    // Tentative de création
    final createRes = await http.post(
      Uri.parse('$_base/accounts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': address, 'password': password}),
    );

    if (createRes.statusCode == 422) {
      // Adresse déjà prise ou invalide
      final error = jsonDecode(createRes.body);
      throw Exception('Adresse indisponible ou invalide. ${error['detail'] ?? ''}');
    }
    if (createRes.statusCode != 201) {
      throw Exception('Erreur lors de la création (${createRes.statusCode})');
    }

    final acc = jsonDecode(createRes.body) as Map<String, dynamic>;

    // Obtenir le token
    final tokenRes = await http.post(
      Uri.parse('$_base/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': address, 'password': password}),
    );
    final tok = jsonDecode(tokenRes.body) as Map<String, dynamic>;
    _token = tok['token'];
    _accountId = acc['id'];
    _address = address;

    await prefs.setString('mail_session', jsonEncode({
      'token': _token, 'id': _accountId, 'address': _address,
    }));
    return address;
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mail_session');
    _token = null; _accountId = null; _address = null;
  }

  Future<List<Map<String, dynamic>>> listMessages() async {
    if (_token == null) return [];
    final r = await http.get(
      Uri.parse('$_base/messages'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return (data['hydra:member'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getMessage(String id) async {
    final r = await http.get(
      Uri.parse('$_base/messages/$id'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
