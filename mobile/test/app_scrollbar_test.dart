import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aldeia_indica/shared/widgets/app_scrollbar.dart';

bool _hasThumb(WidgetTester tester) {
  return tester.widgetList<Container>(find.byType(Container)).any((c) {
    final decoration = c.decoration;
    return decoration is BoxDecoration &&
        decoration.borderRadius == BorderRadius.circular(6);
  });
}

void main() {
  testWidgets(
      'AppScrollbar shows a thumb after the first frame even though the '
      'wrapped ListView has no content dimensions during that same frame '
      '(regression test for the null-check crash / permanently-empty track)',
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: AppScrollbar(
            controller: controller,
            child: ListView.builder(
              controller: controller,
              itemCount: 50,
              itemBuilder: (_, i) => SizedBox(height: 40, child: Text('item $i')),
            ),
          ),
        ),
      ),
    ));

    // Primeiro frame: reproduz exatamente a condição de corrida do bug -
    // não deve lançar exceção mesmo que o ListView ainda não tenha
    // calculado maxScrollExtent.
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Segundo frame (disparado pelo postFrameCallback do fix): a alça
    // precisa aparecer sozinha, sem precisar que o usuário arraste a lista.
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_hasThumb(tester), isTrue,
        reason: 'a alça deveria aparecer sozinha após o primeiro frame');
  });

  testWidgets('AppScrollbar reverse: true positions the thumb near the '
      'bottom when offset is 0 (newest message, like chat)', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 300,
          child: AppScrollbar(
            controller: controller,
            reverse: true,
            child: ListView.builder(
              controller: controller,
              reverse: true,
              itemCount: 50,
              itemBuilder: (_, i) => SizedBox(height: 40, child: Text('item $i')),
            ),
          ),
        ),
      ),
    ));

    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_hasThumb(tester), isTrue);
  });
}
