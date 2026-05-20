import 'dart:convert';
import 'package:http/http.dart' as http;

class GuerrillaMailService {
  static const String _baseUrl = 'https://api.guerrillamail.com/ajax.php';

  /// Récupère une adresse email temporaire
  Future<String> getEmailAddress() async {
    final response = await http.get(Uri.parse('$_baseUrl?f=get_email_address'));
    if (response.statusCode != 200) {
      throw Exception('Erreur Guerrilla Mail: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    return data['email_addr'];
  }

  /// Récupère la liste des emails reçus
  Future<List<Map<String, dynamic>>> fetchEmails() async {
    final response = await http.get(Uri.parse('$_baseUrl?f=fetch_email'));
    if (response.statusCode != 200) {
      throw Exception('Erreur fetch emails: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    final List<dynamic> list = data['list'];
    return list.map((e) => {
      'id': e['mail_id'].toString(),
      'subject': e['mail_subject'],
      'from': e['mail_from'],
      'body': e['mail_body'],
      'received_at': DateTime.now().toIso8601String(),
    }).toList();
  }
}
