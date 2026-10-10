import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/wallet_rates.dart';
import 'components.dart';

class AcceptConfirmation extends StatelessWidget {
  const AcceptConfirmation({super.key, required this.errand});
  final Errand errand;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Accept this errand?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Close acceptance',
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          errand.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        infoRow('Runner payment', '${money(errand.fee)} CY'),
        infoRow(
          'Cash-out value',
          '₱${money(WalletRates.pesosForCashOut(errand.fee))}',
        ),
        infoRow(
          'Separate purchase budget',
          errand.purchaseAmount(errand.budget),
        ),
        infoRow('Distance', distanceLabel(errand.distance)),
        infoRow('Deadline', deadlineLabel(errand.deadline)),
        const SizedBox(height: 12),
        note(
          errand.pesoPurchase
              ? 'Your full actual purchase cost is reimbursed in pesos. Coin earnings are released after the requester confirms completion.'
              : 'This older errand keeps its original coin budget and refund terms.',
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, accept'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
