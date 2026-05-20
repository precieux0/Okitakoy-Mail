import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import '../services/multi_mail_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MultiMailService _mailService = MultiMailService();
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadMailboxes();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.instance.currentUser();
    setState(() => _user = user);
  }

  Future<void> _loadMailboxes() async {
    setState(() => _loading = true);
    await _mailService.loadMailboxesFromSupabase();
    await _refreshMessages();
    setState(() => _loading = false);
  }

  Future<void> _createRandomMailbox() async {
    setState(() => _loading = true);
    try {
      await _mailService.createMailTmMailbox();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boîte aléatoire créée !')),
        );
        await _refreshMessages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createCustomMailbox() async {
    final TextEditingController controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Adresse personnalisée'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'monpseudo',
              helperText: 'Caractères autorisés : a-z, 0-9, . _ -',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Créer'),
              onPressed: () => Navigator.of(context).pop(controller.text),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _loading = true);
      try {
        await _mailService.createCustomMailTmMailbox(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adresse personnalisée créée !')),
          );
          await _refreshMessages();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshMessages() async {
    setState(() => _loading = true);
    try {
      final allMessages = await _mailService.fetchAllMessages();
      setState(() => _messages = allMessages);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du rafraîchissement : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Image.asset('assets/logo.png', width: 28, height: 28),
          const SizedBox(width: 8),
          const Text('Okitakoy Mail', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (value) {
              if (value == 'random') {
                _createRandomMailbox();
              } else if (value == 'custom') {
                _createCustomMailbox();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'random',
                child: Text('Adresse aléatoire (mail.tm)'),
              ),
              const PopupMenuItem(
                value: 'custom',
                child: Text('Adresse personnalisée (mail.tm)'),
              ),
            ],
          ),
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
        onRefresh: _refreshMessages,
        child: Column(
          children: [
            if (_user != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Bonjour ${_user!['name'] ?? ''} 👋',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(child: Text('Aucun message pour le moment'))
                      : ListView.builder(
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: ListTile(
                                title: Text(msg['subject'] ?? '(sans objet)',
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(msg['from'] ?? ''),
                                    Text(msg['mailbox'] ?? '',
                                        style: const TextStyle(fontSize: 10)),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(msg['subject'] ?? '(sans objet)',
                                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 6),
                                            Text('De : ${msg['from'] ?? ''}',
                                                style: const TextStyle(color: Color(0xFF64748B))),
                                            Text('Boîte : ${msg['mailbox'] ?? ''}',
                                                style: const TextStyle(color: Color(0xFF64748B))),
                                            const SizedBox(height: 16),
                                            Text(msg['body'] ?? ''),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
