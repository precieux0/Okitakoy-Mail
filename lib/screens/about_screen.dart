import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('À propos & FAQ')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: Image.asset('assets/logo.png', width: 96, height: 96)),
          const SizedBox(height: 12),
          const Center(
            child: Text('Okitakoy Mail',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          const Center(
            child: Text('par Okitakoy Corp',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          const SizedBox(height: 24),
          _Section(
            title: 'À propos',
            child: Text(
              'Okitakoy Mail est une application de boîte e-mail temporaire '
              'conçue par Okitakoy Corp, fondée par Précieux Okitakoy. '
              'Notre mission : te donner une adresse jetable en un clic '
              'pour protéger ta vraie boîte du spam, des inscriptions '
              'douteuses et du tracking marketing — simplement, sans friction.',
              style: TextStyle(height: 1.5),
            ),
          ),
          const _Section(
            title: 'Notre vision',
            child: Text(
              'Chez Okitakoy Corp, nous croyons à une vie numérique sereine. '
              'Nous bâtissons des outils légers, élégants et respectueux '
              "de la vie privée, pensés d'abord pour l'Afrique et le monde.",
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          const Text('FAQ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const _Faq(
            q: 'Mes e-mails sont-ils stockés ?',
            a: "Non. Les messages restent uniquement le temps de la session sur le service de réception. "
                "Génère une nouvelle adresse à tout moment pour repartir de zéro.",
          ),
          const _Faq(
            q: 'Pourquoi me demander de créer un compte ?',
            a: "Pour te permettre de garder une seule adresse temporaire entre tes sessions "
                "et synchroniser tes préférences. Aucun mot de passe n'est envoyé en clair.",
          ),
          const _Faq(
            q: 'Puis-je envoyer des e-mails ?',
            a: "Non. L'app est en lecture seule : tu reçois, tu lis, tu jettes.",
          ),
          const _Faq(
            q: 'Quels sont les fournisseurs de connexion ?',
            a: "Google, GitHub, ou un classique e-mail + mot de passe stocké localement chiffré.",
          ),
          const _Faq(
            q: 'Qui contacter ?',
            a: 'Okitakoy Corp — fondée par Précieux Okitakoy. Suis-nous pour les nouveautés.',
          ),
          const SizedBox(height: 32),
          const Center(
            child: Text(
              '© Okitakoy Corp — by Précieux Okitakoy',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  final String q, a;
  const _Faq({required this.q, required this.a});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        title: Text(q, style: const TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [Align(alignment: Alignment.centerLeft, child: Text(a, style: const TextStyle(height: 1.4)))],
      ),
    );
  }
}
