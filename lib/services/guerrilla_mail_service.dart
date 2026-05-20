import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GuerrillaMailService {
  static const String _baseUrl = 'https://api.guerrillamail.com/ajax.php';
  static const String _sidTokenKey = 'guerrilla_sid_token';

  Future<String> _getSidToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sidTokenKey) ?? '';
  }

  Future<void> _saveSidToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sidTokenKey, token);
  }

  /// Crée une adresse aléatoire et retourne l'email
  Future<String> getEmailAddress() async {
    final response = await http.get(Uri.parse('$_baseUrl?f=get_email_address'));
    if (response.statusCode != 200) {
      throw Exception('Erreur Guerrilla Mail: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    await _saveSidToken(data['sid_token']);
    return data['email_addr'];
  }

  /// Personnalise l'adresse existante (doit être appelée après getEmailAddress)
  Future<String> setCustomEmailUser(String emailUser) async {
    final sidToken = await _getSidToken();
    if (sidToken.isEmpty) {
      throw Exception('Aucune session trouvée. Appelez getEmailAddress() d\'abord.');
    }
    final response = await http.get(Uri.parse(
        '$_baseUrl?f=set_email_user&email_user=$emailUser&sid_token=$sidToken'));
    if (response.statusCode != 200) {
      throw Exception('Erreur lors du changement de nom: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data['error'] != null) {
      throw Exception(data['error']);
    }
    return data['email_addr'];
  }

  /// Récupère les emails reçus
  Future<List<Map<String, dynamic>>> fetchEmails() async {
    final sidToken = await _getSidToken();
    if (sidToken.isEmpty) return [];
    final response = await http.get(Uri.parse('$_baseUrl?f=fetch_email&sid_token=$sidToken'));
    if (response.statusCode != 200) {
      throw Exception('Erreur fetch emails: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    final List<dynamic> list = data['list'] ?? [];
    return list.map((e) => {
      'id': e['mail_id'].toString(),
      'subject': e['mail_subject'],
      'from': e['mail_from'],
      'body': e['mail_body'],
      'received_at': DateTime.now().toIso8601String(),
    }).toList();
  }
}
