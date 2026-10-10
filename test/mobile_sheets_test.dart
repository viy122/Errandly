import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/ui/app.dart';
import 'package:errandly/ui/details.dart';
import 'package:errandly/ui/accept_confirmation.dart';

void main() {
  testWidgets(
    'phone details and acceptance use sheets without claiming twice',
    (tester) async {
      tester.view.physicalSize = const Size(393, 873);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = ErrandStore()..demo();
      final e = s.runnerOpportunities.first;
      await tester.pumpWidget(ErrandlyApp(store: s));
      await tester.pumpAndSettle();
      final action = find.text('View & Accept').first;
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(TaskDetails), findsOneWidget);
      final accept = find.widgetWithText(FilledButton, 'Accept Errand');
      await tester.ensureVisible(accept);
      await tester.pumpAndSettle();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(find.byType(AcceptConfirmation), findsOneWidget);
      await tester.tap(find.text('Yes, accept'));
      await tester.pumpAndSettle();
      expect(e.runnerId, 'ben');
      expect(find.byType(TaskDetails), findsOneWidget);
      expect(find.byType(AcceptConfirmation), findsNothing);
      expect(find.text('Start Errand'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('private chat composer clears the phone keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final s = ErrandStore()..demo();
    final e = s.errands.first;
    s.messages.clear();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openChat(context, s, e),
              child: const Text('Open chat'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open chat'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();
    final input = find.byType(TextField);
    await tester.enterText(input, 'Can I pick this up now?');
    expect(
      tester.getBottomRight(find.byTooltip('Send message')).dy,
      lessThanOrEqualTo(553),
    );
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(
      s.conversationMessages(e, 'anna').single.text,
      'Can I pick this up now?',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
