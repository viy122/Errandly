import 'package:flutter/material.dart';

import '../data/map_services.dart';
import '../models/geo.dart';
import 'components.dart';
import 'errand_map.dart';
import 'location_status.dart';

class MapPointPicker extends StatefulWidget {
  const MapPointPicker({
    super.key,
    required this.services,
    required this.title,
    this.initial,
    this.initialAddress = '',
    this.forBrowsing = false,
  });
  final MapServices services;
  final String title, initialAddress;
  final GeoPoint? initial;
  final bool forBrowsing;
  @override
  State<MapPointPicker> createState() => _MapPointPickerState();
}

class _MapPointPickerState extends State<MapPointPicker> {
  late final search = TextEditingController(text: widget.initialAddress);
  late GeoPoint? point = widget.initial;
  late GeoPoint? devicePosition = widget.initial is DeviceLocation
      ? widget.initial
      : null;
  int recenter = 0;
  late String label = widget.initialAddress.isNotEmpty
      ? widget.initialAddress
      : widget.initial == null
      ? ''
      : 'Selected map location';
  List<MapPlace> results = [];
  bool working = false, searched = false;
  String? error;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> find({bool gps = false}) async {
    if (working) return;
    FocusScope.of(context).unfocus();
    setState(() {
      working = true;
      error = null;
    });
    try {
      if (gps) {
        final p = await widget.services.currentPosition();
        if (mounted) {
          setState(() {
            point = p;
            devicePosition = p;
            recenter++;
            label =
                'Current location (${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)})';
            results = [];
            searched = false;
          });
        }
      } else {
        if (search.text.trim().length < 3) {
          throw StateError('Enter at least 3 characters, then tap Search.');
        }
        final matches = await widget.services.search(search.text);
        if (mounted) {
          setState(() {
            results = matches;
            searched = true;
          });
        }
      }
    } on StateError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 650,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close map picker',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  onSubmitted: (_) => find(),
                  decoration: const InputDecoration(
                    labelText: 'Search place or address',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Search map locations',
                onPressed: working ? null : () => find(),
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: working ? null : () => find(gps: true),
            icon: const Icon(Icons.my_location, size: 16),
            label: const Text('Use my location'),
          ),
          if (working) const LinearProgressIndicator(),
          if (error != null)
            Text(
              error!,
              style: const TextStyle(fontSize: 11, color: Color(0xFFAD5743)),
            ),
          if (results.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 130),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final result in results)
                    ListTile(
                      dense: true,
                      title: Text(
                        result.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      leading: const Icon(Icons.place_outlined),
                      onTap: () => setState(() {
                        point = result.point;
                        label = result.label;
                        results = [];
                        searched = false;
                      }),
                    ),
                ],
              ),
            ),
          if (searched && results.isEmpty)
            const Text(
              'No matching places. Try a nearby landmark or tap the map.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ErrandMap(
                key: ValueKey(recenter),
                points: point == null ? [] : [point!],
                deviceLocation: devicePosition,
                focusZoom:
                    devicePosition != null && identical(point, devicePosition)
                    ? 17
                    : null,
                onPick: (p) => setState(() {
                  point = p;
                  label = search.text.trim().isEmpty
                      ? 'Map pin (${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)})'
                      : search.text.trim();
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (point != null) LocationStatus(point: point!),
          Text(
            point == null
                ? 'Search and choose a result, or tap the map to place a pin.'
                : 'Selected: $label',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 6),
          Text(
            widget.forBrowsing
                ? 'Choose a location to search nearby pickup pins.'
                : 'Search uses OpenStreetMap; map pins are saved with your errand.',
            style: const TextStyle(fontSize: 10, color: muted),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: point == null || working
                ? null
                : () => Navigator.pop(context, MapPlace(label, point!)),
            child: const Text('Use this pin'),
          ),
        ],
      ),
    ),
  );
}
