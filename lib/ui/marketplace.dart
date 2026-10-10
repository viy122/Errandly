import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../state/errand_store.dart';
import 'components.dart';
import 'role_dashboard.dart';
import 'errand_card.dart';
import 'feed_sort.dart';

class Marketplace extends StatefulWidget {
  const Marketplace({
    super.key,
    required this.store,
    required this.onPost,
    required this.onWallet,
    required this.onJobs,
    this.savedOnly = false,
  });
  final ErrandStore store;
  final VoidCallback onPost, onWallet, onJobs;
  final bool savedOnly;
  @override
  State<Marketplace> createState() => _MarketplaceState();
}

class _MarketplaceState extends State<Marketplace> {
  String category = 'All', sort = 'Newest', query = '';
  final feedKey = GlobalKey();
  bool refreshing = false;
  bool locating = false;
  String? locationError;
  Future<void> changeSort(String value) async {
    if (value == 'Nearest to me' && s.browsingPosition == null) {
      final account = s.currentId;
      setState(() {
        locating = true;
        locationError = null;
      });
      try {
        final position = await s.maps.currentPosition();
        if (!mounted || account != s.currentId) return;
        s.setBrowsingPosition(position);
      } on StateError catch (e) {
        if (mounted) setState(() => locationError = e.message);
        return;
      } finally {
        if (mounted) setState(() => locating = false);
      }
    }
    if (mounted) setState(() => sort = value);
  }

  Future<void> refreshFeed() async {
    setState(() => refreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    await s.reload();
    if (!mounted) return;
    setState(() => refreshing = false);
    s.refresh();
  }

  ErrandStore get s => widget.store;
  @override
  void didUpdateWidget(covariant Marketplace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (sort == 'Nearest to me' && s.browsingPosition == null && !locating) {
      sort = 'Newest';
    }
  }

  List<Errand> get filtered {
    final list =
        (widget.savedOnly
                ? s.errands.where((e) => s.savedIds.contains(e.id))
                : s.runnerOpportunities)
            .where(
              (e) =>
                  (category == 'All' || category == e.category) &&
                  (e.title.toLowerCase().contains(query.toLowerCase()) ||
                      e.description.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      e.pickup.toLowerCase().contains(query.toLowerCase())),
            )
            .toList();
    list.sort(
      (a, b) => switch (sort) {
        'Highest Pay' => b.fee.compareTo(a.fee),
        'Newest' => b.postedAt.compareTo(a.postedAt),
        'Urgent' => (b.urgent ? 1 : 0).compareTo(a.urgent ? 1 : 0),
        'Nearest to me' => comparePickupDistance(a, b, s.browsingPosition),
        _ => a.distance.compareTo(b.distance),
      },
    );
    return list;
  }

  Widget hero(bool small) => Container(
    padding: EdgeInsets.all(small ? 22 : 28),
    decoration: BoxDecoration(
      color: pale,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Tag('RUNNER DASHBOARD', icon: Icons.directions_run),
              const SizedBox(height: 15),
              Text(
                s.runnerMode
                    ? 'Free time?\nMake it worth your while.'
                    : 'Busy day?\nLet someone lend a hand.',
                style: TextStyle(
                  fontSize: small ? 27 : 32,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.runnerMode
                    ? 'Help someone out. Earn on your schedule.\nChoose a trip that works for you.'
                    : 'From a quick pickup to a delivery across cities,\nyour community has you covered.',
                style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: s.runnerMode
                    ? () => Scrollable.ensureVisible(
                        feedKey.currentContext!,
                        duration: const Duration(milliseconds: 350),
                        alignment: .1,
                      )
                    : widget.onPost,
                icon: Icon(
                  s.runnerMode ? Icons.explore_outlined : Icons.add,
                  size: 17,
                ),
                label: Text(
                  s.runnerMode
                      ? 'Find your next errand'
                      : 'Post your first errand',
                ),
              ),
            ],
          ),
        ),
        if (!small)
          const Expanded(
            flex: 4,
            child: SizedBox(height: 190, child: NeighborhoodArt()),
          ),
      ],
    ),
  );
  Widget rail() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(23),
        decoration: BoxDecoration(
          color: teal,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFFBBD8CD),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your Errandly wallet',
                    style: TextStyle(color: Color(0xFFBBD8CD), fontSize: 12),
                  ),
                ),
                Icon(Icons.more_horiz, color: Colors.white),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  money(s.wallet.available),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'CY',
                  style: TextStyle(color: Color(0xFFBBD8CD), fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Available Errandly Coins',
              style: TextStyle(color: Color(0xFFBBD8CD), fontSize: 11),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active jobs',
                        style: TextStyle(
                          color: Color(0xFFBBD8CD),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${s.activeJobs.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pending earnings',
                        style: TextStyle(
                          color: Color(0xFFBBD8CD),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${money(s.pending)} CY',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: teal,
                  minimumSize: const Size(0, 40),
                ),
                onPressed: widget.onWallet,
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                ),
                label: const Text(
                  'View earnings',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Panel(
        padding: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Your community at a glance',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(Icons.public, size: 18, color: teal),
              ],
            ),
            const SizedBox(height: 18),
            infoRow('Available errands', '${s.runnerOpportunities.length}'),
            infoRow(
              'Completed jobs this session',
              '${s.jobs.where((e) => e.status == ErrandStatus.completed).length}',
            ),
            infoRow('Your rating', '${s.user.rating.toStringAsFixed(1)} ★'),
            const Divider(),
            const Text(
              'Small tasks. Real connections.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Panel(
        padding: 20,
        color: const Color(0xFFFAF5E9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: teal, size: 21),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You’re in good company',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Verified users. Secured payments.\nA community that looks out for you.',
              style: TextStyle(fontSize: 11, color: muted, height: 1.7),
            ),
            const SizedBox(height: 16),
            const Tag('IDENTITY VERIFIED', icon: Icons.verified),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Everyday help, wherever you are.\n© 2026 Errandly  •  Prototype',
          style: TextStyle(color: muted, fontSize: 10, height: 1.8),
        ),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final small = box.maxWidth < 650;
      final compact = MediaQuery.sizeOf(context).width < 980;
      final list = filtered;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact || widget.savedOnly)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 14,
              spacing: 20,
              children: [
                SizedBox(
                  width: small ? box.maxWidth : box.maxWidth - 290,
                  child: PageTitle(
                    widget.savedOnly
                        ? 'Your saved errands'
                        : 'Hey, ${s.user.firstName} 👋',
                    widget.savedOnly ? 'A little bookmark for later.' : 'Choose your next job. Track your work. Earn on your schedule.',
                  ),
                ),
              ],
            ),
          if (!compact || widget.savedOnly) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.savedOnly && !compact) ...[
                      hero(small),
                      const SizedBox(height: 18),
                      DashboardStats(
                        items: [
                          (
                            'Available errands',
                            '${s.runnerOpportunities.length}',
                          ),
                          ('Active jobs', '${s.activeJobs.length}'),
                          ('Pending earnings', '${money(s.pending)} CY'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: widget.onJobs,
                        icon: const Icon(Icons.route_outlined),
                        label: Text(
                          s.activeJobs.isEmpty
                              ? 'View active jobs'
                              : 'Continue your active jobs (${s.activeJobs.length})',
                        ),
                      ),
                      const SizedBox(height: 26),
                    ],
                    if (compact &&
                        !widget.savedOnly &&
                        s.activeJobs.isNotEmpty) ...[
                      OutlinedButton.icon(
                        onPressed: widget.onJobs,
                        icon: const Icon(Icons.route_outlined, size: 18),
                        label: Text(
                          'Continue your active jobs (${s.activeJobs.length})',
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (!small || widget.savedOnly)
                      Row(
                        key: feedKey,
                        children: [
                          Expanded(
                            child: Text(
                              widget.savedOnly
                                  ? 'Saved for later'
                                  : 'Available errands',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Tag('${list.length} errands', color: muted),
                        ],
                      ),
                    if (!small || widget.savedOnly) const SizedBox(height: 16),
                    TextField(
                      onChanged: (v) => setState(() => query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search errands',
                        prefixIcon: Icon(Icons.search, size: 21),
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: categories
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (!small)
                                        Icon(
                                          categoryIcon(c),
                                          size: 14,
                                          color: category == c
                                              ? Colors.white
                                              : muted,
                                        ),
                                      if (!small) const SizedBox(width: 6),
                                      Text(c),
                                    ],
                                  ),
                                  selected: category == c,
                                  onSelected: (_) =>
                                      setState(() => category = c),
                                  showCheckmark: false,
                                  selectedColor: teal,
                                  backgroundColor: Colors.white,
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    color: category == c ? Colors.white : muted,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: FeedSortControl(
                            value: sort,
                            small: small,
                            busy: locating,
                            onChanged: changeSort,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Refresh errands',
                          onPressed: refreshing ? null : refreshFeed,
                          icon: const Icon(
                            Icons.refresh,
                            size: 19,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                    if (locationError != null)
                      Text(
                        locationError!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFAD5743),
                        ),
                      ),
                    if (sort == 'Nearest to me') ...[
                      const Text(
                        'Nearest uses straight-line distance to pickup. Posts without a pickup pin appear last.',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                      TextButton.icon(
                        onPressed: locating
                            ? null
                            : () {
                                s.setBrowsingPosition(null);
                                changeSort('Nearest to me');
                              },
                        icon: const Icon(Icons.my_location, size: 16),
                        label: const Text('Update my location'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (list.isEmpty)
                      const Empty(
                        'No errands here yet',
                        'Try another category, area, or search. Your next opportunity is out there.',
                      ),
                    if (refreshing)
                      const FeedSkeleton()
                    else
                      LayoutBuilder(
                        builder: (context, c) {
                          final two = c.maxWidth >= 720;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: list
                                .map(
                                  (e) => SizedBox(
                                    width: two
                                        ? (c.maxWidth - 16) / 2
                                        : c.maxWidth,
                                    child: ErrandCard(store: s, errand: e),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                  ],
                ),
              ),
              if (box.maxWidth >= 1060) ...[
                const SizedBox(width: 26),
                SizedBox(width: 275, child: rail()),
              ],
            ],
          ),
          if (!compact && box.maxWidth < 1060 && !widget.savedOnly) ...[
            const SizedBox(height: 24),
            rail(),
          ],
        ],
      );
    },
  );
}

class MyErrands extends StatefulWidget {
  const MyErrands({super.key, required this.store, this.onFind, this.onPost});
  final ErrandStore store;
  final VoidCallback? onFind, onPost;
  @override
  State<MyErrands> createState() => _MyErrandsState();
}

class _MyErrandsState extends State<MyErrands> {
  late String tab;
  late bool runner;
  @override
  void initState() {
    super.initState();
    runner = widget.store.runnerMode;
    tab = runner ? 'Active Jobs' : 'Posted';
  }

  @override
  void didUpdateWidget(covariant MyErrands oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (runner != widget.store.runnerMode) {
      runner = widget.store.runnerMode;
      tab = runner ? 'Active Jobs' : 'Posted';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final source = runner ? s.jobs : s.requests;
    final stages = runner
        ? [
            'Active Jobs',
            'Accepted',
            'In Progress',
            'Awaiting Payment',
            'Completed',
            'Cancelled',
          ]
        : [
            'Posted',
            'In Progress',
            'Awaiting Confirmation',
            'Completed',
            'Cancelled',
          ];
    final list = source.where((e) => roleStage(e, runner) == tab).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTitle(
          runner ? 'Your jobs, in one place' : 'Your requests, in one place',
          runner
              ? 'Keep track of the work you accepted and the earnings to come.'
              : 'Follow each request from posting to confirmed delivery.',
        ),
        if (!runner && widget.onPost != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: widget.onPost,
              icon: const Icon(Icons.add),
              label: const Text('Post an Errand'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final stage in stages)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '$stage (${source.where((e) => stage == 'Active Jobs' ? !e.terminal : roleStage(e, runner) == stage).length})',
                    ),
                    selected: tab == stage,
                    onSelected: (_) => setState(() => tab = stage),
                    showCheckmark: false,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (tab == 'Active Jobs')
          ActiveJobsPage(store: s, onFind: widget.onFind, showTitle: false),
        if (tab != 'Active Jobs' && list.isEmpty)
          Empty(
            'No ${tab.toLowerCase()} ${runner ? 'jobs' : 'requests'}',
            runner
                ? 'Find an errand to accept. Only jobs assigned to you appear here.'
                : 'Post an errand to get started. Only your own requests appear here.',
          ),
        for (final e in tab == 'Active Jobs' ? <Errand>[] : list) ...[
          ErrandSummaryCard(store: s, errand: e, runner: runner),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
