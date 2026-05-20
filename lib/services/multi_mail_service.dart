import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mailtm_client/mailtm_client.dart';
import 'package:guerrilla_mail_api/guerrilla_mail_api.dart';
import '../main.dart';
import 'auth_service.dart';

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
    'email_address': email,
    'provider': provider,
    'token': token,
    'created_at': createdAt.toIso8601String(),
  };

  factory MailboxInfo.fromJson(Map<String, dynamic> json) => MailboxInfo(
    id: json['id'],
    email: json['email_address'],
    provider: json['provider'],
    token: json['token'] ?? '',
    createdAt: DateTime.parse(json['created_at']),
  );
}

class MessageInfo {
  final String id;
  final String mailboxId;
  final String subject;
  final String from;
  final String body;
  final DateTime receivedAt;

  MessageInfo({
    required this.id,
    required this.mailboxId,
    required this.subject,
    required this.from,
    required this.body,
    required this.receivedAt,
  });
}

class MultiMailService {
  static final MultiMailService _instance = MultiMailService._internal();
  factory MultiMailService() => _instance;
  MultiMailService._internal();

  final List<MailboxInfo> _mailboxes = [];
  List<MailboxInfo> get mailboxes => List.unmodifiable(_mailboxes);

  Future<void> loadMailboxesFromSupabase() async {
    final user = await AuthService.instance.currentUser();
    if (user == null) return;
    final data = await supabase
        .from('user_mailboxes')
        .select()
        .eq('user_id', user['id']);
    _mailboxes.clear();
    for (var row in data) {
      _mailboxes.add(MailboxInfo.fromJson(row));
    }
  }

  void addMailbox(MailboxInfo mailbox) {
    _mailboxes.add(mailbox);
    _saveMailboxToSupabase(mailbox);
  }

  Future<void> _saveMailboxToSupabase(MailboxInfo mailbox) async {
    final user = await AuthService.instance.currentUser();
    if (user == null) return;
    await supabase.from('user_mailboxes').upsert({
      'id': mailbox.id,
      'user_id': user['id'],
      'email_address': mailbox.email,
      'provider': mailbox.provider,
      'token': mailbox.token,
      'is_custom': true, // ou selon le cas
      'created_at': mailbox.createdAt.toIso8601String(),
    });
  }

  void removeMailbox(String id) {
    _mailboxes.removeWhere((m) => m.id == id);
    supabase.from('user_mailboxes').delete().eq('id', id);
  }

  Future<MailboxInfo> createMailTmMailbox() async {
    final mailTm = MailTm();
    final domain = await mailTm.getRandomDomain();
    final password = _generatePassword();
    final localPart = _generateLocalPart();
    final account = await mailTm.createAccount(
      address: '$localPart@$domain',
      password: password,
    );
    final token = await mailTm.getToken(account.address, password);
    final mailbox = MailboxInfo(
      id: account.id,
      email: account.address,
      provider: 'mail.tm',
      token: token,
      createdAt: DateTime.now(),
    );
    addMailbox(mailbox);
    return mailbox;
  }

  Future<MailboxInfo> createCustomMailTmMailbox(String customLocalPart) async {
    final cleaned = customLocalPart.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '');
    if (cleaned.isEmpty) {
      throw Exception('Nom personnalisé invalide. Utilisez a-z, 0-9, point, tiret, underscore.');
    }

    final mailTm = MailTm();
    final domain = await mailTm.getRandomDomain();
    final password = _generatePassword();

    try {
      final account = await mailTm.createAccount(
        address: '$cleaned@$domain',
        password: password,
      );
      final token = await mailTm.getToken(account.address, password);
      final mailbox = MailboxInfo(
        id: account.id,
        email: account.address,
        provider: 'mail.tm',
        token: token,
        createdAt: DateTime.now(),
      );
      addMailbox(mailbox);
      return mailbox;
    } catch (e) {
      throw Exception('Le nom "$cleaned" n\'est pas disponible. Veuillez en choisir un autre.');
    }
  }

  Future<MailboxInfo> createGuerrillaMailbox() async {
    final api = GuerrillaMailApi();
    final email = await api.getEmailAddress();
    final mailbox = MailboxInfo(
      id: email.split('@').first,
      email: email,
      provider: 'guerrillamail',
      token: '',
      createdAt: DateTime.now(),
    );
    addMailbox(mailbox);
    return mailbox;
  }

  Future<List<Map<String, dynamic>>> fetchAllMessages() async {
    List<Map<String, dynamic>> allMessages = [];
    for (final mailbox in _mailboxes) {
      final messages = await fetchMessages(mailbox);
      allMessages.addAll(messages.map((msg) => {
        'id': msg.id,
        'subject': msg.subject,
        'from': msg.from,
        'mailbox': mailbox.email,
        'body': msg.body,
      }));
    }
    return allMessages;
  }

  Future<List<MessageInfo>> fetchMessages(MailboxInfo mailbox) async {
    if (mailbox.provider == 'mail.tm') {
      final mailTm = MailTm();
      mailTm.setToken(mailbox.token);
      final messages = await mailTm.getMessages();
      return messages.map((msg) => MessageInfo(
        id: msg.id,
        mailboxId: mailbox.id,
        subject: msg.subject,
        from: msg.from,
        body: msg.text,
        receivedAt: msg.createdAt,
      )).toList();
    } else if (mailbox.provider == 'guerrillamail') {
      final api = GuerrillaMailApi();
      final emails = await api.checkEmail();
      return emails.map((email) => MessageInfo(
        id: email.mailId.toString(),
        mailboxId: mailbox.id,
        subject: email.mailSubject,
        from: email.mailFrom,
        body: email.mailBody,
        receivedAt: DateTime.now(),
      )).toList();
    }
    return [];
  }

  String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecond;
    return List.generate(16, (_) => chars[random % chars.length]).join();
  }

  String _generateLocalPart() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecond;
    return List.generate(10, (_) => chars[random % chars.length]).join();
  }
}
