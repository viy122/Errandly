import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/geo.dart';
import 'components.dart';

class ErrandMap extends StatefulWidget {
  const ErrandMap({
    super.key,
    required this.points,
    this.route = const [],
    this.onPick,
    this.deviceLocation,
    this.focusZoom,
  });
  final List<GeoPoint> points, route;
  final ValueChanged<GeoPoint>? onPick;
  final GeoPoint? deviceLocation;
  final double? focusZoom;
  @override
  State<ErrandMap> createState() => _ErrandMapState();
}

class _ErrandMapState extends State<ErrandMap> {
  bool tileFailure = false;
  List<GeoPoint> get points => widget.points;
  List<GeoPoint> get route => widget.route;
  ValueChanged<GeoPoint>? get onPick => widget.onPick;
  LatLng latLng(GeoPoint p) => LatLng(p.latitude, p.longitude);
  @override
  Widget build(BuildContext context) {
    final focus = [...points, ...route];
    return Stack(
      children: [
        FlutterMap(
          key: ValueKey(
            focus.map((p) => '${p.latitude},${p.longitude}').join('|'),
          ),
          options: MapOptions(
            initialCenter: focus.isEmpty
                ? const LatLng(14.5995, 120.9842)
                : latLng(focus.first),
            initialZoom: widget.focusZoom ?? (focus.isEmpty ? 6 : 14),
            initialCameraFit:
                focus.length > 1 && focus.first.metersTo(focus.last) > 1
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(focus.map(latLng).toList()),
                    padding: const EdgeInsets.all(38),
                  )
                : null,
            onTap: onPick == null
                ? null
                : (_, p) => onPick!(GeoPoint(p.latitude, p.longitude)),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.errandly',
              errorTileCallback: (_, _, _) {
                if (mounted && !tileFailure) setState(() => tileFailure = true);
              },
            ),
            if (route.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: route.map(latLng).toList(),
                    color: teal,
                    strokeWidth: 4,
                  ),
                ],
              ),
            if (widget.deviceLocation case final DeviceLocation fix)
              if (fix.accuracyMeters != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: latLng(fix),
                      radius: fix.accuracyMeters!,
                      useRadiusInMeter: true,
                      color: const Color(0x222565D6),
                      borderColor: const Color(0x882565D6),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
            CircleLayer(
              circles: [
                for (var i = 0; i < points.length; i++)
                  CircleMarker(
                    point: latLng(points[i]),
                    radius: 9,
                    borderStrokeWidth: 3,
                    borderColor: Colors.white,
                    color: i == 0 ? teal : const Color(0xFFB25236),
                  ),
                if (widget.deviceLocation != null)
                  CircleMarker(
                    point: latLng(widget.deviceLocation!),
                    radius: 7,
                    borderStrokeWidth: 3,
                    borderColor: Colors.white,
                    color: const Color(0xFF2565D6),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          left: 6,
          bottom: 5,
          child: Material(
            color: Colors.white.withValues(alpha: .94),
            child: InkWell(
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 10, color: ink),
                ),
              ),
            ),
          ),
        ),
        if (tileFailure)
          const Positioned(
            top: 6,
            left: 6,
            right: 6,
            child: Material(
              color: Colors.white,
              child: Padding(
                padding: EdgeInsets.all(6),
                child: Text(
                  'Map tiles could not load. Search results and selected pins still work.',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
