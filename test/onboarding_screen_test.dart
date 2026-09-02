import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:honey_badger_chess/main.dart';

void main() {
  setUp(() {
    // Ohne gesetzten Wert -> hasSeenOnboarding() liefert false -> erster
    // Start zeigt das Onboarding.
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const HoneyBadgerChessApp());
    await tester.pump();
  }

  testWidgets('beim allerersten Start erscheint das Onboarding, nicht das '
      'Hauptmenue', (tester) async {
    await pumpApp(tester);

    expect(find.text('Schach zuerst'), findsOneWidget);
    expect(find.text('Gegen Computer spielen'), findsNothing);
  });

  testWidgets('"Überspringen" fuehrt direkt zum Hauptmenue und merkt sich '
      'das', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Überspringen'));
    await tester.pumpAndSettle();

    expect(find.text('Gegen Computer spielen'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_seen'), isTrue);
  });

  testWidgets('durch alle drei Schritte tippen fuehrt zum Hauptmenue', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Schach zuerst'), findsOneWidget);
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    expect(find.text('Optional: ein sicherer Kanal zu zweit'), findsOneWidget);
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    expect(find.text('Optional: der visuelle Cipher'), findsOneWidget);
    await tester.tap(find.text('Los geht\'s'));
    await tester.pumpAndSettle();

    expect(find.text('Gegen Computer spielen'), findsOneWidget);
  });
}
