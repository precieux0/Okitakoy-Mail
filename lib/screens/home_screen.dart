import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/mail_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _address;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _user = await AuthService.instance.currentUser();
    _address = await MailService.instance.createInbox();
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _messages = await MailService.instance.listMessages();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _newInbox() async {
    await MailService.instance.reset();
    _address = await MailService.instance.createInbox();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/logo.png', width: 28, height: 28),
          const SizedBox(width: 8),
          const Text('Okitakoy Mail', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.pushNamed(context, '/about'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.instance.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_user != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Bonjour ${_user!['name'] ?? ''} 👋',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ton adresse temporaire',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  const SizedBox(height: 6),
                  SelectableText(
                    _address ?? '...',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    OutlinedButton.icon(
                      onPressed: _address == null
                          ? null
                          : () {
                              Clipboard.setData(ClipboardData(text: _address!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copié !')),
                              );
                            },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copier'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _newInbox,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Nouvelle adresse'),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Boîte de réception',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_messages.isEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(children: [
                  Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text('Aucun message pour le moment',
                      style: TextStyle(color: Color(0xFF64748B))),
                ]),
              )
            else
              ..._messages.map((m) => Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      title: Text(m['subject'] ?? '(sans objet)',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(m['from']?['address'] ?? ''),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final full = await MailService.instance.getMessage(m['id']);
                        if (!mounted) return;
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => Padding(
                            padding: const EdgeInsets.all(20),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(full['subject'] ?? '(sans objet)',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Text('De : ${full['from']?['address'] ?? ''}',
                                      style: const TextStyle(color: Color(0xFF64748B))),
                                  const SizedBox(height: 16),
                                  Text(full['text'] ?? ''),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
