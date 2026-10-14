import 'package:flutter/material.dart';

import '../models/geo.dart';
import 'components.dart';

class LocationStatus extends StatelessWidget {
  const LocationStatus({super.key, required this.point});
  final GeoPoint point;
  @override
  Widget build(BuildContext context) {
    final fix = point is DeviceLocation ? point as DeviceLocation : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
          style: const TextStyle(fontSize: 11, color: muted),
        ),
        if (fix != null) ...[
          Text(
            '${fix.isMocked ? 'Simulated device location · ' : ''}${fix.accuracyLabel}',
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          Text(
            'Updated ${TimeOfDay.fromDateTime(fix.recordedAt.toLocal()).format(context)}',
            style: const TextStyle(fontSize: 10, color: muted),
          ),
          if (fix.approximate)
            const Text(
              'Approximate location. Enable precise location for Errandly and try again outdoors.',
              style: TextStyle(fontSize: 11, color: Color(0xFFAD5743)),
            ),
        ],
      ],
    );
  }
}
