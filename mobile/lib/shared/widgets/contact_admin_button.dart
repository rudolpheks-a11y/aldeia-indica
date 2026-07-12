import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _adminEmail = 'rudolpheks@hotmail.com';

/// Abre o e-mail do administrador. Público porque a home agora chama isso
/// direto do menu overflow, sem passar por um dos botões abaixo.
Future<void> openAdminEmail(BuildContext context) async {
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
      onPressed: () => openAdminEmail(context),
      icon: const Icon(Icons.mail_outline, size: 18),
      label: const Text('Contatar administrador'),
    );
  }
}
