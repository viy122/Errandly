import 'package:flutter/material.dart';

import '../models/entities.dart';
import 'components.dart';

class PurchasePaymentChoices extends StatelessWidget {
  const PurchasePaymentChoices({
    super.key,
    required this.value,
    required this.amount,
    required this.onChanged,
  });
  final String value;
  final double amount;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Purchase budget payment (pesos)',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      for (final option in ['GCash Simulation', 'Debit / Card Simulation']) ...[
        Semantics(
          checked: value == option,
          inMutuallyExclusiveGroup: true,
          child: Material(
            color: value == option ? pale : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: value == option ? teal : line,
                width: value == option ? 1.5 : 1,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(option),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      value == option
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: value == option ? teal : muted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const Text(
                            'Development simulation',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₱${money(amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );
}
