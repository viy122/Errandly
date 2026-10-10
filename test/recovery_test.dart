import 'package:errandly/models/entities.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/state/personal_preferences.dart';
import 'package:errandly/ui/app.dart';
import 'package:errandly/ui/post_form.dart';
import 'package:errandly/ui/details.dart';
import 'package:errandly/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class RecoveryStorage implements PreferenceStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async => value = data;
}

ErrandStore storeWith(RecoveryStorage storage) =>
    ErrandStore(preferences: PersonalPreferences(storage: storage));

void main() {
  for (final purchased in [false, true]) {
    testWidgets('phone cancellation controls settle with purchase=$purchased', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 873);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = storeWith(RecoveryStorage())..demo();
      final e = s.errands.first;
      s.accept(e);
      if (purchased) {
        s.advance(e);
        s.advance(e);
        s.uploadProof(e, 45, receipt: true, photo: true);
      }
      s.demo('anna');
      s.cancel(e, 'Wrong details');
      s.demo('ben');
      await tester.pumpWidget(
        MaterialApp(
          theme: errandlyTheme(),
          home: Scaffold(
            body: TaskDetails(store: s, errand: e),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Start Errand'), findsNothing);
      final action = find.text(
        purchased ? 'Simulate support decision' : 'Agree to cancel and refund',
      );
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      if (purchased) {
        final approve = find.text('Approve cancellation and settle');
        await tester.ensureVisible(approve);
        await tester.pumpAndSettle();
        await tester.tap(approve);
        await tester.pumpAndSettle();
      }
      expect(e.status, ErrandStatus.cancelled);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    });
  }
  test(
    'cancellation holds progress, needs the other participant, refunds once',
    () async {
      final s = storeWith(RecoveryStorage())..demo();
      addTearDown(s.dispose);
      final e = s.errands.first;
      s.accept(e);
      s.demo('anna');
      final before = s.wallet.available;
      s.cancel(e, 'Incorrect details');
      expect(e.cancellationPending, isTrue);
      expect(() => s.respondCancellation(e, 'approve'), throwsStateError);
      expect(() => s.cancel(e, 'Again'), throwsStateError);
      s.demo('ben');
      expect(() => s.advance(e), throwsStateError);
      s.respondCancellation(e, 'approve');
      expect(e.status, ErrandStatus.cancelled);
      expect(s.wallets['anna']!.available, before + e.total);
      expect(() => s.respondCancellation(e, 'approve'), throwsStateError);
      expect(s.wallets['anna']!.available, before + e.total);
    },
  );

  test('purchased cancellation reimburses recorded cost and compensation separately', () {
    final s = storeWith(RecoveryStorage())..demo();
    addTearDown(s.dispose);
    final e = s.errands.first;
    s.accept(e);
    s.advance(e);
    s.advance(e);
    s.uploadProof(e, 45, receipt: true, photo: true);
    final ben = s.wallet.available;
    s.demo('anna');
    final anna = s.wallet.available;
    s.cancel(e, 'Changed plans');
    s.demo('ben');
    expect(() => s.respondCancellation(e, 'approve'), throwsStateError);
    s.respondCancellation(e, 'approve', support: true, runnerPayment: 10);
    expect(s.wallet.available, ben + 10);
    expect(s.wallets['anna']!.available, anna + e.total - 10);
    expect(e.cancelRefundPurchase, 5);
    expect(
      s.transactions
          .where(
            (t) => t.errandId == e.id && t.type == 'Purchase Reimbursement',
          )
          .single
          .amount,
      45,
    );
    expect(
      () => s.respondCancellation(e, 'approve', support: true),
      throwsStateError,
    );
  });

  test('disagreement holds funds until withdrawal or support rejection', () {
    final s = storeWith(RecoveryStorage())..demo();
    addTearDown(s.dispose);
    final e = s.errands.first;
    s.accept(e);
    s.cancel(e, 'Cannot continue');
    s.demo('anna');
    s.respondCancellation(e, 'reject');
    expect(e.cancellationPending, isTrue);
    expect(() => s.respondCancellation(e, 'withdraw'), throwsStateError);
    s.demo('ben');
    s.respondCancellation(e, 'withdraw');
    expect(e.cancellationPending, isFalse);
    s.advance(e);
    expect(e.progress, 1);
  });

  test('only requester replaces a locked PIN and old PIN no longer works', () {
    final s = storeWith(RecoveryStorage())..demo();
    addTearDown(s.dispose);
    final e = s.errands.first;
    s.accept(e);
    s.advance(e);
    s.advance(e);
    s.uploadProof(e, 45, receipt: true, photo: true);
    for (var i = 0; i < 3; i++) {
      s.advance(e);
    }
    final old = e.pin!;
    for (var i = 0; i < 5; i++) {
      expect(() => s.verifyPin(e, '000000'), throwsStateError);
    }
    expect(() => s.verifyPin(e, old), throwsStateError);
    expect(() => s.resetPin(e), throwsStateError);
    s.demo('anna');
    s.resetPin(e);
    expect(e.pin, isNot(old));
    expect(e.pinAttempts, 0);
    expect(() => s.resetPin(e), throwsStateError);
    s.demo('ben');
    expect(() => s.verifyPin(e, old), throwsStateError);
    s.verifyPin(e, e.pin!);
    s.demo('anna');
    expect(() => s.resetPin(e), throwsStateError);
    s.complete(e);
    expect(e.status, ErrandStatus.completed);
  });

  test('roles and drafts persist independently for each account', () async {
    final storage = RecoveryStorage();
    final prefs = PersonalPreferences(storage: storage);
    await prefs.setRole('ben', false);
    await prefs.setRole('anna', true);
    await prefs.saveDraft('anna', {
      'fields': ['Anna draft'],
      'postId': 'stable-id',
    });
    final restored = PersonalPreferences(storage: storage);
    await restored.load();
    expect(restored.roleFor('ben'), isFalse);
    expect(restored.roleFor('anna'), isTrue);
    expect(restored.draftFor('ben'), isNull);
    expect(restored.draftFor('anna')!['postId'], 'stable-id');
    await restored.saveDraft('anna', null);
    final cleared = PersonalPreferences(storage: storage);
    await cleared.load();
    expect(cleared.draftFor('anna'), isNull);
    expect(cleared.roleFor('anna'), isTrue);
  });

  testWidgets(
    'post draft survives navigating away, refresh and account switching',
    (tester) async {
      tester.view.physicalSize = const Size(393, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = RecoveryStorage();
      final s = storeWith(storage)..demo('anna');
      await s.initialize();
      await tester.pumpWidget(ErrandlyApp(store: s));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post an Errand').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Errand title'),
        'Deliver a sealed package',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post an Errand').last);
      await tester.pumpAndSettle();
      expect(find.text('Deliver a sealed package'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
      final refreshed = storeWith(storage)..demo('anna');
      await refreshed.initialize();
      await tester.pumpWidget(ErrandlyApp(store: refreshed));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post an Errand').last);
      await tester.pumpAndSettle();
      expect(find.byType(PostForm), findsOneWidget);
      expect(find.text('Deliver a sealed package'), findsOneWidget);
      expect(refreshed.preferences.draftFor('ben'), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      refreshed.dispose();
    },
  );
}
