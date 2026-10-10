import 'package:flutter/material.dart';

import '../state/errand_store.dart';
import 'components.dart';

Future<void> chooseListingArea(BuildContext context, ErrandStore store) async {
  final selected = await sheet<String>(context, _AreaSearch(store: store));
  if (selected != null) store.setBrowseArea(selected);
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
                store.browseArea,
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
                      trailing: area == widget.store.browseArea
                          ? const Icon(Icons.check, color: teal)
                          : null,
                      onTap: () => Navigator.pop(context, area),
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
