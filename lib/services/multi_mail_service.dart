import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'guerrilla_mail_service.dart';
import 'mailtm_service.dart';
import 'local_storage_service.dart';

class MailboxInfo {
  final String id;
  final String email;
  final String provider;
  final String token;
  final DateTime createdAt;

  MailboxInfo({
    required this.id,
    required this.email,
    required this.provider,
    required this.token,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'provider': provider,
    'token': token,
    'created_at': createdAt.toIso8601String(),
  };

  factory MailboxInfo.fromJson(Map<String, dynamic> json) => MailboxInfo(
    id: json['id'],
    email: json['email'],
    provider: json['provider'],
    token: json['token'] ?? '',
    createdAt: DateTime.parse(json['created_at']),
  );
}

class MultiMailService {
  static final MultiMailService _instance = MultiMailService._internal();
  factory MultiMailService() => _instance;
  MultiMailService._internal();

  final List<MailboxInfo> _mailboxes = [];
  List<MailboxInfo> get mailboxes => List.unmodifiable(_mailboxes);

  final GuerrillaMailService _guerrilla = GuerrillaMailService();
  final MailTmService _mailTm = MailTmService();

  Future<void> loadMailboxesFromLocal() async {
    final jsonList = await LocalStorageService.loadMailboxes();
    _mailboxes.clear();
    for (var json in jsonList) {
      _mailboxes.add(MailboxInfo.fromJson(json));
    }
  }

  Future<void> _saveMailboxes() async {
    final jsonList = _mailboxes.map((mb) => mb.toJson()).toList();
    await LocalStorageService.saveMailboxes(jsonList);
  }

  Future<void> _saveMessages(String mailboxId, List<Map<String, dynamic>> messages) async {
    await LocalStorageService.saveMessages(mailboxId, messages);
  }

  // Récupération des messages depuis l'API externe + mise en cache
  Future<List<Map<String, dynamic>>> fetchAndCacheMessages(MailboxInfo mailbox) async {
    List<Map<String, dynamic>> freshMessages = [];
    if (mailbox.provider == 'mail.tm') {
      final apiMessages = await _mailTm.getMessages(mailbox.token);
      freshMessages = apiMessages.map((msg) => {
        'id': msg['id'],
        'subject': msg['subject'],
        'from': msg['from'],
        'body': msg['body'],
        'received_at': msg['received_at'],
      }).toList();
    } else if (mailbox.provider == 'guerrillamail') {
      final emails = await _guerrilla.fetchAllEmails();
      freshMessages = emails.map((e) => {
        'id': e['id'],
        'subject': e['subject'],
        'from': e['from'],
        'body': e['body'],
        'received_at': e['received_at'],
      }).toList();
    }
    // Mettre en cache local
    await _saveMessages(mailbox.id, freshMessages);
    return freshMessages;
  }

  // Récupérer les messages en cache d'abord, puis mettre à jour en arrière-plan
  Future<List<Map<String, dynamic>>> getMessages(MailboxInfo mailbox) async {
    final cached = await LocalStorageService.loadMessages(mailbox.id);
    // Mise à jour asynchrone
    fetchAndCacheMessages(mailbox).catchError((e) => print('Erreur refresh: $e'));
    return cached;
  }

  // ----- mail.tm random -----
  Future<MailboxInfo> createMailTmMailbox() async {
    final domains = await _mailTm.getDomains();
    if (domains.isEmpty) throw Exception('Aucun domaine disponible');
    final domain = domains.first;
    final localPart = _mailTm.generateLocalPart();
    final address = '$localPart@$domain';
    final password = _generatePassword();
    final account = await _mailTm.createAccount(address, password);
    final mailbox = MailboxInfo(
      id: account['id']!,
      email: account['email']!,
      provider: 'mail.tm',
      token: account['token']!,
      createdAt: DateTime.now(),
    );
    _mailboxes.add(mailbox);
    await _saveMailboxes();
    return mailbox;
  }

  // ----- mail.tm custom -----
  Future<MailboxInfo> createCustomMailTmMailbox(String customLocalPart) async {
    final cleaned = customLocalPart.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    if (cleaned.isEmpty) {
      throw Exception('Nom personnalisé invalide.');
    }
    final domains = await _mailTm.getDomains();
    if (domains.isEmpty) throw Exception('Aucun domaine disponible');
    final domain = domains.first;
    final address = '$cleaned@$domain';
    final password = _generatePassword();
    try {
      final account = await _mailTm.createAccount(address, password);
      final mailbox = MailboxInfo(
        id: account['id']!,
        email: account['email']!,
        provider: 'mail.tm',
        token: account['token']!,
        createdAt: DateTime.now(),
      );
      _mailboxes.add(mailbox);
      await _saveMailboxes();
      return mailbox;
    } catch (e) {
      throw Exception('Le nom "$cleaned" n\'est pas disponible.');
    }
  }

  // ----- Guerrilla Mail random -----
  Future<MailboxInfo> createGuerrillaMailbox() async {
    final email = await _guerrilla.getEmailAddress();
    final mailbox = MailboxInfo(
      id: email.split('@').first,
      email: email,
      provider: 'guerrillamail',
      token: '',
      createdAt: DateTime.now(),
    );
    _mailboxes.add(mailbox);
    await _saveMailboxes();
    // Récupération immédiate des messages pour initialiser le cache
    await fetchAndCacheMessages(mailbox);
    return mailbox;
  }

  // ----- Guerrilla Mail custom -----
  Future<MailboxInfo> createCustomGuerrillaMailbox(String customLocalPart) async {
    final cleaned = customLocalPart.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleaned.isEmpty) {
      throw Exception('Nom personnalisé invalide (lettres/chiffres uniquement).');
    }
    // Créer une adresse aléatoire (initialise la session)
    await _guerrilla.getEmailAddress();
    final customEmail = await _guerrilla.setCustomEmailUser(cleaned);
    final mailbox = MailboxInfo(
      id: customEmail.split('@').first,
      email: customEmail,
      provider: 'guerrillamail',
      token: '',
      createdAt: DateTime.now(),
    );
    _mailboxes.add(mailbox);
    await _saveMailboxes();
    await fetchAndCacheMessages(mailbox);
    return mailbox;
  }

  // Récupérer tous les messages de toutes les boîtes (affichage)
  Future<List<Map<String, dynamic>>> fetchAllMessagesForDisplay() async {
    List<Map<String, dynamic>> all = [];
    for (final mailbox in _mailboxes) {
      final messages = await getMessages(mailbox);
      all.addAll(messages.map((msg) => {
        'id': msg['id'],
        'subject': msg['subject'],
        'from': msg['from'],
        'mailbox': mailbox.email,
        'body': msg['body'],
      }));
    }
    return all;
  }

  String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecond;
    return List.generate(16, (_) => chars[random % chars.length]).join();
  }
}
