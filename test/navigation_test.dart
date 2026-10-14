import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/ui/account.dart';
import 'package:errandly/ui/app.dart';
import 'package:errandly/ui/details.dart';
import 'package:errandly/ui/marketplace.dart';
import 'package:errandly/ui/notification_settings.dart';
import 'package:errandly/ui/post_form.dart';
import 'package:errandly/ui/role_dashboard.dart';

void main() {
  for (final width in [340.0, 1440.0]) {
    testWidgets('navigation and profile shortcuts work at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = ErrandStore()..demo();
      final job = s.errands.first;
      s.accept(job);
      await tester.pumpWidget(ErrandlyApp(store: s));
      await tester.pumpAndSettle();

      final semantics = tester.ensureSemantics();
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isNull);
      expect(scaffold.bottomNavigationBar == null, width >= 980);
      for (final target in [0, 1, 5, 3, 4]) {
        expect(find.byKey(ValueKey('nav-$target')), findsOneWidget);
        expect(
          tester
              .getSemantics(find.byKey(ValueKey('nav-$target')))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
      }
      semantics.dispose();
      await tester.tap(find.byKey(const ValueKey('nav-5')));
      await tester.pumpAndSettle();
      expect(find.byType(MessagesPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      expect(find.byType(MyErrands), findsOneWidget);
      expect(find.byType(ActiveJobsPage), findsOneWidget);
      expect(find.text(job.title), findsOneWidget);
      expect(
        find.widgetWithText(ChoiceChip, 'Active Jobs (1)'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('nav-4')));
      await tester.pumpAndSettle();
      final settings = find.byKey(const ValueKey('profile-Settings'));
      await tester.ensureVisible(settings);
      await tester.tap(settings);
      await tester.pumpAndSettle();
      expect(find.byType(NotificationSettings), findsOneWidget);
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();

      for (final label in [
        'Saved errands',
        'Friends & favorites',
        'Safety center',
      ]) {
        final link = find.byKey(ValueKey('profile-$label'));
        await tester.ensureVisible(link);
        await tester.pumpAndSettle();
        await tester.tap(link);
        await tester.pumpAndSettle();
        expect(find.byType(ProfilePage), findsNothing);
        if (label == 'Saved errands') {
          expect(find.byType(Marketplace), findsOneWidget);
          // Saved errands remains accessible after switching the view mode.
          s.setMode(false);
          await tester.pumpAndSettle();
          expect(find.text('Your saved errands'), findsOneWidget);
        } else if (label == 'Friends & favorites') {
          expect(find.byType(FriendsPage), findsOneWidget);
        } else {
          expect(find.byType(SafetyPage), findsOneWidget);
        }
        await tester.tap(find.text('Back to Profile'));
        await tester.pumpAndSettle();
        expect(find.byType(ProfilePage), findsOneWidget);
      }

      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Post an Errand'));
      await tester.pumpAndSettle();
      expect(find.byType(PostForm), findsOneWidget);
      await tester.tap(find.text('Back to My Errands'));
      await tester.pumpAndSettle();
      expect(find.byType(MyErrands), findsOneWidget);
      expect(s.currentId, 'ben');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'empty active jobs leads to discovery and system back returns to Profile',
    (tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ErrandlyApp(store: ErrandStore()..demo()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Find an Errand'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find an Errand'));
      await tester.pumpAndSettle();
      expect(find.byType(Marketplace), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-4')));
      await tester.pumpAndSettle();
      final safety = find.byKey(const ValueKey('profile-Safety center'));
      await tester.ensureVisible(safety);
      await tester.pumpAndSettle();
      await tester.tap(safety);
      await tester.pumpAndSettle();
      expect(find.byType(SafetyPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
