import 'package:errandly/state/errand_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> demoLogin(
  WidgetTester tester,
  ErrandStore store,
  String id, {
  bool? runner,
}) async {
  if (store.currentId != null) {
    await store.logout();
    await tester.pumpAndSettle();
  }
  await tapVisible(tester, find.text('Continue as Demo User'));
  await tapVisible(
    tester,
    find.descendant(
      of: find.byKey(const ValueKey('login-demo-account')),
      matching: find.text(id == 'anna' ? 'Anna' : 'Ben'),
    ),
  );
  await tapVisible(
    tester,
    find.descendant(
      of: find.byKey(const ValueKey('login-role')),
      matching: find.text((runner ?? id == 'ben') ? 'Runner' : 'Requester'),
    ),
  );
  await tapVisible(tester, find.text('Enter demo'));
}
