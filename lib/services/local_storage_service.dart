import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _mailboxesKey = 'mailboxes';
  static const String _messagesPrefix = 'messages_';

  // Sauvegarder la liste des boîtes
  static Future<void> saveMailboxes(List<Map<String, dynamic>> mailboxes) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(mailboxes);
    await prefs.setString(_mailboxesKey, jsonString);
  }

  // Charger la liste des boîtes
  static Future<List<Map<String, dynamic>>> loadMailboxes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_mailboxesKey);
    if (jsonString == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(jsonString));
  }

  // Sauvegarder les messages d'une boîte spécifique
  static Future<void> saveMessages(String mailboxId, List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(messages);
    await prefs.setString('$_messagesPrefix$mailboxId', jsonString);
  }

  // Charger les messages d'une boîte
  static Future<List<Map<String, dynamic>>> loadMessages(String mailboxId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_messagesPrefix$mailboxId');
    if (jsonString == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(jsonString));
  }

  // Exporter toutes les données (backup)
  static Future<String> exportBackup() async {
    final mailboxes = await loadMailboxes();
    final Map<String, dynamic> backup = {
      'version': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'mailboxes': mailboxes,
    };
    // Pour chaque boîte, ajouter ses messages
    for (var mb in mailboxes) {
      final messages = await loadMessages(mb['id']);
      backup['messages_${mb['id']}'] = messages;
    }
    final jsonString = jsonEncode(backup);
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/okitakoy_backup.json');
    await file.writeAsString(jsonString);
    return file.path;
  }

  // Importer un backup depuis un fichier
  static Future<void> importBackup(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final backup = jsonDecode(jsonString);
    if (backup['version'] != 1) throw Exception('Version de backup non supportée');
    // Restaurer les boîtes
    await saveMailboxes(List<Map<String, dynamic>>.from(backup['mailboxes']));
    // Restaurer les messages
    for (var mb in backup['mailboxes']) {
      final key = 'messages_${mb['id']}';
      if (backup[key] != null) {
        await saveMessages(mb['id'], List<Map<String, dynamic>>.from(backup[key]));
      }
    }
  }
}
