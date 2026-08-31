import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honey_badger_chess/cipher_screen.dart';

void main() {
  testWidgets('CipherScreen: Verschluesseln in einem Tab, Entschluesseln im '
      'anderen liefert die urspruengliche Nachricht', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CipherScreen()));
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nachricht'),
      'Hallo Welt',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Passwort'),
      'geheim123',
    );
    await tester.tap(find.text('Verschlüsseln & als Schachpartie zeigen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Halbzüge'), findsOneWidget);
    final moveText = tester
        .widget<SelectableText>(find.byType(SelectableText).first)
        .data!;
    expect(moveText, isNotEmpty);

    await tester.tap(find.text('Entschlüsseln'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Zugfolge einfügen'),
      moveText,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Passwort'),
      'geheim123',
    );
    await tester.tap(find.text('Nachricht entschlüsseln'));
    await tester.pumpAndSettle();

    expect(find.text('Hallo Welt'), findsOneWidget);
  });

  testWidgets('CipherScreen: falsches Passwort zeigt Fehlermeldung', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CipherScreen()));
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nachricht'),
      'geheime Info',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Passwort'),
      'richtig',
    );
    await tester.tap(find.text('Verschlüsseln & als Schachpartie zeigen'));
    await tester.pumpAndSettle();

    final moveText = tester
        .widget<SelectableText>(find.byType(SelectableText).first)
        .data!;

    await tester.tap(find.text('Entschlüsseln'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Zugfolge einfügen'),
      moveText,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Passwort'),
      'falsch',
    );
    await tester.tap(find.text('Nachricht entschlüsseln'));
    await tester.pumpAndSettle();

    expect(
      find.text('Falsches Passwort oder beschaedigte Daten.'),
      findsOneWidget,
    );
  });
}
