import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errandly/models/wallet_rates.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/ui/account.dart';

void main() {
  test('buying coins and cashing them out use separate rates', () {
    expect(WalletRates.coinsForTopUp(50), 55);
    expect(WalletRates.coinsForTopUp(100), 110);
    expect(WalletRates.coinsForTopUp(200), 220);
    expect(WalletRates.coinsForTopUp(500), 550);
    expect(WalletRates.pesosForCashOut(55), 40);
    expect(WalletRates.pesosForCashOut(110), 80);
    expect(WalletRates.pesosForCashOut(220), 160);
    expect(WalletRates.pesosForCashOut(40), 29.09);
    final s = ErrandStore()..demo();
    final before = s.wallet.available;
    s.topUp(100);
    expect(s.wallet.available, before + 110);
    s.cashOut(110, '09171234567');
    expect(s.wallet.available, before);
    expect(s.transactions.first.amount, -110);
    expect(s.transactions.first.note, contains('₱80'));
    expect(s.notifications.first.text, contains('₱80'));
  });

  testWidgets('top-up shows pesos paid and coins received before confirming', (
    tester,
  ) async {
    final s = ErrandStore()..demo();
    final before = s.wallet.available;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WalletAction(store: s)),
      ),
    );
    expect(find.text('You pay in pesos'), findsOneWidget);
    expect(find.text('110 CY'), findsOneWidget);
    expect(s.wallet.available, before);
    await tester.tap(find.widgetWithText(ChoiceChip, '₱200'));
    await tester.pumpAndSettle();
    expect(find.text('220 CY'), findsOneWidget);
    expect(s.wallet.available, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cash-out preview matches the confirmed peso payout', (
    tester,
  ) async {
    final s = ErrandStore()..demo();
    final before = s.wallet.available;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WalletAction(store: s, cashout: true)),
      ),
    );
    expect(find.text('₱80'), findsOneWidget);
    final amount = find.widgetWithText(
      TextFormField,
      'Amount to cash out (CY)',
    );
    await tester.enterText(amount, '220');
    await tester.pumpAndSettle();
    expect(find.text('₱160'), findsOneWidget);
    await tester.enterText(amount, '110');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'GCash number'),
      '09171234567',
    );
    await tester.tap(find.text('Review cash out'));
    await tester.pumpAndSettle();
    expect(find.text('₱80'), findsOneWidget);
    expect(s.wallet.available, before);
    await tester.tap(find.text('Confirm cash out'));
    await tester.pumpAndSettle();
    expect(s.wallet.available, before - 110);
    expect(s.transactions.first.note, contains('₱80'));
    expect(tester.takeException(), isNull);
  });
}
