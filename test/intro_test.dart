import 'package:errandly/ui/intro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryIntroPreferences extends IntroPreferences {
  bool seen = false;
  bool fail = false;
  int saves = 0;
  @override
  Future<bool> hasSeen() async {
    if (fail) throw StateError('Storage unavailable');
    return seen;
  }

  @override
  Future<void> markSeen() async {
    saves++;
    if (fail) throw StateError('Storage unavailable');
    seen = true;
  }
}

Widget app(MemoryIntroPreferences preferences, {bool reduced = false}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: IntroGate(
        preferences: preferences,
        child: const Scaffold(body: Text('Welcome to the app')),
      ),
    );

void main() {
  testWidgets('skip opens app and does not repeat on next launch', (
    tester,
  ) async {
    final preferences = MemoryIntroPreferences();
    await tester.pumpWidget(app(preferences));
    await tester.pump();
    await tester.pump();
    expect(find.text('Skip intro'), findsOneWidget);
    await tester.tap(find.text('Skip intro'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to the app'), findsOneWidget);
    expect(preferences.saves, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(preferences));
    await tester.pumpAndSettle();
    expect(find.text('Skip intro'), findsNothing);
    expect(find.text('Welcome to the app'), findsOneWidget);
  });

  testWidgets('unsupported video automatically enters app with no storage', (
    tester,
  ) async {
    final preferences = MemoryIntroPreferences()..fail = true;
    await tester.pumpWidget(app(preferences));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to the app'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion opens app without playing an intro', (
    tester,
  ) async {
    final preferences = MemoryIntroPreferences();
    await tester.pumpWidget(app(preferences, reduced: true));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to the app'), findsOneWidget);
    expect(find.byType(IntroVideo), findsNothing);
    expect(preferences.seen, isTrue);
  });

  for (final size in [const Size(320, 640), const Size(1440, 900)]) {
    testWidgets('intro remains skippable at $size and replay closes', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => replayIntro(context),
                child: const Text('Replay'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Replay'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Continue to Errandly'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Skip intro'));
      await tester.pumpAndSettle();
      expect(find.byType(IntroVideo), findsNothing);
      expect(find.text('Replay'), findsOneWidget);
    });
  }
}
