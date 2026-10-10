import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:errandly/data/errand_api.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/ui/app.dart';
import 'package:errandly/ui/details.dart';

import 'api_store_test.dart' show stateFor, response;

void main() {
  testWidgets(
    'pending chat blocks duplicate sends and failed sends keep the draft',
    (tester) async {
      final pending = Completer<http.Response>();
      final state = stateFor('ben');
      var sends = 0;
      final s = ErrandStore.mysql(
        ErrandApi(
          url: 'http://localhost/api',
          client: MockClient((request) async {
            final data = jsonDecode(request.body) as Map<String, dynamic>;
            if (data['action'] == 'send') {
              sends++;
              if (sends == 1) return pending.future;
              state['messages'] = [
                {
                  'errandId': 'db1',
                  'senderId': 'ben',
                  'recipientId': 'anna',
                  'text': data['text'],
                  'date': '2026-10-10T12:00:00Z',
                },
              ];
            }
            return response({'state': state});
          }),
        ),
      );
      await s.initialize();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPanel(store: s, errand: s.errands.single),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'I have your parcel.');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Send message',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      expect(sends, 1);
      pending.complete(
        response({'error': 'Message could not save. Try again.'}, 503),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'I have your parcel.',
      );
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
      expect(sends, 2);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('I have your parcel.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      s.dispose();
    },
  );

  testWidgets('background app stops polling and refreshes when resumed', (
    tester,
  ) async {
    final state = stateFor('ben');
    var reads = 0;
    final s = ErrandStore.mysql(
      ErrandApi(
        url: 'http://localhost/api',
        client: MockClient((request) async {
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          if (data['action'] == 'state') reads++;
          return response({'state': state});
        }),
      ),
    );
    await s.initialize();
    await tester.pumpWidget(ErrandlyApp(store: s));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(reads, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final before = reads;
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
    expect(reads, before);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(reads, before + 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    s.dispose();
  });
}
