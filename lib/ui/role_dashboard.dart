import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/wallet_rates.dart';
import '../state/errand_store.dart';
import 'components.dart';
import 'details.dart';

String roleStage(Errand errand, bool runner) => switch (errand.status) {
  ErrandStatus.posted => 'Posted',
  ErrandStatus.accepted => runner ? 'Accepted' : 'In Progress',
  ErrandStatus.ongoing => 'In Progress',
  ErrandStatus.waiting => runner ? 'Awaiting Payment' : 'Awaiting Confirmation',
  ErrandStatus.completed => 'Completed',
  ErrandStatus.cancelled || ErrandStatus.expired => 'Cancelled',
};

class RoleModeSwitch extends StatelessWidget {
  const RoleModeSwitch({super.key, required this.store, this.light = false});
  final ErrandStore store;
  final bool light;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: light ? forest : canvas,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: light ? lime.withValues(alpha: .55) : line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final runner in [false, true])
          Expanded(
            child: Semantics(
              button: true,
              selected: store.runnerMode == runner,
              label: runner ? 'Runner Mode' : 'Requester Mode',
              child: InkWell(
                key: ValueKey(runner ? 'mode-runner' : 'mode-requester'),
                onTap: () => store.setMode(runner),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: store.runnerMode == runner
                        ? (light ? lime : ink)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    runner ? 'Runner' : 'Requester',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: store.runnerMode == runner
                          ? (light ? ink : Colors.white)
                          : (light ? Colors.white : muted),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class DashboardStats extends StatelessWidget {
  const DashboardStats({super.key, required this.items});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          SizedBox(
            width:
                (constraints.maxWidth -
                    (constraints.maxWidth < 480 ? 10 : 20)) /
                (constraints.maxWidth < 480 ? 2 : 3),
            child: Panel(
              padding: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: teal,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.$1,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class ErrandSummaryCard extends StatelessWidget {
  const ErrandSummaryCard({
    super.key,
    required this.store,
    required this.errand,
    required this.runner,
  });
  final ErrandStore store;
  final Errand errand;
  final bool runner;

  @override
  Widget build(BuildContext context) {
    final e = errand;
    final counterpart = runner
        ? store.users[e.ownerId]
        : store.users[e.runnerId];
    return Panel(
      padding: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Tag(roleStage(e, runner)),
              Tag(e.category, color: muted),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            e.title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            runner
                ? 'Requester: ${counterpart!.name}'
                : counterpart == null
                ? 'Waiting for a runner'
                : 'Runner: ${counterpart.name}',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          infoRow('Pickup', e.pickup),
          infoRow('Deliver to', e.destination),
          infoRow(
            runner
                ? 'You earn'
                : e.terminal
                ? 'Coin payment'
                : 'Coins secured',
            '${money(runner ? e.fee : e.total)} CY',
          ),
          if (runner)
            infoRow(
              'Cash-out value',
              '₱${money(WalletRates.pesosForCashOut(e.fee))}',
            ),
          if (e.budget > 0)
            infoRow(
              e.pesoPurchase
                  ? 'Separate purchase budget'
                  : 'Original coin purchase budget',
              e.purchaseAmount(e.budget),
            ),
          infoRow('Deadline', deadlineLabel(e.deadline)),
          if (e.progress >= 0 && !e.terminal) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (e.progress + 1) / 8,
              color: teal,
              backgroundColor: pale,
            ),
            const SizedBox(height: 8),
            Text(
              progressLabels[e.progress],
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ],
          if (e.status == ErrandStatus.expired) ...[
            const SizedBox(height: 8),
            const Text(
              'Expired before acceptance. Payment refunded.',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => openDetails(context, store, e),
            icon: Icon(
              runner ? Icons.route_outlined : Icons.location_searching,
              size: 17,
            ),
            label: Text(
              e.terminal
                  ? 'View details'
                  : runner
                  ? e.status == ErrandStatus.waiting
                        ? 'View payment status'
                        : 'Continue job'
                  : e.status == ErrandStatus.waiting
                  ? 'Confirm receipt'
                  : 'Track request',
            ),
          ),
        ],
      ),
    );
  }
}

class RequesterDashboard extends StatelessWidget {
  const RequesterDashboard({
    super.key,
    required this.store,
    required this.onPost,
    required this.onRequests,
    required this.onWallet,
  });
  final ErrandStore store;
  final VoidCallback onPost, onRequests, onWallet;

  @override
  Widget build(BuildContext context) {
    final requests = store.requests;
    final compact = MediaQuery.sizeOf(context).width < 980;
    final active = requests.where((e) => !e.terminal).toList()
      ..sort((a, b) => b.status.index.compareTo(a.status.index));
    int count(String stage) =>
        requests.where((e) => roleStage(e, false) == stage).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact)
          PageTitle(
            'Hey, ${store.user.firstName} 👋',
            'Your requests. Your progress. A little help when you need it.',
          ),
        if (compact)
          Panel(
            padding: 16,
            color: pale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Need a hand?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Post a request and follow your runner’s updates.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onPost,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Post an Errand'),
                ),
              ],
            ),
          )
        else
          Panel(
            color: pale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Tag('REQUESTER DASHBOARD', icon: Icons.add_task_outlined),
                const SizedBox(height: 16),
                const Text(
                  'Need a hand?\nLet someone help.',
                  style: TextStyle(
                    fontSize: 29,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Post a request, follow your runner’s progress, and confirm when everything arrives.',
                  style: TextStyle(color: muted, height: 1.6),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onPost,
                  icon: const Icon(Icons.add),
                  label: const Text('Post an Errand'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        DashboardStats(
          items: [
            ('Posted', '${count('Posted')}'),
            ('In Progress', '${count('In Progress')}'),
            ('Awaiting Confirmation', '${count('Awaiting Confirmation')}'),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your active requests',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(onPressed: onRequests, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 12),
        if (active.isEmpty)
          const Empty(
            'No active requests',
            'Post an errand and your runner’s updates will appear here.',
          ),
        for (final e in active.take(3)) ...[
          ErrandSummaryCard(store: store, errand: e, runner: false),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your request wallet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              infoRow(
                'Available balance',
                '${money(store.wallet.available)} CY',
              ),
              infoRow('Secured payments', '${money(store.securedPayments)} CY'),
              infoRow(
                'Separate peso purchase funds',
                '₱${money(store.purchaseBudget)}',
              ),
              infoRow('Refunds received', '${money(store.wallet.refunds)} CY'),
              infoRow('Peso refunds sent', '₱${money(store.pesoRefunds)}'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onWallet,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Manage wallet'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ActiveJobsPage extends StatelessWidget {
  const ActiveJobsPage({
    super.key,
    required this.store,
    this.onFind,
    this.showTitle = true,
  });
  final ErrandStore store;
  final VoidCallback? onFind;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final jobs = store.activeJobs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle)
          const PageTitle(
            'Your active jobs',
            'Pickup, delivery and handoff — keep your current work moving.',
          ),
        if (jobs.isEmpty) ...[
          const Empty(
            'No active job yet',
            'Accept an available errand to start earning. Your current jobs will appear here.',
          ),
          const SizedBox(height: 16),
          if (onFind != null)
            FilledButton.icon(
              onPressed: onFind,
              icon: const Icon(Icons.search),
              label: const Text('Find an Errand'),
            ),
        ],
        for (final e in jobs) ...[
          ErrandSummaryCard(store: store, errand: e, runner: true),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
