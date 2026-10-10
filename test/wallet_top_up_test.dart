import 'dart:async';
import 'dart:convert';

import 'package:errandly/data/errand_api.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/ui/account.dart';
import 'package:errandly/ui/wallet_top_up.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class DelayedTopUpStore extends ErrandStore {
  Completer<void> result = Completer<void>();
  int calls = 0;

  @override
  Future<void> topUp(double pesos, {String method = 'GCash Simulation'}) async {
    calls++;
    await result.future;
    await super.topUp(pesos, method: method);
  }
}

Future<void> tapVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openTopUp(WidgetTester tester, ErrandStore store) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => openWalletAction(context, store),
            child: const Text('Open top up'),
          ),
        ),
      ),
    ),
  );
  await tapVisible(tester, 'Open top up');
}

void main() {
  testWidgets(
    'phone can swipe, edit, confirm and receive one matching receipt',
    (tester) async {
      tester.view.physicalSize = const Size(393, 873);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = ErrandStore()..demo();
      addTearDown(store.dispose);
      final before = store.wallet.available;
      await openTopUp(tester, store);
      expect(find.byType(WalletTopUp), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tapVisible(tester, '₱200');
      await tester.ensureVisible(find.byType(PageView));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Continue with Debit / Credit Card');
      expect(store.wallet.available, before);
      expect(find.text('220 CY'), findsOneWidget);
      await tapVisible(tester, 'Edit top up');
      expect(find.text('Continue with Debit / Credit Card'), findsOneWidget);
      await tapVisible(tester, 'Continue with Debit / Credit Card');
      await tapVisible(tester, 'Confirm simulated top up');
      expect(find.byType(PrintedTopUpReceipt), findsOneWidget);
      expect(tester.getSize(find.byType(PrintedTopUpReceipt)).height, 873);
      expect(find.text('SIMULATED RECEIPT'), findsOneWidget);
      expect(store.wallet.available, before + 220);
      expect(store.transactions.first.note, 'Card Simulation • ₱200');
      expect(tester.takeException(), isNull);
      await tapVisible(tester, 'Print again');
      expect(store.wallet.available, before + 220);
      await tapVisible(tester, 'Done');
      expect(find.byType(WalletTopUp), findsNothing);
      expect(store.wallet.available, before + 220);
    },
  );

  testWidgets(
    'failed payment keeps review open; pending taps cannot credit twice',
    (tester) async {
      final store = DelayedTopUpStore()..demo();
      addTearDown(store.dispose);
      final before = store.wallet.available;
      await openTopUp(tester, store);
      await tapVisible(tester, 'Continue with GCash');
      final confirm = find.widgetWithText(
        FilledButton,
        'Confirm simulated top up',
      );
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pump();
      expect(store.calls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(PrintedTopUpReceipt), findsNothing);
      store.result.completeError(
        StateError('Connection unavailable. Try again.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connection unavailable. Try again.'), findsOneWidget);
      expect(store.wallet.available, before);
      expect(find.byType(PrintedTopUpReceipt), findsNothing);
      store.result = Completer<void>();
      await tester.tap(confirm);
      await tester.pump();
      store.result.complete();
      await tester.pumpAndSettle();
      expect(store.calls, 2);
      expect(store.wallet.available, before + 110);
      expect(find.byType(PrintedTopUpReceipt), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('small screens support large text and reduced-motion receipts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = ErrandStore()..demo();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.6),
            disableAnimations: true,
          ),
          child: Scaffold(body: WalletTopUp(store: store)),
        ),
      ),
    );
    await tapVisible(tester, 'Card');
    await tapVisible(tester, 'Continue with Debit / Credit Card');
    await tapVisible(tester, 'Confirm simulated top up');
    expect(find.text('TOP-UP COMPLETE'), findsOneWidget);
    final transition = tester.widget<FractionalTranslation>(
      find.byKey(const ValueKey('receipt-feed')),
    );
    expect(transition.translation.dy, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'printing feeds the paper from the slot and replays without another credit',
    (tester) async {
      final store = ErrandStore()..demo();
      addTearDown(store.dispose);
      final before = store.wallet.available;
      await openTopUp(tester, store);
      await tapVisible(tester, 'Continue with GCash');
      await tapVisible(tester, 'Confirm simulated top up');
      final paper = find.byKey(const ValueKey('receipt-feed'));
      final button = find.text('Print again');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<FractionalTranslation>(paper).translation.dy, -1);
      await tester.pump(const Duration(milliseconds: 1600));
      final halfway = tester
          .widget<FractionalTranslation>(paper)
          .translation
          .dy;
      expect(halfway, greaterThan(-1));
      expect(halfway, lessThan(0));
      await tester.pumpAndSettle();
      expect(tester.widget<FractionalTranslation>(paper).translation.dy, 0);
      expect(store.wallet.available, before + 110);
      expect(
        store.transactions
            .where(
              (entry) =>
                  entry.type == 'Top Up' && entry.userId == store.currentId,
            )
            .first
            .amount,
        110,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'selected payment method is sent to API; unsupported methods are rejected',
    () async {
      Map<String, dynamic>? payload;
      final client = MockClient((request) async {
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('{"ok":true}', 200);
      });
      final store = ErrandStore.mysql(
        ErrandApi(url: 'http://localhost/api', client: client),
      );
      addTearDown(store.dispose);
      await store.topUp(100, method: 'Card Simulation');
      expect(payload?['method'], 'Card Simulation');
      expect(payload?['pesos'], 100);
      expect(() => store.topUp(100, method: 'Unsupported'), throwsStateError);
    },
  );
}
