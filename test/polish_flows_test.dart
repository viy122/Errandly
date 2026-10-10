import 'dart:async';

import 'package:errandly/models/entities.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/state/personal_preferences.dart';
import 'package:errandly/ui/app.dart';
import 'package:errandly/ui/account.dart';
import 'package:errandly/ui/details.dart';
import 'package:errandly/ui/auth.dart';
import 'package:errandly/ui/motion.dart';
import 'package:errandly/ui/notification_settings.dart';
import 'package:errandly/ui/onboarding.dart';
import 'package:errandly/ui/pin_input.dart';
import 'package:errandly/ui/transaction_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryPreferenceStorage implements PreferenceStorage {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async {
    if (fail) throw StateError('Unavailable');
    value = data;
  }
}

class DelayedLoginStore extends ErrandStore {
  final completion = Completer<void>();
  int calls = 0;
  @override
  Future<void> login(String email, String password) async {
    calls++;
    await completion.future;
    await super.login(email, password);
  }
}

class DelayedPreferenceStorage extends MemoryPreferenceStorage {
  final initialRead = Completer<String?>();
  @override
  Future<String?> read() => initialRead.future;
}

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 873);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'slow device storage preserves guide and existing account choices',
    (tester) async {
      final storage = DelayedPreferenceStorage();
      final prefs = PersonalPreferences(storage: storage);
      final loaded = prefs.load();
      await tester.pump(const Duration(seconds: 2));
      storage.initialRead.complete(
        '{"guideSeen":true,"accounts":{"ben":{"Sound":false,"Wallet":false}}}',
      );
      await tester.pump();
      await loaded;
      expect(prefs.guideSeen, isTrue);
      expect(prefs.forAccount('ben').sound, isFalse);
      await prefs.setAlert('anna', 'Messages', false);
      final restored = PersonalPreferences(
        storage: MemoryPreferenceStorage()..value = storage.value,
      );
      await restored.load();
      expect(restored.guideSeen, isTrue);
      expect(restored.forAccount('ben').wallet, isFalse);
      expect(restored.forAccount('anna').messages, isFalse);
    },
  );

  testWidgets('storage timeout never overwrites unread saved preferences', (
    tester,
  ) async {
    final storage = DelayedPreferenceStorage();
    final prefs = PersonalPreferences(storage: storage);
    final loaded = prefs.load();
    await tester.pump(const Duration(seconds: 11));
    await loaded;
    await expectLater(prefs.setAlert('ben', 'Sound', false), throwsStateError);
    expect(storage.value, isNull);
    expect(prefs.forAccount('ben').sound, isFalse);
  });

  test(
    'notification choices and guide completion persist separately per account',
    () async {
      final storage = MemoryPreferenceStorage();
      final prefs = PersonalPreferences(storage: storage);
      await prefs.setAlert('ben', 'Wallet', false);
      await prefs.setAlert('ben', 'Sound', false);
      await prefs.setAlert('anna', 'Messages', false);
      await prefs.completeGuide();
      final nextLaunch = PersonalPreferences(storage: storage);
      await nextLaunch.load();
      expect(nextLaunch.guideSeen, isTrue);
      expect(nextLaunch.forAccount('ben').wallet, isFalse);
      expect(nextLaunch.forAccount('ben').messages, isTrue);
      expect(nextLaunch.forAccount('ben').sound, isFalse);
      expect(nextLaunch.forAccount('anna').wallet, isTrue);
      expect(nextLaunch.forAccount('anna').messages, isFalse);
      expect(nextLaunch.forAccount('joshua').wallet, isTrue);
    },
  );

  test(
    'failed preference saving reports failure and later writes recover',
    () async {
      final storage = MemoryPreferenceStorage()..fail = true;
      final prefs = PersonalPreferences(storage: storage);
      await expectLater(
        prefs.setAlert('ben', 'Wallet', false),
        throwsStateError,
      );
      expect(prefs.forAccount('ben').wallet, isFalse);
      storage.fail = false;
      await prefs.setAlert('ben', 'Sound', false);
      final nextLaunch = PersonalPreferences(storage: storage);
      await nextLaunch.load();
      expect(nextLaunch.forAccount('ben').wallet, isFalse);
      expect(nextLaunch.forAccount('ben').sound, isFalse);
    },
  );

  testWidgets('wallet history opens a receipt without moving money', (
    tester,
  ) async {
    phone(tester);
    final s = ErrandStore()..demo();
    s.topUp(100);
    final entry = s.transactions.first;
    final balance = s.wallet.available;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: WalletPage(store: s)),
        ),
      ),
    );
    await tapVisible(tester, find.byKey(ValueKey('receipt-${entry.id}')));
    expect(find.byType(TransactionReceipt), findsOneWidget);
    expect(find.text('110 CY'), findsWidgets);
    expect(find.text('₱100'), findsOneWidget);
    expect(find.text(entry.id), findsOneWidget);
    expect(s.wallet.available, balance);
    await tester.tap(find.byTooltip('Close receipt'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionReceipt), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('peso receipt preserves currency and backend reference', (
    tester,
  ) async {
    phone(tester);
    final s = ErrandStore()..demo();
    final entry = WalletEntry(
      'ben',
      'Purchase Reimbursement',
      45,
      'Separate peso transfer',
      currency: 'PHP',
      id: '42',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionReceipt(store: s, entry: entry),
        ),
      ),
    );
    expect(find.text('₱45'), findsWidgets);
    expect(find.text('45 CY'), findsNothing);
    expect(find.text('ER-00000042'), findsOneWidget);
    expect(
      find.textContaining('not added to or taken from the coin balance'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('older receipt never invents an original peso amount', (
    tester,
  ) async {
    phone(tester);
    final s = ErrandStore()..demo();
    final entry = WalletEntry(
      'ben',
      'Top Up',
      110,
      'Historical top-up',
      id: '41',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionReceipt(store: s, entry: entry),
        ),
      ),
    );
    expect(
      find.textContaining('Original peso amount is unavailable'),
      findsOneWidget,
    );
    expect(find.text('Peso payment'), findsNothing);
    expect(find.text('₱100'), findsNothing);
    expect(find.text('At current cash-out rate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('six-digit PIN supports whole-code paste and digit filtering', (
    tester,
  ) async {
    phone(tester);
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(18),
            child: CompletionPinInput(controller: controller),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('completion-pin-input')),
      '12a345678',
    );
    await tester.pumpAndSettle();
    expect(controller.text, '123456');
    await tester.enterText(
      find.byKey(const ValueKey('completion-pin-input')),
      '654321',
    );
    await tester.pumpAndSettle();
    expect(controller.text, '654321');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'handoff feedback waits for requester confirmation before release',
    (tester) async {
      phone(tester);
      final s = ErrandStore()..demo();
      final e = s.errands.first;
      final balance = s.wallet.available;
      s.accept(e);
      s.advance(e);
      s.advance(e);
      s.uploadProof(e, 45, receipt: true, photo: true);
      s.advance(e);
      s.advance(e);
      s.advance(e);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskDetails(store: s, errand: e),
          ),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('completion-pin-input')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('completion-pin-input')),
        '000000',
      );
      await tapVisible(tester, find.text('Verify handoff'));
      expect(find.byType(SuccessFeedback), findsNothing);
      expect(e.handoffVerified, isFalse);
      expect(s.wallet.available, balance);
      await tester.enterText(
        find.byKey(const ValueKey('completion-pin-input')),
        e.pin!,
      );
      await tapVisible(tester, find.text('Verify handoff'));
      expect(e.status, ErrandStatus.waiting);
      expect(find.byType(SuccessFeedback), findsOneWidget);
      expect(find.text('Payment released'), findsNothing);
      expect(s.wallet.available, balance);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      s.demo('anna');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Yes, Complete Errand'));
      expect(find.text('Payment released'), findsOneWidget);
      expect(e.status, ErrandStatus.completed);
      expect(s.wallets['ben']!.available, balance + 40);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('settings mute badges while retaining inbox history', (
    tester,
  ) async {
    phone(tester);
    final prefs = PersonalPreferences(storage: MemoryPreferenceStorage());
    final s = ErrandStore(preferences: prefs)..demo();
    s.notifications.clear();
    s.notice('ben', 'Wallet', 'Saved wallet update');
    expect(s.hasUnreadAlerts, isTrue);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotificationSettings(store: s)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('notification-Wallet')));
    await tester.pumpAndSettle();
    expect(s.hasUnreadAlerts, isFalse);
    expect(s.notifications.single.text, 'Saved wallet update');
    expect(prefs.forAccount('anna').wallet, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'new alerts follow category settings and clear when accounts change',
    (tester) async {
      phone(tester);
      final prefs = PersonalPreferences(storage: MemoryPreferenceStorage());
      await prefs.setAlert('ben', 'Wallet', false);
      await prefs.setAlert('ben', 'Sound', false);
      final s = ErrandStore(preferences: prefs)..demo();
      await tester.pumpWidget(ErrandlyApp(store: s));
      await tester.pumpAndSettle();
      s.notice('ben', 'Wallet', 'Muted wallet update');
      s.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      s.notice('ben', 'Errands', 'Runner arrived');
      s.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Errands · Runner arrived'), findsOneWidget);
      s.demo('anna');
      await tester.pumpAndSettle();
      expect(find.text('Errands · Runner arrived'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'guide completes all steps and does not repeat after restarting',
    (tester) async {
      phone(tester);
      final storage = MemoryPreferenceStorage();
      final prefs = PersonalPreferences(storage: storage);
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingGate(
            preferences: prefs,
            child: const Scaffold(body: Text('App ready')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('One account. Two ways to help.'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('₱100 → 110 CY'), findsOneWidget);
      expect(find.text('Cash out 110 CY → ₱80'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('3. Requester confirms'), findsOneWidget);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('App ready'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingGate(
            preferences: PersonalPreferences(storage: storage),
            child: const Scaffold(body: Text('App ready')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingGuide), findsNothing);
      expect(find.text('App ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('login shows loading and prevents repeated submission', (
    tester,
  ) async {
    phone(tester);
    final s = DelayedLoginStore();
    await tester.pumpWidget(ErrandlyApp(store: s));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Log in'));
    expect(find.byType(AuthForm), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ben@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'demo123',
    );
    await tester.ensureVisible(find.text('Log in').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log in').last);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Signing in…'), findsOneWidget);
    expect(s.calls, 1);
    final button = find.ancestor(
      of: find.text('Signing in…'),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    s.completion.complete();
    await tester.pumpAndSettle();
    expect(s.currentId, 'ben');
    expect(find.byType(AuthForm), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
