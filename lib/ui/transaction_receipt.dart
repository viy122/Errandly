import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/entities.dart';
import '../models/wallet_rates.dart';
import '../state/errand_store.dart';
import 'components.dart';
import 'motion.dart';

class TransactionReceipt extends StatelessWidget {
  const TransactionReceipt({
    super.key,
    required this.store,
    required this.entry,
  });
  final ErrandStore store;
  final WalletEntry entry;
  String get reference => entry.id.startsWith('LOCAL-')
      ? entry.id
      : 'ER-${entry.id.padLeft(8, '0')}';
  @override
  Widget build(BuildContext context) {
    final matches = store.errands.where((e) => e.id == entry.errandId);
    final e = matches.isEmpty ? null : matches.first;
    final amount = entry.currency == 'PHP'
        ? '₱${money(entry.amount.abs())}'
        : '${money(entry.amount.abs())} CY';
    final released = entry.type == 'Runner Earnings';
    final allocation = const {
      'Purchase Budget',
      'Service Fee',
    }.contains(entry.type);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Digital receipt',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Close receipt',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Entrance(
            child: ClipPath(
              clipper: const _ReceiptEdge(),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 35),
                decoration: const BoxDecoration(color: Color(0xFFFFFDF7)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: Brand(size: 56)),
                    const SizedBox(height: 20),
                    Text(
                      entry.type,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      amount,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: teal,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, size: 15, color: teal),
                        const SizedBox(width: 5),
                        Text(
                          released ? 'Payment released' : entry.status,
                          style: const TextStyle(
                            color: teal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    infoRow(
                      'Date',
                      '${entry.date.month}/${entry.date.day}/${entry.date.year}',
                    ),
                    infoRow('Time', timeLabel(entry.date)),
                    infoRow(
                      'Account',
                      store.users[entry.userId]?.name ?? 'Your account',
                    ),
                    infoRow(
                      entry.amount >= 0
                          ? 'Amount recorded as credit'
                          : allocation
                          ? 'Allocated from secured funds'
                          : 'Amount recorded as debit',
                      amount,
                      strong: true,
                    ),
                    if (entry.pesoAmount != null)
                      infoRow(
                        entry.type == 'Top Up' ? 'Peso payment' : 'Peso payout',
                        '₱${money(entry.pesoAmount!)}',
                        strong: true,
                      ),
                    if (entry.currency == 'CY' && entry.type != 'Cash Out')
                      infoRow(
                        'At current cash-out rate',
                        '₱${money(WalletRates.pesosForCashOut(entry.amount.abs()))}',
                      ),
                    if (entry.pesoAmount == null &&
                        const {'Top Up', 'Cash Out'}.contains(entry.type))
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Original peso amount is unavailable for this older transaction. See its recorded details below.',
                          style: TextStyle(
                            fontSize: 11,
                            color: muted,
                            height: 1.5,
                          ),
                        ),
                      ),
                    const Divider(),
                    Text(
                      entry.note,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    if (e != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        e.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (entry.type == 'Errand Payment') ...[
                        infoRow('Runner payment secured', '${money(e.fee)} CY'),
                        infoRow(
                          'Service fee secured',
                          '${money(e.serviceFee)} CY',
                        ),
                        if (!e.pesoPurchase)
                          infoRow(
                            'Original purchase budget secured',
                            e.purchaseAmount(e.budget),
                          ),
                        if (e.pesoPurchase && e.budget > 0)
                          Text(
                            'The ₱${money(e.budget)} purchase budget is funded separately and has its own receipt.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: muted,
                              height: 1.5,
                            ),
                          ),
                      ],
                      if (entry.type == 'Purchase Budget' ||
                          entry.type == 'Purchase Reimbursement')
                        Text(
                          'Actual purchase cost: ${e.purchaseAmount(e.actualCost ?? e.budget)}. ${e.pesoPurchase ? 'Peso reimbursements have no coin conversion deduction.' : 'This errand keeps its original coin budget terms.'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: muted,
                            height: 1.5,
                          ),
                        ),
                      if (released)
                        const Text(
                          'Released after the requester confirmed completion.',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                    ],
                    if (allocation)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'This allocates already secured funds. It does not deduct your wallet balance again.',
                          style: TextStyle(
                            fontSize: 11,
                            color: muted,
                            height: 1.5,
                          ),
                        ),
                      ),
                    if (entry.currency == 'PHP')
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Separate peso funds. This amount is not added to or taken from the coin balance.',
                          style: TextStyle(
                            fontSize: 11,
                            color: muted,
                            height: 1.5,
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    const Divider(),
                    const Text(
                      'REFERENCE',
                      style: TextStyle(
                        fontSize: 9,
                        color: muted,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SelectableText(
                      reference,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Recorded in Errandly. Payments and transfers are simulated. Rate estimates do not change the original transaction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, color: muted, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: reference));
              if (context.mounted) toast(context, 'Reference copied.');
            },
            icon: const Icon(Icons.copy_outlined, size: 17),
            label: const Text('Copy reference'),
          ),
        ],
      ),
    );
  }
}

class _ReceiptEdge extends CustomClipper<Path> {
  const _ReceiptEdge();
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 8);
    const tooth = 12.0;
    for (var x = size.width; x > 0; x -= tooth) {
      path
        ..lineTo((x - tooth / 2).clamp(0, size.width), size.height)
        ..lineTo((x - tooth).clamp(0, size.width), size.height - 8);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant _ReceiptEdge oldClipper) => false;
}
