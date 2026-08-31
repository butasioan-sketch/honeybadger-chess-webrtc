import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:honey_badger_chess/game_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GameScreen baut ein 8x8-Brett ohne Fehler', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(vsComputer: false)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final file in 'abcdefgh'.split('')) {
      for (var rank = 1; rank <= 8; rank++) {
        expect(find.byKey(ValueKey('square_$file$rank')), findsOneWidget);
      }
    }
    expect(find.text('Weiss am Zug'), findsOneWidget);
  });

  testWidgets('Antippen von e2 dann e4 fuehrt den Zug aus (lokales Spiel)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(vsComputer: false)),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('square_e2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('square_e4')));
    await tester.pump();

    expect(find.text('Schwarz am Zug'), findsOneWidget);
  });
}
