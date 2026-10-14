import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/wallet_rates.dart';
import '../state/errand_store.dart';
import 'components.dart';
import 'details.dart';

class ErrandCard extends StatelessWidget {
  const ErrandCard({super.key, required this.store, required this.errand});
  final ErrandStore store;
  final Errand errand;

  @override
  Widget build(BuildContext context) {
    final e = errand, owner = store.users[errand.ownerId]!;
    final ageMinutes = DateTime.now().difference(e.postedAt).inMinutes;
    final eligible =
        store.runnerMode && e.available && e.ownerId != store.currentId;
    return Panel(
      padding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Avatar(owner, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            owner.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (owner.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 13, color: teal),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${owner.rating.toStringAsFixed(1)} ★ · ${owner.completed} completed',
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                '${ageMinutes < 0 ? 0 : ageMinutes}m ago',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Tag(e.category.toUpperCase()),
              if (e.urgent) const Tag('URGENT', color: Color(0xFFAD5743)),
              if (!e.available) Tag(e.label, color: muted),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            e.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            e.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: muted, height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: teal),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${e.pickup} → ${e.destination}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: ink, height: 1.4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                distanceLabel(e.distance),
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            e.distanceSource == 'osrm_driving'
                ? 'Trip: car-road estimate'
                : 'Trip: requester estimate',
            style: const TextStyle(fontSize: 10, color: muted),
          ),
          if (store.browsingPosition != null && e.pickupPoint != null)
            Text(
              '${distanceLabel(store.browsingPosition!.metersTo(e.pickupPoint!))} to pickup · straight line',
              style: const TextStyle(fontSize: 10, color: teal),
            ),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: muted),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Due ${deadlineLabel(e.deadline)}',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pale,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.pesoPurchase
                            ? 'Purchase budget'
                            : 'Original coin budget',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e.purchaseAmount(e.budget),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Runner payment',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${money(e.fee)} CY',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: teal,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Cash-out ₱${money(WalletRates.pesosForCashOut(e.fee))}',
                        style: const TextStyle(fontSize: 9, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => openDetails(context, store, e),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size(0, 44),
                  ),
                  child: Text(
                    eligible ? 'View & Accept' : 'View details',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: store.savedIds.contains(e.id)
                    ? 'Unsave'
                    : 'Save errand',
                onPressed: () => store.quietly(() => store.toggleSave(e)),
                icon: Icon(
                  store.savedIds.contains(e.id)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  size: 20,
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                tooltip: 'Message requester',
                onPressed: () => openChat(context, store, e),
                icon: const Icon(Icons.chat_bubble_outline, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
