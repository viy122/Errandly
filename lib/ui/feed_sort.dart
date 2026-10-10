import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/geo.dart';
import 'components.dart';

const feedSortChoices = [
  'Newest',
  'Nearest to me',
  'Highest Pay',
  'Urgent',
  'Shortest trip',
];
int comparePickupDistance(Errand a, Errand b, GeoPoint? position) {
  if (position == null) return b.postedAt.compareTo(a.postedAt);
  final left = a.pickupPoint == null
      ? double.infinity
      : position.metersTo(a.pickupPoint!);
  final right = b.pickupPoint == null
      ? double.infinity
      : position.metersTo(b.pickupPoint!);
  final compared = left.compareTo(right);
  return compared != 0 ? compared : b.postedAt.compareTo(a.postedAt);
}

class FeedSortControl extends StatelessWidget {
  const FeedSortControl({
    super.key,
    required this.value,
    required this.small,
    required this.onChanged,
    this.busy = false,
  });
  final String value;
  final bool small, busy;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    if (!small) {
      return DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: feedSortChoices
            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
            .toList(),
        onChanged: busy ? null : (v) => onChanged(v!),
      );
    }
    return OutlinedButton.icon(
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.sort, size: 18),
      label: Text(busy ? 'Getting location…' : 'Sort: $value'),
      onPressed: busy
          ? null
          : () async {
              final choice = await sheet<String>(
                context,
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Sort errands',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close sort choices',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      for (final v in feedSortChoices)
                        ListTile(
                          title: Text(v),
                          subtitle: v == 'Nearest to me'
                              ? const Text(
                                  'Straight-line distance from your location to pickup',
                                  style: TextStyle(fontSize: 11),
                                )
                              : v == 'Shortest trip'
                              ? const Text(
                                  'Pickup-to-drop-off distance',
                                  style: TextStyle(fontSize: 11),
                                )
                              : null,
                          trailing: Icon(
                            v == value
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: v == value ? teal : muted,
                          ),
                          onTap: () => Navigator.pop(context, v),
                        ),
                    ],
                  ),
                ),
              );
              if (choice != null) onChanged(choice);
            },
    );
  }
}
