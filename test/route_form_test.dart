import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:errandly/data/map_services.dart';
import 'package:errandly/models/geo.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:errandly/state/personal_preferences.dart';
import 'package:errandly/ui/post_form.dart';

class MapDraftStorage implements PreferenceStorage {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String text) async {
    data = text;
  }
}

class FormMaps extends MapServices {
  Future<RoadRoute> Function()? response;
  @override
  Future<RoadRoute> route(GeoPoint from, GeoPoint to) => response!();
}

class DeviceFix extends GeolocatorPlatform {
  LocationPermission permission = LocationPermission.denied;
  bool enabled = true;
  int requests = 0;
  LocationSettings? settings;
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return permission = LocationPermission.whileInUse;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    settings = locationSettings;
    return Position(
      latitude: 14.5995,
      longitude: 120.9842,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

Future<ErrandStore> draftStore(FormMaps maps) async {
  final s = ErrandStore(
    mapServices: maps,
    preferences: PersonalPreferences(storage: MapDraftStorage()),
  )..demo('anna');
  await s.preferences.saveDraft('anna', {
    'fields': [
      'Trip test',
      'Description',
      'Instructions',
      'Manila landmark',
      'Manila destination',
      'Manila',
      '5',
      '0',
      '40',
    ],
    'pickupPoint': const GeoPoint(14.5995, 120.9842).toJson(),
    'destinationPoint': const GeoPoint(14.5831, 120.9794).toJson(),
    'deadlineAt': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
  });
  return s;
}

void main() {
  test(
    'device location requests foreground permission and bounds the GPS wait',
    () async {
      final original = GeolocatorPlatform.instance;
      final platform = DeviceFix();
      GeolocatorPlatform.instance = platform;
      addTearDown(() => GeolocatorPlatform.instance = original);
      expect((await readDevicePosition()).latitude, 14.5995);
      expect(platform.requests, 1);
      expect(platform.settings!.timeLimit, const Duration(seconds: 15));
      platform.permission = LocationPermission.deniedForever;
      await expectLater(readDevicePosition(), throwsStateError);
      expect(platform.requests, 1);
      platform.enabled = false;
      await expectLater(readDevicePosition(), throwsStateError);
    },
  );
  testWidgets(
    'road estimate persists in draft and address edits invalidate pin/route',
    (tester) async {
      final maps = FormMaps()
        ..response = () async => const RoadRoute(
          meters: 3225.7,
          seconds: 307,
          points: [GeoPoint(14.5995, 120.9842), GeoPoint(14.5831, 120.9794)],
        );
      final s = await draftStore(maps);
      addTearDown(s.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PostForm(store: s, onPublished: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Calculate road route'));
      await tester.tap(find.text('Calculate road route'));
      await tester.pumpAndSettle();
      final saved = s.preferences.draftFor('anna')!;
      expect(saved['distanceSource'], 'osrm_driving');
      expect(saved['routeSeconds'], 307);
      expect(saved['fields'][6], '3.225700');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PostForm(store: s, onPublished: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Road estimate: 3.225700 km'), findsOneWidget);
      final address = find.widgetWithText(TextFormField, 'Pickup address');
      await tester.ensureVisible(address);
      await tester.enterText(address, 'Changed pickup');
      await tester.pumpAndSettle();
      final changed = s.preferences.draftFor('anna')!;
      expect(changed['pickupPoint'], isNull);
      expect(changed['distanceSource'], 'manual');
      expect(changed['fields'][6], '');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'address change during calculation discards the late route result',
    (tester) async {
      final completer = Completer<RoadRoute>();
      final maps = FormMaps()..response = () => completer.future;
      final s = await draftStore(maps);
      addTearDown(s.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PostForm(store: s, onPublished: () {})),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Calculate road route'));
      await tester.tap(find.text('Calculate road route'));
      await tester.pump();
      final address = find.widgetWithText(TextFormField, 'Pickup address');
      await tester.ensureVisible(address);
      await tester.enterText(address, 'Another pickup');
      await tester.pump();
      completer.complete(
        const RoadRoute(meters: 9999, seconds: 60, points: []),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Road estimate:'), findsNothing);
      expect(s.preferences.draftFor('anna')!['fields'][6], '5');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
