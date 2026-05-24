import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GuerrillaMailService {
  static const String _baseUrl = 'https://api.guerrillamail.com/ajax.php';
  static const String _sidTokenKey = 'guerrilla_sid_token';
  static const String _seqKey = 'guerrilla_seq';

  Future<String> _getSidToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sidTokenKey) ?? '';
  }

  Future<void> _saveSidToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sidTokenKey, token);
  }

  Future<int> _getSeq() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_seqKey) ?? 0;
  }

  Future<void> _saveSeq(int seq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_seqKey, seq);
  }

  /// Crée une adresse aléatoire et retourne l'email
  Future<String> getEmailAddress() async {
    final response = await http.get(Uri.parse('$_baseUrl?f=get_email_address'));
    if (response.statusCode != 200) {
      throw Exception('Erreur Guerrilla Mail: ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    await _saveSidToken(data['sid_token']);
    await _saveSeq(0);
    return data['email_addr'];
  }

  /// Personnalise l'adresse existante
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
    await _saveSeq(0);
    return data['email_addr'];
  }

  /// Récupère les nouveaux emails depuis le dernier séquenceur
  Future<List<Map<String, dynamic>>> fetchNewEmails() async {
    final sidToken = await _getSidToken();
    if (sidToken.isEmpty) return [];

    final currentSeq = await _getSeq();
    final response = await http.get(Uri.parse(
        '$_baseUrl?f=check_email&sid_token=$sidToken&seq=$currentSeq'));
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final List<dynamic> newList = data['list'] ?? [];

    if (newList.isNotEmpty) {
      int maxSeq = currentSeq;
      for (var email in newList) {
        if (email['mail_id'] > maxSeq) maxSeq = email['mail_id'];
      }
      await _saveSeq(maxSeq);
    }

    return newList.map((e) => {
      'id': e['mail_id'].toString(),
      'subject': e['mail_subject'] ?? '',
      'from': e['mail_from'] ?? '',
      'body': e['mail_body'] ?? '',
      'received_at': DateTime.now().toIso8601String(),
    }).toList();
  }

  /// Récupère tous les emails (depuis le début si seq=0)
  Future<List<Map<String, dynamic>>> fetchAllEmails() async {
    return fetchNewEmails(); // check_email avec seq=0 renvoie les 20 derniers emails
  }
}
