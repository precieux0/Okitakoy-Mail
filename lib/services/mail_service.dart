import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service de boîte mail temporaire utilisant l'API publique mail.tm.
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

  Future<String> createInbox() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('mail_session');
    if (saved != null) {
      final m = jsonDecode(saved) as Map<String, dynamic>;
      _token = m['token']; _accountId = m['id']; _address = m['address'];
      return _address!;
    }
    final domain = (await _domains()).first;
    final address = '${_rand(10)}@$domain';
    final password = _rand(16);

    final create = await http.post(
      Uri.parse('$_base/accounts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': address, 'password': password}),
    );
    final acc = jsonDecode(create.body) as Map<String, dynamic>;

    final tokRes = await http.post(
      Uri.parse('$_base/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': address, 'password': password}),
    );
    final tok = jsonDecode(tokRes.body) as Map<String, dynamic>;
    _token = tok['token']; _accountId = acc['id']; _address = address;

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
