import 'dart:async';

import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/wallet_rates.dart';
import '../state/personal_preferences.dart';
import 'components.dart';
import 'motion.dart';

class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.preferences,
    required this.child,
    this.enabled = true,
  });
  final PersonalPreferences preferences;
  final Widget child;
  final bool enabled;
  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? seen;
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      unawaited(load());
    } else {
      seen = true;
    }
  }

  Future<void> load() async {
    await widget.preferences.load();
    if (mounted && seen != true) {
      setState(() => seen = widget.preferences.guideSeen);
    }
  }

  void finish() {
    setState(() => seen = true);
    unawaited(widget.preferences.completeGuide().catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) => seen == true
      ? widget.child
      : seen == null
      ? const Scaffold(body: Center(child: Brand(size: 90)))
      : OnboardingGuide(onFinished: finish);
}

Future<void> openGuide(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            OnboardingGuide(onFinished: () => Navigator.pop(context)),
      ),
    );

class OnboardingGuide extends StatefulWidget {
  const OnboardingGuide({super.key, required this.onFinished});
  final VoidCallback onFinished;
  @override
  State<OnboardingGuide> createState() => _OnboardingGuideState();
}

class _OnboardingGuideState extends State<OnboardingGuide> {
  int step = 0;
  Widget card(IconData icon, String title, String text) => Panel(
    padding: 16,
    color: Colors.white,
    child: Row(
      children: [
        Icon(icon, color: teal, size: 28),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                text,
                style: const TextStyle(fontSize: 12, color: muted, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget visual() => switch (step) {
    0 => const ErrandIllustration(height: 190),
    1 => Panel(
      color: teal,
      padding: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 40,
            color: Colors.white,
          ),
          const SizedBox(height: 15),
          Text(
            '₱${money(WalletRates.topUpPesos)} → ${money(WalletRates.topUpCoins)} CY',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cash out ${money(WalletRates.cashOutCoins)} CY → ₱${money(WalletRates.cashOutPesos)}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    ),
    _ => const Center(child: SuccessMark(pending: true)),
  };
  @override
  Widget build(BuildContext context) {
    final titles = [
      'One account. Two ways to help.',
      'Coins for fees. Pesos for purchases.',
      'A secure handoff, every time.',
    ];
    final descriptions = [
      'Request help when you need it, or earn by helping someone nearby. Switch modes whenever you like.',
      'Your wallet pays the runner and service fee in CY. Money for the item is funded and reimbursed separately in pesos.',
      'The requester shares the PIN after receiving the item. Verification comes first; payment release follows confirmation.',
    ];
    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 14, 0),
                  child: Row(
                    children: [
                      const Brand(size: 50),
                      const Spacer(),
                      TextButton(
                        onPressed: widget.onFinished,
                        child: const Text('Skip guide'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 220),
                      child: Column(
                        key: ValueKey(step),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 15),
                          visual(),
                          const SizedBox(height: 28),
                          Text(
                            titles[step],
                            style: const TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                              letterSpacing: -.8,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            descriptions[step],
                            style: const TextStyle(
                              fontSize: 14,
                              color: muted,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (step == 0) ...[
                            card(
                              Icons.shopping_bag_outlined,
                              'Requester',
                              'Post an errand, set its budget, and track progress.',
                            ),
                            const SizedBox(height: 10),
                            card(
                              Icons.directions_run,
                              'Runner',
                              'Browse errands, ask questions, and accept a job.',
                            ),
                          ],
                          if (step == 1) ...[
                            card(
                              Icons.currency_exchange,
                              'Different buying and cash-out rates',
                              'Check the amount you receive before confirming.',
                            ),
                            const SizedBox(height: 10),
                            card(
                              Icons.receipt_long_outlined,
                              'Full purchase reimbursement',
                              'Actual item cost stays in pesos, with no coin conversion deduction.',
                            ),
                          ],
                          if (step == 2) ...[
                            card(
                              Icons.pin_outlined,
                              '1. Requester shares the PIN',
                              'Only after the item or service has been received.',
                            ),
                            const SizedBox(height: 10),
                            card(
                              Icons.verified_user_outlined,
                              '2. Runner verifies handoff',
                              'Earnings remain pending while awaiting confirmation.',
                            ),
                            const SizedBox(height: 10),
                            card(
                              Icons.check_circle_outline,
                              '3. Requester confirms',
                              'Coin earnings and separate purchase reimbursement are released.',
                            ),
                          ],
                          const SizedBox(height: 16),
                          const Text(
                            'Payments, uploads, and verification are simulated in this prototype.',
                            style: TextStyle(fontSize: 11, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'Step ${step + 1} of 3',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 3; i++)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.all(4),
                                height: 6,
                                width: i == step ? 26 : 8,
                                decoration: BoxDecoration(
                                  color: i == step
                                      ? teal
                                      : const Color(0xFFCDDDD3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (step > 0) ...[
                            OutlinedButton(
                              onPressed: () => setState(() => step--),
                              child: const Text('Back'),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: FilledButton(
                              onPressed: () => step == 2
                                  ? widget.onFinished()
                                  : setState(() => step++),
                              child: Text(step == 2 ? 'Get started' : 'Next'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
