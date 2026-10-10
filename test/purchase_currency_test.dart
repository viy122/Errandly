import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errandly/models/entities.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/ui/account.dart';
import 'package:errandly/ui/post_form.dart';
import 'package:errandly/ui/payment_choices.dart';

Errand purchase({bool pesos = true}) => Errand(
  id: 'purchase-test',
  ownerId: 'anna',
  title: 'Buy supplies',
  category: 'Purchase',
  description: 'Buy one item.',
  pickup: 'Store',
  destination: 'Home',
  budget: 50,
  fee: 110,
  distance: 500,
  deadline: DateTime.now().add(const Duration(days: 1)),
  pesoPurchase: pesos,
);

void finish(ErrandStore s, Errand e, double cost) {
  s.demo('ben');
  s.accept(e);
  s.advance(e);
  s.advance(e);
  s.uploadProof(e, cost, receipt: true, photo: true);
  s.advance(e);
  s.advance(e);
  s.advance(e);
  s.verifyPin(e, e.pin!);
  s.demo('anna');
  s.complete(e);
}

void main() {
  for (final cost in [0.0, 45.0, 49.99, 50.0]) {
    test(
      'purchase cost $cost is reimbursed in pesos without minting coins',
      () {
        final s = ErrandStore()..demo('anna');
        addTearDown(s.dispose);
        final e = purchase();
        final anna = s.wallet.available;
        final ben = s.wallets['ben']!.available;
        s.post(e, 'Errandly Wallet');
        expect(s.wallet.available, anna - 115);
        final funding = s.transactions.singleWhere(
          (t) =>
              t.note.contains('Buy supplies') && t.type == 'Purchase Funding',
        );
        expect(funding.amount, -50);
        expect(funding.currency, 'PHP');
        finish(s, e, cost);
        expect(s.wallet.available, anna - 115);
        expect(s.wallets['ben']!.available, ben + 110);
        expect(s.pesoRefunds, closeTo(50 - cost, .00001));
        final reimbursement = s.transactions.where(
          (t) => t.type == 'Purchase Reimbursement',
        );
        expect(reimbursement.length, cost > 0 ? 1 : 0);
        if (cost > 0) {
          expect(reimbursement.single.amount, cost);
          expect(reimbursement.single.currency, 'PHP');
        }
        final count = s.transactions.length;
        expect(() => s.complete(e), throwsStateError);
        expect(s.transactions.length, count);
        s.demo('ben');
        expect(s.reimbursements, cost);
        s.cashOut(110, '09171234567');
        expect(s.transactions.first.note, contains('₱80'));
        expect(s.wallet.available, ben);
      },
    );
  }
  for (final expire in [false, true]) {
    test(
      '${expire ? 'expiry' : 'cancellation'} refunds coins and pesos separately once',
      () {
        final s = ErrandStore()..demo('anna');
        addTearDown(s.dispose);
        final before = s.wallet.available;
        final e = purchase();
        s.post(e, 'Errandly Wallet');
        void refund() =>
            expire ? s.simulateExpiry(e) : s.cancel(e, 'No longer needed');
        refund();
        expect(s.wallet.available, before);
        expect(s.wallet.refunds, 115);
        expect(s.pesoRefunds, 50);
        expect(() => refund(), throwsStateError);
        expect(s.pesoRefunds, 50);
      },
    );
  }
  test('legacy coin budget keeps its original refund amount', () {
    final s = ErrandStore()..demo('anna');
    addTearDown(s.dispose);
    final before = s.wallet.available;
    final e = purchase(pesos: false);
    s.post(e, 'Errandly Wallet');
    expect(s.wallet.available, before - 165);
    s.cancel(e, 'No longer needed');
    expect(s.wallet.available, before);
    expect(s.wallet.refunds, 165);
    expect(s.pesoRefunds, 0);
  });
  testWidgets(
    'post review separates purchase pesos from runner and service coins',
    (tester) async {
      tester.view.physicalSize = const Size(375, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = ErrandStore()..demo('anna');
      addTearDown(s.dispose);
      var published = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PostForm(store: s, onPublished: () => published = true),
            ),
          ),
        ),
      );
      Future<void> enter(String label, String value) async {
        final field = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      Future<void> press(String label) async {
        final button = find.text(label);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await enter('Errand title', 'Buy supplies');
      await enter('Description', 'Buy one item');
      await enter('Pickup address', 'Store');
      await enter('Delivery address', 'Home');
      await enter('Listing area / city', 'Nasugbu');
      await press('Continue');
      await enter('Item / purchase budget (₱)', '50');
      await enter('Runner payment (CY)', '110');
      await tester.pumpAndSettle();
      expect(find.text('115 CY'), findsOneWidget);
      expect(find.text('₱80'), findsOneWidget);
      expect(find.textContaining('1 CY is used'), findsNothing);
      await press('Continue');
      expect(find.text('115 CY'), findsOneWidget);
      final choices = find.byType(PurchasePaymentChoices);
      expect(choices, findsOneWidget);
      expect(
        find.descendant(of: choices, matching: find.text('₱50')),
        findsNWidgets(2),
      );
      expect(
        tester.widget<PurchasePaymentChoices>(choices).value,
        'GCash Simulation',
      );
      expect(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Purchase budget payment (pesos)',
        ),
        findsNothing,
      );
      final before = s.wallet.available;
      await press('Secure payment & publish');
      expect(published, isTrue);
      expect(s.wallet.available, before - 115);
      expect(s.errands.first.pesoPurchase, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'runner history distinguishes peso reimbursement from coin earnings',
    (tester) async {
      final s = ErrandStore()..demo('anna');
      s.transactions.clear();
      addTearDown(s.dispose);
      final e = purchase();
      s.post(e, 'Errandly Wallet');
      finish(s, e, 45);
      s.demo('ben');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: WalletPage(store: s)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Purchase Reimbursement'), findsOneWidget);
      expect(find.text('+₱45'), findsOneWidget);
      expect(find.text('+110 CY'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
