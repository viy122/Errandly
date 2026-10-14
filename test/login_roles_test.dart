import 'package:errandly/state/errand_store.dart';
import 'package:errandly/state/personal_preferences.dart';
import 'package:errandly/ui/app.dart';
import 'package:errandly/ui/auth.dart';
import 'package:errandly/ui/demo_account_toggle.dart';
import 'package:errandly/ui/role_dashboard.dart';
import 'package:errandly/ui/marketplace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'login_helpers.dart';

class LoginStorage implements PreferenceStorage {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async => data = value;
}

void main() {
  for (final width in [340.0, 1440.0]) {
    testWidgets('role and demo accounts appear only at login at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = ErrandStore(
        preferences: PersonalPreferences(storage: LoginStorage()),
      );
      addTearDown(s.dispose);
      await tester.pumpWidget(ErrandlyApp(store: s));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Log in'));
      expect(find.byKey(const ValueKey('login-role')), findsOneWidget);
      await tapVisible(tester, find.text('Use demo accounts'));
      expect(find.byKey(const ValueKey('login-demo-account')), findsOneWidget);
      await tapVisible(tester, find.text('Ben'));
      expect(
        s.currentId,
        isNull,
        reason: 'Choosing an account must not log in before submission',
      );
      await tapVisible(tester, find.text('Enter demo'));
      expect(s.currentId, 'ben');
      expect(s.runnerMode, isTrue);
      expect(find.byType(Marketplace), findsOneWidget);
      expect(find.byType(RoleModeSwitch), findsNothing);
      expect(find.byType(DemoAccountToggle), findsNothing);
      expect(find.byKey(const ValueKey('login-role')), findsNothing);
      await tapVisible(tester, find.byKey(const ValueKey('nav-4')));
      expect(find.widgetWithText(OutlinedButton, 'Anna'), findsNothing);
      await tapVisible(tester, find.text('Log out'));
      expect(s.currentId, isNull);
      await demoLogin(tester, s, 'anna');
      expect(s.runnerMode, isFalse);
      expect(find.byType(RequesterDashboard), findsOneWidget);
      expect(find.byType(RoleModeSwitch), findsNothing);
      expect(find.byType(DemoAccountToggle), findsNothing);
      expect(s.preferences.roleFor('anna'), isFalse);
      expect(s.preferences.roleFor('ben'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'email login respects selected role and failed login keeps user signed out',
    (tester) async {
      final s = ErrandStore(
        preferences: PersonalPreferences(storage: LoginStorage()),
      );
      addTearDown(s.dispose);
      await tester.pumpWidget(ErrandlyApp(store: s));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Log in'));
      await tapVisible(tester, find.text('Runner'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'anna@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'wrong-password',
      );
      await tapVisible(
        tester,
        find.descendant(
          of: find.byType(AuthForm),
          matching: find.widgetWithText(FilledButton, 'Log in'),
        ),
      );
      expect(s.currentId, isNull);
      expect(find.byType(AuthForm), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'demo123',
      );
      await tapVisible(
        tester,
        find.descendant(
          of: find.byType(AuthForm),
          matching: find.widgetWithText(FilledButton, 'Log in'),
        ),
      );
      expect(s.currentId, 'anna');
      expect(s.runnerMode, isTrue);
      expect(find.byType(Marketplace), findsOneWidget);
      expect(find.byType(RoleModeSwitch), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
