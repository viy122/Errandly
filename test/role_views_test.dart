import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errandly/models/entities.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/ui/account.dart';
import 'package:errandly/ui/app.dart';
import 'package:errandly/ui/details.dart';
import 'package:errandly/ui/marketplace.dart';
import 'package:errandly/ui/role_dashboard.dart';

Errand ownRequest(ErrandStore s) => Errand(
  id: 'own-request',
  ownerId: s.currentId!,
  title: 'My parcel request',
  category: 'Delivery',
  description: 'Deliver my parcel.',
  pickup: 'Pickup address',
  destination: 'Delivery address',
  budget: 0,
  fee: 20,
  distance: 1000,
  deadline: DateTime.now().add(const Duration(days: 1)),
);

void main() {
  test('changing mode preserves ownership, wallet and handoff permissions', () {
    final s = ErrandStore()..demo();
    final job = s.errands.first;
    s.accept(job);
    final request = ownRequest(s);
    s.post(request, 'Errandly Wallet');
    final balance = s.wallet.available;
    s.setMode(false);
    expect(s.currentId, 'ben');
    expect(s.requests, contains(request));
    expect(s.requests, isNot(contains(job)));
    expect(s.jobs, contains(job));
    expect(s.jobs, isNot(contains(request)));
    expect(s.runnerOpportunities, isNot(contains(request)));
    expect(s.securedPayments, request.total);
    expect(s.wallet.available, balance);
    expect(() => s.complete(job), throwsStateError);
    // An assigned runner keeps permission to advance their job in either view.
    s.advance(job);
    expect(job.status, ErrandStatus.ongoing);
    expect(() => s.advance(request), throwsStateError);
    s.setMode(true);
    expect(s.wallet.available, balance);
    expect(s.activeJobs, contains(job));
  });

  for (final width in [375.0, 1440.0]) {
    testWidgets('both dashboards and central actions work at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = ErrandStore()..demo();
      final job = s.errands.first;
      s.accept(job);
      final request = ownRequest(s);
      s.post(request, 'Errandly Wallet');
      final balance = s.wallet.available;
      await tester.pumpWidget(ErrandlyApp(store: s));
      await tester.pumpAndSettle();
      expect(find.byType(Marketplace), findsOneWidget);
      expect(find.text(request.title), findsNothing);
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(find.byType(ActiveJobsPage), findsOneWidget);
      expect(find.byType(MyErrands), findsOneWidget);
      expect(find.text(job.title), findsOneWidget);
      expect(find.text(request.title), findsNothing);

      await tester.tap(
        find.text(width >= 980 ? 'Find errands' : 'Find Errands').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('mode-requester')));
      await tester.pumpAndSettle();
      expect(find.byType(RequesterDashboard), findsOneWidget);
      expect(find.text(request.title), findsOneWidget);
      expect(find.text(job.title), findsNothing);
      expect(find.text('Accept errand'), findsNothing);
      expect(s.currentId, 'ben');
      expect(s.wallet.available, balance);
      final postButton = find.widgetWithText(FilledButton, 'Post an Errand');
      await tester.ensureVisible(postButton);
      await tester.pumpAndSettle();
      await tester.tap(postButton);
      await tester.pumpAndSettle();
      expect(find.text('Errand title'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('mode-runner')));
      await tester.pumpAndSettle();
      expect(find.byType(ActiveJobsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('job and request lists separate waiting and completed work', (
    tester,
  ) async {
    final s = ErrandStore()..demo();
    final job = s.errands.first;
    s.accept(job);
    job.status = ErrandStatus.waiting;
    final request = ownRequest(s);
    s.post(request, 'Errandly Wallet');
    request.status = ErrandStatus.waiting;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: s,
              builder: (_, _) => MyErrands(store: s),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(ChoiceChip, 'Awaiting Payment (1)'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Awaiting Payment (1)'));
    await tester.pumpAndSettle();
    expect(find.text(job.title), findsOneWidget);
    expect(find.text(request.title), findsNothing);
    s.setMode(false);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(ChoiceChip, 'Awaiting Confirmation (1)'),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ChoiceChip, 'Awaiting Confirmation (1)'),
    );
    await tester.pumpAndSettle();
    expect(find.text(request.title), findsOneWidget);
    expect(find.text(job.title), findsNothing);
    request.status = ErrandStatus.completed;
    job.status = ErrandStatus.completed;
    s.refresh();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(ChoiceChip, 'Completed (1)'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed (1)'));
    await tester.pumpAndSettle();
    expect(find.text(request.title), findsOneWidget);
    expect(find.text(job.title), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'wallet priorities change but all account activity stays accessible',
    (tester) async {
      final s = ErrandStore()..demo();
      s.entry('ben', 'Refund', 5, 'Test refund');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: s,
                builder: (_, _) => WalletPage(store: s),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Cash out'), findsOneWidget);
      expect(find.text('Runner Earnings'), findsOneWidget);
      expect(find.text('Refund'), findsNothing);
      await tester.ensureVisible(find.text('All activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All activity'));
      await tester.pumpAndSettle();
      expect(find.text('Refund'), findsOneWidget);
      await tester.tap(find.text('This mode'));
      s.setMode(false);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Top up'), findsOneWidget);
      expect(find.text('Refund'), findsOneWidget);
      expect(find.text('Runner Earnings'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'task actions follow assignment even when the view mode changes',
    (tester) async {
      final s = ErrandStore()..demo();
      final job = s.errands.first;
      s.accept(job);
      s.setMode(false);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskDetails(store: s, errand: job),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('YOUR JOB'), findsOneWidget);
      expect(find.text('Start Errand'), findsOneWidget);
      expect(find.text('Cancel errand'), findsNothing);
      s.demo('anna');
      s.setMode(true);
      await tester.pumpAndSettle();
      expect(find.text('YOUR REQUEST'), findsOneWidget);
      expect(find.text('Start Errand'), findsNothing);
      expect(find.text('Cancel errand'), findsOneWidget);
      s.demo('ben');
      s.advance(job);
      s.advance(job);
      s.uploadProof(job, 45, receipt: true, photo: true);
      s.advance(job);
      s.advance(job);
      s.advance(job);
      s.setMode(false);
      await tester.pumpAndSettle();
      expect(find.text('Completion PIN: ${job.pin}'), findsNothing);
      expect(find.text('Verify handoff'), findsOneWidget);
      s.demo('anna');
      s.setMode(true);
      await tester.pumpAndSettle();
      expect(find.text('Completion PIN: ${job.pin}'), findsOneWidget);
      expect(find.text('Verify handoff'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
