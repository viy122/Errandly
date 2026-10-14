import 'package:flutter/material.dart';

import '../state/errand_store.dart';
import '../models/geo.dart';
import 'components.dart';

Future<void> chooseListingArea(BuildContext context, ErrandStore store) async {
  final account = store.currentId;
  final selected = await sheet<Object>(context, _AreaSearch(store: store));
  if (account != store.currentId) return;
  if (selected is GeoPoint) {
    store.setBrowsingPosition(selected);
    store.setBrowseNearby(true);
  } else if (selected is String) {
    store.setBrowseArea(selected);
  }
}

class LocationPicker extends StatelessWidget {
  const LocationPicker({super.key, required this.store});
  final ErrandStore store;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 320),
    child: TextButton(
      onPressed: () => chooseListingArea(context, store),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.public, size: 18, color: teal),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                store.browseNearby
                    ? 'Nearby · ${store.nearbyRadiusKm.toInt()} km'
                    : store.browseArea,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: muted),
          ],
        ),
      ),
    ),
  );
}

class _AreaSearch extends StatefulWidget {
  const _AreaSearch({required this.store});
  final ErrandStore store;
  @override
  State<_AreaSearch> createState() => _AreaSearchState();
}

class _AreaSearchState extends State<_AreaSearch> {
  String query = '';
  bool locating = false;
  String? locationError;
  Future<void> locate() async {
    if (locating) return;
    setState(() {
      locating = true;
      locationError = null;
    });
    try {
      final point = await widget.store.maps.currentPosition();
      if (mounted) Navigator.pop(context, point);
    } on StateError catch (e) {
      if (mounted) setState(() => locationError = e.message);
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final areas = widget.store.areaOptions
        .where((a) => a.toLowerCase().contains(query.trim().toLowerCase()))
        .toList();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Choose listing area',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              IconButton(
                tooltip: 'Close location selection',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Search city or area',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: locating ? null : locate,
            icon: const Icon(Icons.my_location, size: 18),
            label: Text(
              locating ? 'Finding your location…' : 'Use my current location',
            ),
          ),
          if (locating) const LinearProgressIndicator(),
          if (locationError != null)
            Text(
              locationError!,
              style: const TextStyle(fontSize: 11, color: Color(0xFFAD5743)),
            ),
          const Text(
            'Areas come from posted errands. Select All locations to browse everywhere.',
            style: TextStyle(fontSize: 11, color: muted),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (areas.isEmpty)
                    const ListTile(title: Text('No matching listing areas')),
                  for (final area in areas)
                    ListTile(
                      title: Text(area),
                      trailing:
                          !widget.store.browseNearby &&
                              area == widget.store.browseArea
                          ? const Icon(Icons.check, color: teal)
                          : null,
                      onTap: locating
                          ? null
                          : () => Navigator.pop(context, area),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
