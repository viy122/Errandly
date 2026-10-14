import 'package:errandly/state/errand_store.dart';
import 'package:errandly/state/personal_preferences.dart';
import 'package:errandly/ui/app.dart';
import 'package:errandly/ui/marketplace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'login_helpers.dart';

class VisibilityStorage implements PreferenceStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async => value = data;
}

void main() {
  testWidgets(
    'publishing shows a live owner preview and another runner can find it despite old filters',
    (tester) async {
      tester.view.physicalSize = const Size(375, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = ErrandStore(
        preferences: PersonalPreferences(storage: VisibilityStorage()),
      )..demo('anna');
      s.errands.clear();
      addTearDown(s.dispose);
      await tester.pumpWidget(ErrandlyApp(store: s));
      await tester.pumpAndSettle();

      Future<void> press(Finder button) async {
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      Future<void> enter(String label, String value) async {
        final field = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      await press(find.text('Post an Errand'));
      await enter('Errand title', 'New request for a runner');
      await enter('Description', 'Deliver a sealed envelope.');
      await enter('Pickup address', 'Public pickup place');
      await enter('Delivery address', 'Public delivery place');
      await enter('Listing area / city', 'A new listing area');
      await press(find.text('Continue'));
      await enter('Item / purchase budget (₱)', '0');
      await press(find.text('Continue'));
      await press(find.text('Secure payment & publish'));
      final posted = s.errands.single;
      expect(posted.available, isTrue);
      expect(posted.ownerId, 'anna');

      await demoLogin(tester, s, 'anna', runner: true);
      expect(find.byType(Marketplace), findsOneWidget);
      expect(find.text('Your live posts'), findsOneWidget);
      expect(find.text(posted.title), findsOneWidget);
      expect(s.runnerOpportunities, isEmpty);
      expect(() => s.accept(posted), throwsStateError);
      // Previous feed preferences must not hide this post in the other account.
      s.setBrowseArea('An unrelated area');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Search errands'),
        'no matching text',
      );
      await press(find.byKey(const ValueKey('feed-category')));
      await press(find.text('Printing').last);
      await demoLogin(tester, s, 'ben');
      expect(s.currentId, 'ben');
      expect(s.runnerMode, isTrue);
      expect(s.browseArea, 'All locations');
      expect(s.runnerOpportunities, contains(posted));
      expect(find.text('Your live posts'), findsNothing);
      expect(find.text(posted.title), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'View & Accept'),
        findsOneWidget,
      );
      await s.accept(posted);
      await tester.pumpAndSettle();
      expect(s.activeJobs, contains(posted));
      expect(s.runnerOpportunities, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
