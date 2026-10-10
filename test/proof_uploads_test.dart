import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:errandly/data/errand_api.dart';
import 'package:errandly/data/proof_picker.dart';
import 'package:errandly/models/proof_image.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/ui/proof_uploads.dart';

import 'api_store_test.dart' show stateFor, response;

final png = File('assets/brand/errandly-symbol.png').readAsBytesSync();
SelectedProof image(String name) => SelectedProof(name: name, bytes: png);

void main() {
  testWidgets(
    'proof decoder accepts actual images and rejects broken payloads',
    (tester) async {
      await tester.runAsync(() async {
        await validateProofImage(
          SelectedProof(
            name: 'receipt.png',
            bytes: File('test/fixtures/proof-receipt.png').readAsBytesSync(),
          ),
        );
        await expectLater(
          validateProofImage(
            SelectedProof(name: 'broken.png', bytes: png.sublist(0, 16)),
          ),
          throwsA(isA<Exception>()),
        );
      });
    },
  );
  test('selected proof rejects oversized, empty and disguised files', () {
    expect(
      () => SelectedProof(
        name: 'large.png',
        bytes: Uint8List(SelectedProof.maxBytes + 1),
      ),
      throwsStateError,
    );
    expect(
      () => SelectedProof(
        name: 'receipt.jpg',
        bytes: Uint8List.fromList(utf8.encode('<script>bad</script>')),
      ),
      throwsStateError,
    );
    expect(
      () => SelectedProof(name: 'empty.png', bytes: Uint8List(0)),
      throwsStateError,
    );
    expect(image('receipt.png').mime, 'image/png');
  });

  test(
    'upload uses authenticated multipart and restores saved proof metadata',
    () async {
      final state = stateFor('ben');
      final task = state['errands'][0] as Map<String, dynamic>;
      task.addAll({
        'progress': 2,
        'actualCost': null,
        'receipt': false,
        'itemPhoto': false,
        'proofFiles': [],
      });
      final api = ErrandApi(
        url: 'http://localhost/api',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer ${'a' * 64}');
          if (request.method == 'GET') {
            return http.Response.bytes(
              png,
              200,
              headers: {'content-type': 'image/png'},
            );
          }
          if ((request.headers['content-type'] ?? '').startsWith(
            'multipart/form-data',
          )) {
            final body = latin1.decode(request.bodyBytes);
            expect(body, contains('name="receipt"; filename="receipt.png"'));
            expect(body, contains('name="item"; filename="items.png"'));
            expect(body, contains('name="errandId"'));
            expect(body, contains('db1'));
            task.addAll({
              'actualCost': 45,
              'receipt': true,
              'itemPhoto': true,
              'proofFiles': [
                for (final kind in ['receipt', 'item'])
                  {
                    'id': kind,
                    'kind': kind,
                    'name': '$kind.png',
                    'mime': 'image/png',
                    'size': png.length,
                    'date': '2026-10-10T12:00:00Z',
                  },
              ],
            });
          }
          return response({'state': state});
        }),
      )..token = 'a' * 64;
      final s = ErrandStore.mysql(api);
      await s.initialize();
      final e = s.errands.single;
      await s.uploadProof(
        e,
        45,
        receipt: true,
        photo: true,
        receiptFile: image('receipt.png'),
        itemFile: image('items.png'),
      );
      expect(e.proofFiles.length, 2);
      expect(e.actualCost, 45);
      expect(await api.proofBytes('receipt'), png);
      expect(s.busy, isFalse);
      s.dispose();
    },
  );

  testWidgets(
    'phone upload previews, cancellation and requester gallery work',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = ErrandStore()..demo();
      final e = s.errands.first;
      s.accept(e);
      s.advance(e);
      s.advance(e);
      var picks = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: s,
                builder: (_, _) => ProofUploadPanel(
                  store: s,
                  errand: e,
                  picker: () async => ++picks == 2
                      ? null
                      : image(picks == 1 ? 'receipt.png' : 'items.png'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save purchase proof'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('choose-receipt')));
      await tester.pumpAndSettle();
      expect(find.text('receipt.png'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('choose-item')));
      await tester.tap(find.byKey(const ValueKey('choose-item')));
      await tester.pumpAndSettle();
      expect(find.text('receipt.png'), findsOneWidget);
      expect(e.proofFiles, isEmpty);
      await tester.tap(find.byKey(const ValueKey('choose-item')));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save purchase proof');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter the actual cost'), findsOneWidget);
      expect(e.proofFiles, isEmpty);
      final cost = find.byType(TextFormField);
      await tester.ensureVisible(cost);
      await tester.enterText(cost, '45');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(e.proofFiles.length, 2);
      expect(e.proof('receipt')!.bytes, png);
      s.demo('anna');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProofGallery(store: s, errand: e),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open receipt'));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      await tester.tap(find.byTooltip('Close proof image'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed upload retains previews and retry saves once', (
    tester,
  ) async {
    final state = stateFor('ben');
    final task = state['errands'][0] as Map<String, dynamic>;
    task.addAll({
      'progress': 2,
      'actualCost': null,
      'receipt': false,
      'itemPhoto': false,
      'proofFiles': [],
    });
    var tries = 0;
    final api = ErrandApi(
      url: 'http://localhost/api',
      client: MockClient((request) async {
        if ((request.headers['content-type'] ?? '').startsWith('multipart/')) {
          tries++;
          if (tries == 1) {
            return response({
              'error': 'Connection interrupted. Try again.',
            }, 503);
          }
          task.addAll({
            'actualCost': 45,
            'receipt': true,
            'itemPhoto': true,
            'proofFiles': [
              for (final kind in ['receipt', 'item'])
                {
                  'id': kind,
                  'kind': kind,
                  'name': '$kind.png',
                  'mime': 'image/png',
                  'size': png.length,
                  'date': '2026-10-10T12:00:00Z',
                },
            ],
          });
        }
        return response({'state': state});
      }),
    );
    final s = ErrandStore.mysql(api);
    await s.initialize();
    var picks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: s,
              builder: (_, _) => ProofUploadPanel(
                store: s,
                errand: s.errands.single,
                picker: () async =>
                    image(++picks == 1 ? 'receipt.png' : 'items.png'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('choose-receipt')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('choose-item')));
    await tester.tap(find.byKey(const ValueKey('choose-item')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.enterText(find.byType(TextFormField), '45');
    final save = find.widgetWithText(FilledButton, 'Save purchase proof');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('receipt.png'), findsOneWidget);
    expect(find.text('items.png'), findsOneWidget);
    expect(s.errands.single.proofFiles, isEmpty);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(tries, 2);
    expect(s.errands.single.proofFiles.length, 2);
    expect(tester.takeException(), isNull);
  });

  test('delivery photo follows runner assignment and handoff state', () async {
    final s = ErrandStore()..demo();
    final e = s.errands.first;
    s.accept(e);
    expect(
      () => s.uploadDeliveryProof(e, image('delivery.png')),
      throwsStateError,
    );
    s.advance(e);
    s.advance(e);
    s.uploadProof(
      e,
      45,
      receipt: true,
      photo: true,
      receiptFile: image('receipt.png'),
      itemFile: image('items.png'),
    );
    s.advance(e);
    s.advance(e);
    s.advance(e);
    s.demo('anna');
    expect(
      () => s.uploadDeliveryProof(e, image('delivery.png')),
      throwsStateError,
    );
    s.demo('ben');
    await s.uploadDeliveryProof(e, image('delivery.png'));
    expect(e.proof('delivery')!.bytes, png);
    s.verifyPin(e, e.pin!);
    expect(
      () => s.uploadDeliveryProof(e, image('other.png')),
      throwsStateError,
    );
  });
}
