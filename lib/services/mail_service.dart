import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class MailService {
  MailService._();
  static final instance = MailService._();

  static const _base = 'https://api.mail.tm';
  String? _token;
  String? _accountId;
  String? _address;

  String? get address => _address;

  final _supabase = Supabase.instance.client;

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

  /// Sauvegarde l'adresse email dans Supabase (table custom_emails)
  Future<void> _saveEmailToSupabase(String emailAddress, bool isCustom) async {
    final user = await AuthService.instance.currentUser();
    if (user == null) return;
    try {
      // Récupérer l'id du profil (par email)
      final profile = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', user['email'])
          .maybeSingle();
      if (profile != null) {
        await _supabase.from('custom_emails').insert({
          'user_id': profile['id'],
          'email_address': emailAddress,
          'is_custom': isCustom,
        });
      }
    } catch (e) {
      print("Erreur sauvegarde email dans Supabase: $e");
    }
  }

  /// Sauvegarde un message dans l'historique Supabase
  Future<void> _saveMessageToSupabase(Map<String, dynamic> message) async {
    final user = await AuthService.instance.currentUser();
    if (user == null) return;
    try {
      final profile = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', user['email'])
          .maybeSingle();
      if (profile == null) return;

      // Vérifier si le message existe déjà
      final exists = await _supabase
          .from('email_history')
          .select()
          .eq('user_id', profile['id'])
          .eq('message_id', message['id'])
          .maybeSingle();
      if (exists == null) {
        await _supabase.from('email_history').insert({
          'user_id': profile['id'],
          'message_id': message['id'],
          'subject': message['subject'],
          'from_address': message['from']?['address'],
          'body': message['text'] ?? message['html'],
          'received_at': message['createdAt'] ?? DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print("Erreur sauvegarde historique: $e");
    }
  }

  Future<String> createInbox() async {
    return _createInboxWithLocalPart(null);
  }

  Future<String> createInboxWithCustomLocalPart(String customLocalPart) async {
    if (customLocalPart.isEmpty) {
      throw Exception('Le nom local ne peut pas être vide');
    }
    final cleaned = customLocalPart.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    if (cleaned.isEmpty) {
      throw Exception('Nom local invalide (caractères autorisés : a-z 0-9 . _ -)');
    }
    return _createInboxWithLocalPart(cleaned);
  }

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
    final selectedDomain = domains.first;

    final local = localPart ?? _rand(10);
    final address = '$local@$selectedDomain';
    final password = _rand(16);

    final createRes = await http.post(
      Uri.parse('$_base/accounts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': address, 'password': password}),
    );

    if (createRes.statusCode == 422) {
      throw Exception('Adresse indisponible ou invalide.');
    }
    if (createRes.statusCode != 201) {
      throw Exception('Erreur lors de la création (${createRes.statusCode})');
    }

    final acc = jsonDecode(createRes.body) as Map<String, dynamic>;

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

    // Sauvegarde dans Supabase
    await _saveEmailToSupabase(address, localPart != null);

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
    final messages = (data['hydra:member'] as List).cast<Map<String, dynamic>>();

    // Sauvegarde chaque message dans Supabase (asynchrone, non bloquante)
    for (final msg in messages) {
      _saveMessageToSupabase(msg);
    }
    return messages;
  }

  Future<Map<String, dynamic>> getMessage(String id) async {
    final r = await http.get(
      Uri.parse('$_base/messages/$id'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
