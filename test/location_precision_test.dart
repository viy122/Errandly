import 'package:errandly/data/map_services.dart';
import 'package:errandly/models/geo.dart';
import 'package:errandly/ui/errand_map.dart';
import 'package:errandly/ui/location_status.dart';
import 'package:errandly/ui/map_point_picker.dart';
import 'package:errandly/ui/location_picker.dart';
import 'package:errandly/state/errand_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class PrecisionDevice extends GeolocatorPlatform {
  DateTime? timestamp;
  double accuracy = 8;
  bool mocked = false;
  LocationSettings? requested;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    requested = locationSettings;
    return Position(
      latitude: 14.5995,
      longitude: 120.9842,
      timestamp: timestamp ?? DateTime.now(),
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
      isMocked: mocked,
    );
  }
}

void main() {
  testWidgets(
    'header location picker uses a device fix instead of an entered city',
    (tester) async {
      final fix = DeviceLocation(
        14.5995,
        120.9842,
        recordedAt: DateTime.now(),
        accuracyMeters: 8,
      );
      final store = ErrandStore(
        mapServices: MapServices(positionReader: () async => fix),
      )..demo('ben');
      addTearDown(store.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocationPicker(store: store)),
        ),
      );
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();
      expect(identical(store.browsingPosition, fix), isTrue);
      expect(store.browseNearby, isTrue);
      expect(store.browseArea, 'All locations');
      expect(find.text('Choose listing area'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test('device fix retains accuracy and timestamp while saved pins contain coordinates only', () async {
    final old = GeolocatorPlatform.instance;
    final device = PrecisionDevice()..mocked = true;
    GeolocatorPlatform.instance = device;
    addTearDown(() => GeolocatorPlatform.instance = old);
    final fix = await MapServices().currentPosition() as DeviceLocation;
    expect(device.requested!.accuracy, LocationAccuracy.bestForNavigation);
    expect(device.requested!.timeLimit, const Duration(seconds: 15));
    expect(fix.accuracyMeters, 8);
    expect(fix.isMocked, isTrue);
    expect(fix.approximate, isFalse);
    expect(fix.toJson(), {'lat': 14.5995, 'lon': 120.9842});
    device.timestamp = DateTime.now().subtract(const Duration(minutes: 10));
    await expectLater(
      MapServices().currentPosition(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'reason',
          contains('old location'),
        ),
      ),
    );
    device.timestamp = null;
    device.accuracy = 1500;
    final coarse = await MapServices().currentPosition() as DeviceLocation;
    expect(coarse.approximate, isTrue);
    device.accuracy = double.nan;
    expect(
      (await MapServices().currentPosition() as DeviceLocation).accuracyMeters,
      isNull,
    );
  });

  testWidgets(
    'GPS pin zooms in, shows accuracy and recenters even at the same coordinates',
    (tester) async {
      final old = GeolocatorPlatform.instance;
      final device = PrecisionDevice();
      GeolocatorPlatform.instance = device;
      addTearDown(() => GeolocatorPlatform.instance = old);
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final maps = MapServices();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapPointPicker(
              services: maps,
              title: 'Your location',
              forBrowsing: true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();
      final first = tester.widget<ErrandMap>(find.byType(ErrandMap));
      expect(first.deviceLocation, isA<DeviceLocation>());
      final options = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .options;
      expect(options.initialCenter.latitude, 14.5995);
      expect(options.initialCenter.longitude, 120.9842);
      expect(options.initialZoom, 17);
      expect(find.text('14.599500, 120.984200'), findsOneWidget);
      expect(find.text('Accuracy: ±8 m'), findsOneWidget);
      final circles = tester
          .widgetList<CircleLayer>(find.byType(CircleLayer))
          .expand((layer) => layer.circles);
      expect(circles.any((c) => c.useRadiusInMeter && c.radius == 8), isTrue);
      expect(circles.any((c) => c.color == const Color(0xFF2565D6)), isTrue);
      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ErrandMap>(find.byType(ErrandMap)).key,
        isNot(first.key),
      );
      device.accuracy = 800;
      await tester.tap(find.text('Use my location'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Approximate location.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('manual map pins do not claim GPS accuracy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LocationStatus(point: GeoPoint(14.5, 121))),
    );
    expect(find.text('14.500000, 121.000000'), findsOneWidget);
    expect(find.textContaining('Accuracy:'), findsNothing);
  });
}
