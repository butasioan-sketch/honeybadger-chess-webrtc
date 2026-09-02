import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:honey_badger_chess/main.dart';

void main() {
  testWidgets('App startet und zeigt das Hauptmenue', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HoneyBadgerChessApp());

    expect(find.text('Honey Badger Chess'), findsOneWidget);
    expect(find.text('Gegen Computer spielen'), findsOneWidget);
    expect(find.text('Gegen Freund spielen'), findsOneWidget);
    expect(find.text('Visueller Cipher'), findsOneWidget);
  });
}
