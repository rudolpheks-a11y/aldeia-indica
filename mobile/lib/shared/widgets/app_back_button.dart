import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Botão de voltar padrão das telas internas. Volta para a tela anterior quando
/// há uma na pilha; caso a tela tenha sido aberta diretamente (sem pilha),
/// retorna para a home do morador.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Voltar',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
    );
  }
}
