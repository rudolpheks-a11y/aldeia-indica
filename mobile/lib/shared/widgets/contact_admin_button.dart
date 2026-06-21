import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _adminEmail = 'rudolpheks@hotmail.com';

Future<void> _openAdminEmail(BuildContext context) async {
  final uri = Uri(
    scheme: 'mailto',
    path: _adminEmail,
    queryParameters: {'subject': 'Contato via Aldeia Indica'},
  );
  if (!await launchUrl(uri)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o e-mail.')),
      );
    }
  }
}

/// Botão de texto simples para a tela de login.
class ContactAdminTextButton extends StatelessWidget {
  const ContactAdminTextButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _openAdminEmail(context),
      icon: const Icon(Icons.mail_outline, size: 18),
      label: const Text('Contatar administrador'),
    );
  }
}

/// Ícone para a AppBar da home.
class ContactAdminIconButton extends StatelessWidget {
  const ContactAdminIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Contatar administrador',
      icon: const Icon(Icons.mail_outline),
      onPressed: () => _openAdminEmail(context),
    );
  }
}
