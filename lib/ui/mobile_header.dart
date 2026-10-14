import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../state/errand_store.dart';
import 'components.dart';
import 'location_picker.dart';

class MobileHeader extends StatelessWidget {
  const MobileHeader({
    super.key,
    required this.store,
    required this.onProfile,
    required this.onNotifications,
    required this.onWallet,
  });
  final ErrandStore store;
  final VoidCallback onProfile, onNotifications, onWallet;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('mobile-header'),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    decoration: const BoxDecoration(
      color: forest,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Profile',
              onPressed: onProfile,
              padding: EdgeInsets.zero,
              icon: Avatar(store.user, size: 38),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hey, ${store.user.firstName} 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: store.runnerMode
                        ? () => chooseListingArea(context, store)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              store.runnerMode
                                  ? store.browseNearby
                                        ? 'Nearby · ${store.nearbyRadiusKm.toInt()} km'
                                        : store.browseArea
                                  : store.user.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (store.runnerMode)
                            const Icon(
                              Icons.expand_more,
                              size: 14,
                              color: Colors.white70,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Brand(light: true, size: 34),
            IconButton(
              tooltip: 'Notifications',
              onPressed: onNotifications,
              icon: Badge(
                isLabelVisible: store.hasUnreadAlerts,
                child: const Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: lime,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: lime),
          ),
          child: InkWell(
            onTap: onWallet,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wallet balance',
                          style: TextStyle(color: forest, fontSize: 10),
                        ),
                        Text(
                          '${money(store.wallet.available)} CY',
                          style: const TextStyle(
                            color: ink,
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Text(
                      store.runnerMode
                          ? '${store.runnerOpportunities.length} available errands'
                          : '${store.requests.where((e) => !e.terminal).length} active requests',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: forest, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: forest, size: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
