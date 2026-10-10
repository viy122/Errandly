import 'dart:math' as math;

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude, longitude;
  bool get valid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
  Map<String, double> toJson() => {'lat': latitude, 'lon': longitude};
  static GeoPoint? parse(dynamic value) {
    if (value == null) return null;
    if (value is! Map || value['lat'] is! num || value['lon'] is! num) {
      throw const FormatException('Invalid map pin.');
    }
    final point = GeoPoint(
      (value['lat'] as num).toDouble(),
      (value['lon'] as num).toDouble(),
    );
    if (!point.valid) throw const FormatException('Invalid map pin.');
    return point;
  }

  double metersTo(GeoPoint other) {
    double radians(double v) => v * math.pi / 180;
    final dLat = radians(other.latitude - latitude);
    final dLon = radians(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(radians(latitude)) *
            math.cos(radians(other.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}

class MapPlace {
  const MapPlace(this.label, this.point);
  final String label;
  final GeoPoint point;
  factory MapPlace.fromJson(Map<String, dynamic> data) =>
      MapPlace(data['label'] as String, GeoPoint.parse(data['point'])!);
}

class RoadRoute {
  const RoadRoute({
    required this.meters,
    required this.seconds,
    required this.points,
  });
  final double meters, seconds;
  final List<GeoPoint> points;
  factory RoadRoute.fromJson(Map<String, dynamic> data) {
    final meters = (data['meters'] as num).toDouble();
    final seconds = (data['seconds'] as num).toDouble();
    if (!meters.isFinite || meters <= 0 || !seconds.isFinite || seconds < 0) {
      throw const FormatException('Invalid route result.');
    }
    return RoadRoute(
      meters: meters,
      seconds: seconds,
      points: (data['points'] as List).map((p) => GeoPoint.parse(p)!).toList(),
    );
  }
}
