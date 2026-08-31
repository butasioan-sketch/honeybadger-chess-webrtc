import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:honey_badger_chess/cipher_screen.dart';
import 'package:honey_badger_chess/visual_chess_cipher.dart';

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Bedingung nicht innerhalb von $timeout erfuellt.');
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump();
}

void main() {
  // `compute()` (echtes Isolate) haengt sich nachweislich innerhalb von
  // testWidgets()/TestWidgetsFlutterBinding auf (bestaetigt mit einem
  // Minimal-Repro ganz ohne Cipher-Code - ein Flutter-Testumgebungs-
  // Problem). In der App bleibt compute() aktiv; hier ersetzen wir es durch
  // denselben PBKDF2-Aufruf ohne Isolate.
  setUpAll(() {
    deriveKeyBytesRunner = deriveKeyBytesInline;
  });
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
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.textContaining('Halbzüge').evaluate().isNotEmpty,
    );

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
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.text('Hallo Welt').evaluate().isNotEmpty,
    );

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
      'richtig123',
    );
    await tester.tap(find.text('Verschlüsseln & als Schachpartie zeigen'));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.byType(SelectableText).evaluate().isNotEmpty,
    );

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
      'falsch12',
    );
    await tester.tap(find.text('Nachricht entschlüsseln'));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find
          .text('Falsches Passwort oder beschaedigte Daten.')
          .evaluate()
          .isNotEmpty,
    );

    expect(
      find.text('Falsches Passwort oder beschaedigte Daten.'),
      findsOneWidget,
    );
  });
}
