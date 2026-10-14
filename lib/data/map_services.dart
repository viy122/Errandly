import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/geo.dart';
import 'errand_api.dart';

typedef PositionReader = Future<GeoPoint> Function();

class MapServices {
  MapServices({this.api, PositionReader? positionReader})
    : positionReader = positionReader ?? readDevicePosition;
  final ErrandApi? api;
  final PositionReader positionReader;
  Future<GeoPoint> currentPosition() async {
    try {
      final point = await positionReader();
      if (!point.valid) throw StateError('Device location is unavailable.');
      return point;
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError(
        'Could not read device location. Try again or choose a map pin.',
      );
    }
  }

  Future<List<MapPlace>> search(String text) async {
    if (api == null) {
      throw StateError('Connect to the API to search map locations.');
    }
    final response = await api!.call('placeSearch', {'query': text.trim()});
    try {
      return (response['places'] as List)
          .map((v) => MapPlace.fromJson(Map<String, dynamic>.from(v)))
          .toList();
    } catch (_) {
      throw StateError('Could not read the map results. Try another search.');
    }
  }

  Future<RoadRoute> route(GeoPoint from, GeoPoint to) async {
    if (api == null) {
      throw StateError('Connect to the API to calculate a road route.');
    }
    final result = await api!.call('roadRoute', {
      'from': from.toJson(),
      'to': to.toJson(),
    });
    try {
      return RoadRoute.fromJson(result);
    } catch (_) {
      throw StateError(
        'Could not read that road route. Try different pins or enter a manual distance.',
      );
    }
  }
}

Future<GeoPoint> readDevicePosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw StateError('Turn on device location, or choose a map pin manually.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw StateError(
      'Location access is unavailable. You can still search or choose map pins.',
    );
  }
  try {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: Duration(seconds: 15),
      ),
    );
    final age = DateTime.now().difference(p.timestamp);
    if (age > const Duration(minutes: 2) || age < const Duration(minutes: -1)) {
      throw StateError(
        'Your device returned an old location. Tap Use my location again to get a fresh position.',
      );
    }
    return DeviceLocation(
      p.latitude,
      p.longitude,
      recordedAt: p.timestamp,
      accuracyMeters: p.accuracy.isFinite && p.accuracy > 0 ? p.accuracy : null,
      isMocked: p.isMocked,
    );
  } on TimeoutException {
    throw StateError(
      'Could not get your location in time. Try again or choose a map pin.',
    );
  } on StateError {
    rethrow;
  } catch (_) {
    throw StateError(
      'Could not read device location. Try again or choose a map pin.',
    );
  }
}
