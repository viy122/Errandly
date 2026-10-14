import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errandly/ui/app.dart';
import 'package:errandly/ui/details.dart';
import 'package:errandly/ui/account.dart';
import 'package:errandly/ui/auth.dart';
import 'package:errandly/ui/post_form.dart';
import 'package:errandly/state/errand_store.dart';

import 'login_helpers.dart';

void main() {
  testWidgets(
    'posting accepts custom addresses, kilometres and a multi-day deadline',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = ErrandStore()..demo('anna');
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
        final finder = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(finder);
        await tester.enterText(finder, value);
      }

      await enter('Errand title', 'Deliver to another province');
      await enter('Description', 'Please deliver the sealed envelope.');
      await enter('Pickup address', '123 Sample Street, Quezon City');
      await enter('Delivery address', '456 Sample Road, Cavite');
      await enter('Listing area / city', 'Quezon City to Cavite');
      await enter('Estimated distance (km)', '65');
      final deadlineField = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Deadline',
      );
      await tester.ensureVisible(deadlineField);
      await tester.pumpAndSettle();
      await tester.tap(deadlineField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('In 3 days').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await enter('Item / purchase budget (₱)', '0');
      await enter('Runner payment (CY)', '450');
      await tester.ensureVisible(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Secure payment & publish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Secure payment & publish'));
      await tester.pumpAndSettle();
      expect(published, isTrue);
      final e = s.errands.first;
      expect(e.title, 'Deliver to another province');
      expect(e.pickup, '123 Sample Street, Quezon City');
      expect(e.destination, '456 Sample Road, Cavite');
      expect(e.area, 'Quezon City to Cavite');
      expect(e.distance, 65000);
      expect(
        e.deadline.difference(DateTime.now()).inHours,
        greaterThanOrEqualTo(71),
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [375.0, 1440.0]) {
    testWidgets(
      'demo login switches accounts without losing shared errands at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = ErrandStore()..demo();
        final e = s.errands.first;
        s.accept(e);
        final benBalance = s.wallet.available;
        final annaBalance = s.wallets['anna']!.available;
        await tester.pumpWidget(ErrandlyApp(store: s));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('nav-3')));
        await tester.pumpAndSettle();
        await demoLogin(tester, s, 'anna');
        await tester.tap(find.byKey(const ValueKey('nav-3')));
        await tester.pumpAndSettle();
        expect(s.currentId, 'anna');
        expect(s.runnerMode, isFalse);
        expect(s.wallet.available, annaBalance);
        expect(find.byType(WalletPage), findsOneWidget);
        expect(e.runnerId, 'ben');
        await demoLogin(tester, s, 'ben');
        await tester.tap(find.byKey(const ValueKey('nav-3')));
        await tester.pumpAndSettle();
        expect(s.currentId, 'ben');
        expect(s.runnerMode, isTrue);
        expect(s.wallet.available, benBalance);
        expect(s.pending, 40);
        expect(find.byType(WalletPage), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('phone header clears system insets and its controls respond', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 873);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 48, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(ErrandlyApp(store: ErrandStore()..demo()));
    await tester.pumpAndSettle();
    final notifications = find.byTooltip('Notifications');
    final avatar = find.text('BS').first;
    for (final control in [notifications, avatar]) {
      expect(tester.getTopLeft(control).dy, greaterThanOrEqualTo(48));
    }

    await tester.tap(notifications);
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.byTooltip('Close notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BS').first);
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byTooltip('Menu'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('community and registration screens fit a phone', (tester) async {
    tester.view.physicalSize = const Size(375, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = ErrandStore()..demo();
    final screens = <Widget>[
      FriendsPage(store: s, onHire: () {}),
      NotificationsPage(store: s),
      SafetyPage(store: s),
      AuthForm(store: s, signup: true),
      Verification(store: s),
    ];
    for (final screen in screens) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: screen)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: screen.runtimeType.toString(),
      );
    }
  });
  testWidgets('welcome can open the interactive campus demo', (tester) async {
    final store = ErrandStore();
    await tester.pumpWidget(ErrandlyApp(store: store));
    await demoLogin(tester, store, 'ben');
    expect(find.text('Hey, Ben 👋'), findsOneWidget);
    expect(find.text('Buy 1 Yellow Pad'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [375.0, 768.0, 1440.0]) {
    testWidgets('screens adapt to $width pixels without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = ErrandStore()..demo();
      await tester.pumpWidget(ErrandlyApp(store: s));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label
          in width >= 980
              ? ['My Errands', 'Wallet', 'Messages', 'Find errands']
              : [
                  'My Errands',
                  'Wallet',
                  'Profile',
                  'Messages',
                  'Find Errands',
                ]) {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      s.setMode(false);
      await tester.pumpAndSettle();
      for (final label
          in width >= 980
              ? ['My Errands', 'Wallet', 'Post an errand', 'Home']
              : ['My Errands', 'Post an Errand', 'Wallet', 'Home']) {
        await tester.tap(find.text(label).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('task details and chat lay out on a narrow viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = ErrandStore()..demo();
    final e = s.errands.first;
    s.accept(e);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskDetails(store: s, errand: e),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatPanel(store: s, errand: e),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
