import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class MailTmService {
  static const String _baseUrl = 'https://api.mail.tm';

  /// Récupère la liste des domaines disponibles
  Future<List<String>> getDomains() async {
    final response = await http.get(Uri.parse('$_baseUrl/domains'));
    if (response.statusCode != 200) {
      throw Exception('Erreur mail.tm: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    final List<dynamic> members = data['hydra:member'];
    return members.map((d) => d['domain'].toString()).toList();
  }

  /// Génère un mot de passe aléatoire
  String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(16, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Crée un compte mail.tm et retourne (id, email, token)
  Future<Map<String, String>> createAccount(String address, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/accounts'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': address, 'password': password}),
    );
    if (response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception('Erreur création compte mail.tm: ${error['detail'] ?? response.body}');
    }
    final data = jsonDecode(response.body);
    final accountId = data['id'];
    // Obtenir le token
    final tokenRes = await http.post(
      Uri.parse('$_baseUrl/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'address': address, 'password': password}),
    );
    final tokenData = jsonDecode(tokenRes.body);
    return {
      'id': accountId,
      'email': address,
      'token': tokenData['token'],
    };
  }

  /// Récupère les messages d'une boîte mail
  Future<List<Map<String, dynamic>>> getMessages(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/messages'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    final List<dynamic> members = data['hydra:member'];
    return members.map((msg) => {
      'id': msg['id'],
      'subject': msg['subject'] ?? '',
      'from': msg['from']?['address'] ?? '',
      'body': msg['text'] ?? msg['html'] ?? '',
      'received_at': msg['createdAt'] ?? DateTime.now().toIso8601String(),
    }).toList();
  }

  /// Génére une partie locale aléatoire
  String generateLocalPart() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
