import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aldeia_indica/features/auth/presentation/register_morador_screen.dart';

void main() {
  testWidgets(
      'submitting the morador registration form empty requires the 2 invite '
      'codes, not just the original fields', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: RegisterMoradorScreen()),
    ));

    final submitButton = find.widgetWithText(ElevatedButton, 'Cadastrar');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // As duas telas de código de convite (regressão do rascunho por e-mail
    // que foi descartado) precisam aparecer como campos obrigatórios,
    // exatamente como nome/e-mail/senha já eram.
    expect(find.text('Obrigatório'), findsNWidgets(3)); // nome + 2 códigos
    expect(find.text('Selecione a comunidade'), findsOneWidget);
    expect(find.text('Selecione o condomínio'), findsOneWidget);
  });
}
