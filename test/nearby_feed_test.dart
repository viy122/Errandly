import 'dart:async';

import 'package:errandly/data/map_services.dart';
import 'package:errandly/models/entities.dart';
import 'package:errandly/models/geo.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/state/personal_preferences.dart';
import 'package:errandly/ui/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const center = GeoPoint(14.5995, 120.9842);

class NearbyStorage implements PreferenceStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String data) async => value = data;
}

class NearbyMaps extends MapServices {
  int gpsCalls = 0;
  bool denied = false;
  Completer<GeoPoint>? pending;
  @override
  Future<GeoPoint> currentPosition() async {
    gpsCalls++;
    if (denied) {
      throw StateError('Location denied. All locations remains available.');
    }
    return pending == null ? center : pending!.future;
  }

  @override
  Future<List<MapPlace>> search(String text) async => [
    const MapPlace('Chosen public location', center),
  ];
}

Errand listing(
  String title,
  GeoPoint? pin, {
  String owner = 'anna',
  String area = 'Manila',
}) => Errand(
  id: title,
  ownerId: owner,
  title: title,
  category: 'Delivery',
  description: 'Development listing',
  pickup: 'Public pickup',
  destination: 'Public delivery',
  budget: 0,
  fee: 40,
  // A long delivery trip must still count as nearby when its pickup is near.
  distance: title == 'Near pickup' ? 500000 : 1000,
  area: area,
  pickupPoint: pin,
  deadline: DateTime.now().add(const Duration(days: 1)),
);

ErrandStore makeStore(NearbyMaps maps) {
  final s = ErrandStore(
    mapServices: maps,
    preferences: PersonalPreferences(storage: NearbyStorage()),
  )..demo('ben');
  s.errands
    ..clear()
    ..addAll([
      listing(
        'Distant pickup',
        const GeoPoint(15.0, 120.9842),
        area: 'Other city',
      ),
      listing('Unpinned request', null),
      listing('Medium pickup', const GeoPoint(14.71, 120.9842)),
      listing('Near pickup', const GeoPoint(14.60, 120.9842)),
    ]);
  return s;
}

Future<void> mount(WidgetTester tester, ErrandStore s) async {
  tester.view.physicalSize = const Size(375, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(s.dispose);
  await tester.pumpWidget(ErrandlyApp(store: s));
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  test('radius filters pickup distance and preserves availability rules', () {
    final s = makeStore(NearbyMaps());
    addTearDown(s.dispose);
    expect(() => s.setBrowseNearby(true), throwsStateError);
    final own = listing('Own pickup', center, owner: 'ben');
    final accepted = listing('Accepted pickup', center)
      ..status = ErrandStatus.accepted;
    final cancelled = listing('Cancelled pickup', center)
      ..status = ErrandStatus.cancelled;
    final expired = listing('Expired pickup', center)
      ..status = ErrandStatus.expired;
    final blocked = listing('Blocked pickup', center, owner: 'maria');
    s.errands.addAll([own, accepted, cancelled, expired, blocked]);
    s.blocked['ben'] = {'maria'};
    s.setBrowsingPosition(center);
    s.setBrowseNearby(true);
    expect(s.runnerOpportunities.map((e) => e.title), ['Near pickup']);
    s.setNearbyRadius(25);
    expect(s.runnerOpportunities.map((e) => e.title), [
      'Medium pickup',
      'Near pickup',
    ]);
    s.setNearbyRadius(5);
    expect(s.runnerOpportunities.map((e) => e.title), ['Near pickup']);
    expect(() => s.setNearbyRadius(0), throwsStateError);
    s.setBrowseNearby(false);
    expect(s.runnerOpportunities.map((e) => e.title), [
      'Distant pickup',
      'Unpinned request',
      'Medium pickup',
      'Near pickup',
    ]);
    s.setBrowseNearby(true);
    s.setBrowseArea('Other city');
    expect(s.browseNearby, isFalse);
    expect(s.runnerOpportunities.single.title, 'Distant pickup');
    s.setBrowseNearby(true);
    s.demo('anna');
    expect(s.browsingPosition, isNull);
    expect(s.browseNearby, isFalse);
    expect(s.browseArea, 'All locations');
  });

  testWidgets(
    'GPS nearby radius and all locations show near, far and unpinned posts correctly',
    (tester) async {
      final maps = NearbyMaps();
      final store = makeStore(maps);
      await mount(tester, store);
      expect(maps.gpsCalls, 0);
      expect(find.text('Distant pickup'), findsOneWidget);
      await press(tester, find.byKey(const ValueKey('feed-scope-nearby')));
      await press(tester, find.text('Use my location'));
      expect(maps.gpsCalls, 1);
      expect(store.browseNearby, isTrue);
      expect(find.text('Near pickup'), findsOneWidget);
      expect(find.text('Distant pickup'), findsNothing);
      expect(find.text('Unpinned request'), findsNothing);
      expect(find.text('Sort: Nearest to me'), findsOneWidget);
      await press(tester, find.byKey(const ValueKey('nearby-radius')));
      await press(tester, find.text('25 km').last);
      expect(find.text('Medium pickup'), findsOneWidget);
      await press(tester, find.byKey(const ValueKey('feed-scope-all')));
      expect(find.text('Distant pickup'), findsOneWidget);
      expect(find.text('Unpinned request'), findsOneWidget);
      // Nearby jobs still use the same acceptance checks and leave discovery after a claim.
      await store.accept(
        store.errands.firstWhere((e) => e.title == 'Near pickup'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Near pickup'), findsNothing);
      expect(store.activeJobs.single.title, 'Near pickup');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('denied GPS keeps all posts available and nearby unselected', (
    tester,
  ) async {
    final maps = NearbyMaps()..denied = true;
    final s = makeStore(maps);
    await mount(tester, s);
    await press(tester, find.byKey(const ValueKey('feed-scope-nearby')));
    await press(tester, find.text('Use my location'));
    expect(s.browseNearby, isFalse);
    expect(find.text('Distant pickup'), findsOneWidget);
    expect(find.text('Unpinned request'), findsOneWidget);
    expect(find.textContaining('Location denied.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('map location supports nearby filtering without a GPS request', (
    tester,
  ) async {
    final maps = NearbyMaps();
    final s = makeStore(maps);
    await mount(tester, s);
    await press(tester, find.byKey(const ValueKey('feed-scope-nearby')));
    await press(tester, find.text('Choose location on map'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Search place or address'),
      'Public location',
    );
    await press(tester, find.byTooltip('Search map locations'));
    await press(tester, find.text('Chosen public location'));
    await press(tester, find.text('Use this pin'));
    expect(maps.gpsCalls, 0);
    expect(s.browsingPositionLabel, 'Chosen public location');
    expect(s.browseNearby, isTrue);
    expect(find.text('Near pickup'), findsOneWidget);
    expect(find.text('Distant pickup'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('late GPS result cannot apply to a different account', (
    tester,
  ) async {
    final maps = NearbyMaps()..pending = Completer<GeoPoint>();
    final s = makeStore(maps);
    await mount(tester, s);
    await press(tester, find.byKey(const ValueKey('feed-scope-nearby')));
    await tester.tap(find.text('Use my location'));
    await tester.pump();
    s.demo('anna');
    await tester.pump();
    maps.pending!.complete(center);
    await tester.pumpAndSettle();
    expect(s.currentId, 'anna');
    expect(s.browsingPosition, isNull);
    expect(s.browseNearby, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
