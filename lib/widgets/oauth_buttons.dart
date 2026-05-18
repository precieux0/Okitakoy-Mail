import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class OAuthButtons extends StatefulWidget {
  const OAuthButtons({super.key});
  @override
  State<OAuthButtons> createState() => _OAuthButtonsState();
}

class _OAuthButtonsState extends State<OAuthButtons> {
  bool _busy = false;

  Future<void> _wrap(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProviderButton(
          label: 'Continuer avec Google',
          icon: Icons.g_mobiledata,
          color: const Color(0xFFEA4335),
          onTap: _busy ? null : () => _wrap(AuthService.instance.signInWithGoogle),
        ),
        const SizedBox(height: 10),
        _ProviderButton(
          label: 'Continuer avec GitHub',
          icon: Icons.code,
          color: const Color(0xFF111827),
          onTap: _busy ? null : () => _wrap(AuthService.instance.signInWithGitHub),
        ),
      ],
    );
  }
}

class _ProviderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _ProviderButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: const Color(0xFF0F172A),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
