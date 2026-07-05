import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aldeia_indica/features/auth/presentation/register_morador_screen.dart';

void main() {
  Future<void> submit(WidgetTester tester) async {
    final submitButton = find.widgetWithText(ElevatedButton, 'Cadastrar');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'submitting the form completely empty does not require invite codes '
      '(they are the optional fast path, not mandatory)', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: RegisterMoradorScreen()),
    ));

    await submit(tester);

    // Só nome continua obrigatório sem condição — e-mail/senha têm mensagem
    // própria, e os 2 códigos de convite, quando os dois ficam vazios, não
    // devem acusar erro nenhum (esse é o caminho de backup pro admin).
    expect(find.text('Obrigatório'), findsOneWidget); // só o nome
    expect(find.text('Selecione a comunidade'), findsOneWidget);
    expect(find.text('Selecione o condomínio'), findsOneWidget);
    expect(find.text('Informe os dois códigos ou nenhum'), findsNothing);
  });

  testWidgets(
      'filling only one of the two invite codes is rejected — must be both '
      'or neither', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: RegisterMoradorScreen()),
    ));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Código de convite (morador 1) — opcional'),
      'algum-codigo',
    );

    await submit(tester);

    expect(find.text('Informe os dois códigos ou nenhum'), findsOneWidget);
  });
}
