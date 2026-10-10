import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../state/errand_store.dart';
import 'components.dart';
import 'motion.dart';

class CancellationPanel extends StatelessWidget {
  const CancellationPanel({
    super.key,
    required this.store,
    required this.errand,
  });
  final ErrandStore store;
  final Errand errand;

  @override
  Widget build(BuildContext context) {
    final e = errand;
    final requestedByMe = e.cancelRequestedBy == store.currentId;
    final participant =
        store.currentId == e.ownerId || store.currentId == e.runnerId;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Panel(
        color: pale,
        padding: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cancellation pending',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(e.cancellationReason ?? 'Cancellation requested.'),
            const SizedBox(height: 8),
            Text(
              e.needsCancellationReview
                  ? 'Support must review the recorded purchase and work. Progress and payment remain on hold.'
                  : 'Both participants must agree. Approval refunds ${money(e.total)} CY${e.pesoPurchase && e.budget > 0 ? ' and ₱${money(e.budget)}' : ''}. Funds stay secured until resolved.',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            if (participant && requestedByMe)
              TextButton(
                onPressed: store.busy
                    ? null
                    : () => attempt(
                        context,
                        () => store.respondCancellation(e, 'withdraw'),
                        'Cancellation withdrawn. The errand can continue.',
                      ),
                child: const Text('Withdraw cancellation'),
              ),
            if (participant && !requestedByMe) ...[
              if (!e.needsCancellationReview) ...[
                const SizedBox(height: 12),
                AsyncActionButton(
                  label: 'Agree to cancel and refund',
                  enabled: !store.busy,
                  onPressed: () => attempt(
                    context,
                    () => store.respondCancellation(e, 'approve'),
                    'Cancellation resolved. Refund recorded.',
                  ),
                ),
              ],
              TextButton(
                onPressed: store.busy
                    ? null
                    : () => attempt(
                        context,
                        () => store.respondCancellation(e, 'reject'),
                        'Disagreement recorded. Funds stay secured for support review.',
                      ),
                child: const Text('Disagree — request support review'),
              ),
            ],
            if (store.isSupport || (participant && store.isDemoAccount))
              OutlinedButton.icon(
                onPressed: store.busy
                    ? null
                    : () => sheet(
                        context,
                        _CancellationReview(store: store, errand: e),
                      ),
                icon: const Icon(Icons.support_agent, size: 18),
                label: Text(
                  store.isSupport
                      ? 'Review cancellation'
                      : 'Simulate support decision',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CancellationReview extends StatefulWidget {
  const _CancellationReview({required this.store, required this.errand});
  final ErrandStore store;
  final Errand errand;
  @override
  State<_CancellationReview> createState() => _CancellationReviewState();
}

class _CancellationReviewState extends State<_CancellationReview> {
  double compensation = 0;
  @override
  Widget build(BuildContext context) {
    final e = widget.errand;
    final cost = e.actualCost ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitle(
            widget.store.isSupport
                ? 'Review cancellation'
                : 'Support review simulation',
            'Review the saved purchase proof and agree on compensation before resolving.',
          ),
          infoRow('Recorded purchase cost', e.purchaseAmount(cost)),
          infoRow(
            'Receipt / item photo',
            '${e.receipt ? 'Attached' : 'Missing'} / ${e.itemPhoto ? 'Attached' : 'Missing'}',
          ),
          select(
            'Runner compensation (CY)',
            compensation == 0
                ? 'No runner compensation'
                : 'Full runner payment (${money(e.fee)} CY)',
            [
              'No runner compensation',
              'Full runner payment (${money(e.fee)} CY)',
            ],
            (v) => setState(
              () => compensation = v == 'No runner compensation' ? 0 : e.fee,
            ),
          ),
          infoRow(
            'Requester coin refund',
            '${money(e.total - (e.pesoPurchase ? 0 : cost) - compensation)} CY',
          ),
          if (e.pesoPurchase)
            infoRow('Requester peso refund', '₱${money(e.budget - cost)}'),
          note(
            'Approval reimburses the recorded purchase cost, pays the selected compensation, and refunds the remaining secured funds once. Peso transfers remain simulated.',
          ),
          const SizedBox(height: 16),
          AsyncActionButton(
            label: 'Approve cancellation and settle',
            enabled: !widget.store.busy,
            onPressed: () async {
              if (await attempt(
                    context,
                    () => widget.store.respondCancellation(
                      e,
                      'approve',
                      support: true,
                      runnerPayment: compensation,
                    ),
                    'Cancellation and funds resolved.',
                  ) &&
                  context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          TextButton(
            onPressed: widget.store.busy
                ? null
                : () async {
                    if (await attempt(
                          context,
                          () => widget.store.respondCancellation(
                            e,
                            'reject',
                            support: true,
                          ),
                          'Cancellation rejected. The errand can continue.',
                        ) &&
                        context.mounted) {
                      Navigator.pop(context);
                    }
                  },
            child: const Text('Reject cancellation and resume errand'),
          ),
        ],
      ),
    );
  }
}
