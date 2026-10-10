import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:errandly/data/errand_api.dart';
import 'package:errandly/data/map_services.dart';
import 'package:errandly/models/entities.dart';
import 'package:errandly/models/geo.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/ui/feed_sort.dart';
import 'package:errandly/ui/location_picker.dart';
import 'package:errandly/ui/marketplace.dart';
import 'package:errandly/ui/map_point_picker.dart';
import 'package:errandly/ui/payment_choices.dart';

Errand task(String id, GeoPoint? pin, double trip) => Errand(
  id: id,
  ownerId: 'anna',
  title: id,
  category: 'Delivery',
  description: 'Test',
  pickup: 'Test',
  destination: 'Test',
  budget: 0,
  fee: 40,
  distance: trip,
  deadline: DateTime.now().add(const Duration(days: 1)),
  pickupPoint: pin,
);
void main() {
  test('nearest compares pickup distance and puts unknown pins last', () {
    const origin = GeoPoint(0, 0);
    expect(origin.metersTo(const GeoPoint(0, 1)), closeTo(111195, 2));
    expect(
      const GeoPoint(0, 179.9).metersTo(const GeoPoint(0, -179.9)),
      closeTo(22239, 3),
    );
    expect(() => GeoPoint.parse({'lat': 91, 'lon': 0}), throwsFormatException);
    final list = [
      task('unknown', null, 1),
      task('far', const GeoPoint(0, 1), 10),
      task('near', const GeoPoint(0, .01), 99999),
    ];
    list.sort((a, b) => comparePickupDistance(a, b, origin));
    expect(list.map((e) => e.id), ['near', 'far', 'unknown']);
  });
  test('map calls use authenticated API and correct coordinates', () async {
    final calls = <String>[];
    final api = ErrandApi(
      url: 'http://localhost/api',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        final body = jsonDecode(request.body) as Map;
        calls.add(body['action'] as String);
        if (body['action'] == 'placeSearch') {
          return http.Response(
            jsonEncode({
              'places': [
                {
                  'label': 'Test place',
                  'point': {'lat': 14.5, 'lon': 120.9},
                },
              ],
            }),
            200,
          );
        }
        expect(body['from'], {'lat': 14.5, 'lon': 120.9});
        return http.Response(
          jsonEncode({
            'meters': 2345.6,
            'seconds': 500,
            'points': [
              {'lat': 14.5, 'lon': 120.9},
              {'lat': 14.6, 'lon': 121.0},
            ],
          }),
          200,
        );
      }),
    )..token = 'test-token';
    final maps = MapServices(
      api: api,
      positionReader: () async => const GeoPoint(14.5, 120.9),
    );
    final places = await maps.search('Test place');
    final route = await maps.route(
      places.first.point,
      const GeoPoint(14.6, 121),
    );
    expect(route.meters, 2345.6);
    expect(calls, ['placeSearch', 'roadRoute']);
    expect((await maps.currentPosition()).latitude, 14.5);
    api.close();
  });
  testWidgets('phone sort is one control with clear nearest/trip choices', (
    tester,
  ) async {
    String value = 'Newest';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FeedSortControl(
              value: value,
              small: true,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Sort: Newest'));
    await tester.pumpAndSettle();
    expect(find.text('Sort errands'), findsOneWidget);
    await tester.tap(find.text('Shortest trip'));
    await tester.pumpAndSettle();
    expect(find.text('Sort: Shortest trip'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });
  testWidgets(
    'listing area searches case-insensitively and retains selection',
    (tester) async {
      final s = ErrandStore()..demo();
      addTearDown(s.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocationPicker(store: s)),
        ),
      );
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'NASUGBU');
      await tester.pumpAndSettle();
      expect(find.text('Nasugbu, Batangas'), findsOneWidget);
      await tester.tap(find.text('Nasugbu, Batangas'));
      await tester.pumpAndSettle();
      expect(s.browseArea, 'Nasugbu, Batangas');
    },
  );
  testWidgets('payment cards select exactly one method and show pesos', (
    tester,
  ) async {
    String value = 'GCash Simulation';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PurchasePaymentChoices(
              value: value,
              amount: 150,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );
    expect(find.text('₱150'), findsNWidgets(2));
    await tester.tap(find.text('Debit / Card Simulation'));
    await tester.pumpAndSettle();
    expect(value, 'Debit / Card Simulation');
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });
  testWidgets('denied GPS keeps newest sort and shows usable error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = ErrandStore(
      mapServices: MapServices(
        positionReader: () async =>
            throw StateError('Location denied. Choose a map pin.'),
      ),
    )..demo();
    addTearDown(s.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Marketplace(
              store: s,
              onPost: () {},
              onWallet: () {},
              onJobs: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sort: Newest'));
    await tester.tap(find.text('Sort: Newest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nearest to me'));
    await tester.pumpAndSettle();
    expect(find.text('Sort: Newest'), findsOneWidget);
    expect(find.text('Location denied. Choose a map pin.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('map search is explicit and a chosen result returns its pin', (
    tester,
  ) async {
    var queries = 0;
    final api = ErrandApi(
      url: 'http://localhost/api',
      client: MockClient((request) async {
        queries++;
        return http.Response(
          jsonEncode({
            'places': [
              {
                'label': 'Manila public landmark',
                'point': {'lat': 14.5995, 'lon': 120.9842},
              },
            ],
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    MapPlace? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showDialog<MapPlace>(
                  context: context,
                  builder: (_) => Dialog(
                    child: MapPointPicker(
                      services: MapServices(api: api),
                      title: 'Choose pickup pin',
                    ),
                  ),
                );
              },
              child: const Text('Open map'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Manila');
    await tester.pumpAndSettle();
    expect(queries, 0);
    await tester.tap(find.byTooltip('Search map locations'));
    await tester.pumpAndSettle();
    expect(queries, 1);
    await tester.tap(find.text('Manila public landmark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this pin'));
    await tester.pumpAndSettle();
    expect(selected!.point.latitude, 14.5995);
    expect(tester.takeException(), isNull);
  });
}
