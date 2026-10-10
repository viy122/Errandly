import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/wallet_rates.dart';
import '../state/errand_store.dart';
import 'components.dart';
import 'intro.dart';
import 'details.dart';
import 'wallet_top_up.dart';
import 'transaction_receipt.dart';
import 'notification_settings.dart';
import 'onboarding.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key, required this.store});
  final ErrandStore store;
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  bool allActivity = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final entries = s.transactions
        .where(
          (t) =>
              t.userId == s.currentId &&
              (allActivity ||
                  (s.runnerMode
                          ? const {
                              'Runner Earnings',
                              'Purchase Reimbursement',
                              'Cash Out',
                              'Top Up',
                            }
                          : const {
                              'Errand Payment',
                              'Purchase Budget',
                              'Purchase Funding',
                              'Service Fee',
                              'Refund',
                              'Top Up',
                            })
                      .contains(t.type)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageTitle(
          s.runnerMode
              ? 'Your time. Your earnings.'
              : 'Your wallet. Your requests.',
          s.runnerMode
              ? 'Track your earnings and cash out your available balance.'
              : 'Fund your requests, track secured payments, and see your refunds.',
        ),
        LayoutBuilder(
          builder: (context, box) {
            final balance = Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: teal,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AVAILABLE BALANCE',
                    style: TextStyle(
                      color: Color(0xFFBBD8CD),
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    '${money(s.wallet.available)} CY',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Errandly Coins',
                    style: TextStyle(color: Color(0xFFBBD8CD), fontSize: 12),
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: teal,
                        ),
                        onPressed: () =>
                            openWalletAction(context, s, cashout: s.runnerMode),
                        icon: Icon(
                          s.runnerMode ? Icons.north_east : Icons.add,
                          size: 17,
                        ),
                        label: Text(s.runnerMode ? 'Cash out' : 'Top up'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF78A798)),
                        ),
                        onPressed: () => openWalletAction(
                          context,
                          s,
                          cashout: !s.runnerMode,
                        ),
                        icon: Icon(
                          s.runnerMode ? Icons.add : Icons.north_east,
                          size: 17,
                        ),
                        label: Text(s.runnerMode ? 'Top up' : 'Cash out'),
                      ),
                    ],
                  ),
                ],
              ),
            );
            final stats = Panel(
              child: Column(
                children: [
                  if (s.runnerMode) ...[
                    infoRow(
                      'Cash-out value of available coins',
                      '₱${money(WalletRates.pesosForCashOut(s.wallet.available))}',
                    ),
                    infoRow('Pending earnings', '${money(s.pending)} CY'),
                    infoRow(
                      'Total earnings',
                      '${money(s.wallet.totalEarnings)} CY',
                    ),
                    infoRow('Active jobs', '${s.activeJobs.length}'),
                    infoRow(
                      'Purchase reimbursements sent',
                      '₱${money(s.reimbursements)}',
                    ),
                  ] else ...[
                    infoRow(
                      'Secured payments',
                      '${money(s.securedPayments)} CY',
                    ),
                    infoRow(
                      'Separate purchase funds secured',
                      '₱${money(s.purchaseBudget)}',
                    ),
                    infoRow(
                      'Coin refunds received',
                      '${money(s.wallet.refunds)} CY',
                    ),
                    infoRow('Peso refunds sent', '₱${money(s.pesoRefunds)}'),
                  ],
                  const Divider(),
                  Text(
                    s.runnerMode
                        ? 'Coin earnings become available after confirmation. Purchase reimbursements are separate simulated peso transfers; they do not enter your coin balance.'
                        : 'Coins secure runner payment and service fees. Purchase funds are secured separately in pesos; unused pesos are refunded through a simulated transfer.',
                    style: TextStyle(color: muted, fontSize: 11, height: 1.6),
                  ),
                ],
              ),
            );
            return box.maxWidth > 720
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: balance),
                      const SizedBox(width: 20),
                      Expanded(child: stats),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [balance, const SizedBox(height: 18), stats],
                  );
          },
        ),
        const SizedBox(height: 20),
        note(
          'Buy ${money(WalletRates.topUpCoins)} CY for ₱${money(WalletRates.topUpPesos)}. Cash out ${money(WalletRates.cashOutCoins)} CY for ₱${money(WalletRates.cashOutPesos)}. Purchase reimbursements remain in pesos with no conversion deduction. Transactions are simulated.',
          icon: Icons.swap_horiz,
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                allActivity
                    ? 'All wallet activity'
                    : s.runnerMode
                    ? 'Earnings history'
                    : 'Payment & refund history',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => allActivity = !allActivity),
              child: Text(allActivity ? 'This mode' : 'All activity'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          s.runnerMode
              ? 'Your balance is shared across both modes. Use All activity to see payments and refunds too.'
              : 'Your balance is shared across both modes. Purchase and service-fee rows allocate already secured funds; they do not deduct your balance twice.',
          style: const TextStyle(fontSize: 11, color: muted, height: 1.5),
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          const Empty(
            'A fresh start',
            'Your top-ups, earnings and payments will appear here.',
          ),
        for (final t in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              key: ValueKey('receipt-${t.id}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () =>
                  sheet(context, TransactionReceipt(store: s, entry: t)),
              child: Panel(
                padding: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: t.amount > 0 ? pale : canvas,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        t.amount > 0 ? Icons.south_west : Icons.north_east,
                        color: teal,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.type,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${t.date.month}/${t.date.day} · ${timeLabel(t.date)} · ${t.note}',
                            style: const TextStyle(color: muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${t.amount > 0 ? '+' : '−'}${t.currency == 'PHP' ? '₱${money(t.amount.abs())}' : '${money(t.amount.abs())} CY'}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: t.amount > 0 ? teal : ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          t.status,
                          style: const TextStyle(color: muted, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> openWalletAction(
  BuildContext context,
  ErrandStore store, {
  bool cashout = false,
}) async {
  if (cashout) {
    await sheet(context, WalletAction(store: store, cashout: true));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: WalletAction(store: store)),
      ),
    ),
  );
}

class WalletAction extends StatefulWidget {
  const WalletAction({super.key, required this.store, this.cashout = false});
  final ErrandStore store;
  final bool cashout;
  @override
  State<WalletAction> createState() => _WalletActionState();
}

class _WalletActionState extends State<WalletAction> {
  final amount = TextEditingController(text: '110'),
      phone = TextEditingController();
  bool confirm = false;

  @override
  void dispose() {
    amount.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.cashout) return WalletTopUp(store: widget.store);
    final enteredCoins = double.tryParse(amount.text) ?? 0;
    final coins = enteredCoins.isFinite && enteredCoins > 0
        ? enteredCoins
        : 0.0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitle(
            'Your effort, cashed out.',
            '${money(WalletRates.cashOutCoins)} CY → ₱${money(WalletRates.cashOutPesos)}. Simulated GCash transfer.',
          ),
          infoRow(
            'Available balance',
            '${money(widget.store.wallet.available)} CY',
          ),
          const SizedBox(height: 14),
          if (!confirm) ...[
            field(
              'Amount to cash out (CY)',
              amount,
              type: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            field('GCash number', phone, type: TextInputType.phone),
          ],
          infoRow('Cash out', '${money(coins)} CY'),
          infoRow(
            'You receive in pesos',
            '₱${money(WalletRates.pesosForCashOut(coins))}',
            strong: true,
          ),
          if (confirm)
            note(
              'Confirm simulated transfer to ${phone.text}. Your available balance will decrease by ${money(coins)} CY.',
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              if (!confirm) {
                if (!coins.isFinite ||
                    coins <= 0 ||
                    coins > widget.store.wallet.available) {
                  toast(
                    context,
                    'Enter an amount within your available balance.',
                  );
                  return;
                }
                if (!RegExp(r'^09\d{9}$').hasMatch(phone.text)) {
                  toast(
                    context,
                    'Enter a valid 11-digit GCash number starting with 09.',
                  );
                  return;
                }
                setState(() => confirm = true);
                return;
              }
              if (await attempt(
                context,
                () => widget.store.cashOut(coins, phone.text),
                'Cash out successfully simulated.',
              )) {
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(confirm ? 'Confirm cash out' : 'Review cash out'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.store, this.modal = false});
  final ErrandStore store;
  final bool modal;
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String tab = 'All';
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final list = s.notifications
        .where(
          (n) => n.userId == s.currentId && (tab == 'All' || n.type == tab),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.modal) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Notifications',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Notification settings',
                onPressed: () => openNotificationSettings(context, s),
                icon: const Icon(Icons.settings_outlined),
              ),
              IconButton(
                tooltip: 'Close notifications',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => s.quietly(() => s.markRead()),
              child: const Text('Mark all read'),
            ),
          ),
        ] else
          PageTitle(
            'Keeping you posted',
            'The little updates that keep everything moving.',
            trailing: TextButton(
              onPressed: () => s.quietly(() => s.markRead()),
              child: const Text(
                'Mark all read',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
        Wrap(
          spacing: 8,
          children: ['All', 'Errands', 'Wallet', 'Messages']
              .map(
                (v) => ChoiceChip(
                  label: Text(v),
                  selected: tab == v,
                  onSelected: (_) => setState(() => tab = v),
                ),
              )
              .toList(),
        ),
        if (!widget.modal)
          TextButton.icon(
            onPressed: () => openNotificationSettings(context, s),
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const Text('Notification settings'),
          ),
        const SizedBox(height: 22),
        if (list.isEmpty)
          const Empty(
            'You’re all caught up',
            'Updates will appear here as your errands move along.',
          ),
        for (final n in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Panel(
              color: n.read ? Colors.white : pale,
              padding: 4,
              child: ListTile(
                leading: Icon(
                  n.type == 'Wallet'
                      ? Icons.account_balance_wallet_outlined
                      : n.type == 'Messages'
                      ? Icons.chat_bubble_outline
                      : Icons.bolt_outlined,
                  color: teal,
                ),
                title: Text(n.text, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  timeLabel(n.date),
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
                trailing: n.read
                    ? null
                    : const Icon(Icons.circle, size: 7, color: teal),
                onTap: () {
                  s.quietly(() => s.markRead(n));
                  if (n.type == 'Messages') {
                    sheet(
                      context,
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: MessagesPage(store: s, modal: true),
                      ),
                    );
                    return;
                  }
                  final found = s.errands.where((e) => e.id == n.errandId);
                  if (found.isNotEmpty) {
                    openDetails(context, s, found.first);
                  }
                },
              ),
            ),
          ),
      ],
    );
  }
}

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key, required this.store});
  final ErrandStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: NotificationsPage(store: store, modal: true),
    ),
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.store,
    this.onSaved,
    this.onFriends,
    this.onSafety,
  });
  final ErrandStore store;
  final VoidCallback? onSaved, onFriends, onSafety;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String tab = 'Posts';
  @override
  Widget build(BuildContext context) {
    final s = widget.store, u = s.user;
    final reviewList = s.reviews.where((r) => r.toId == u.id).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageTitle('My profile', 'Your community starts with you.'),
        Panel(
          padding: 4,
          child: Column(
            children: [
              for (final entry in [
                (
                  'Settings',
                  Icons.settings_outlined,
                  () => openNotificationSettings(context, s),
                ),
                if (widget.onSaved != null)
                  ('Saved errands', Icons.bookmark_border, widget.onSaved!),
                if (widget.onFriends != null)
                  (
                    'Friends & favorites',
                    Icons.people_outline,
                    widget.onFriends!,
                  ),
                if (widget.onSafety != null)
                  ('Safety center', Icons.shield_outlined, widget.onSafety!),
              ])
                ListTile(
                  key: ValueKey('profile-${entry.$1}'),
                  leading: Icon(entry.$2, color: teal),
                  title: Text(
                    entry.$1,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: entry.$3,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          child: Column(
            children: [
              Avatar(u, size: 88),
              const SizedBox(height: 16),
              Text(
                u.name,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 9),
              const Tag('Verified User', icon: Icons.verified),
              const SizedBox(height: 14),
              Text(
                u.bio,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted, height: 1.6),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 22,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  Text(
                    '${u.rating.toStringAsFixed(1)} ★ · ${reviewList.length} reviews',
                  ),
                  Text('${u.completed} completed errands'),
                  const Text('Member since 2026'),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => sheet(context, EditProfile(store: s)),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit profile'),
              ),
              const SizedBox(height: 10),
              Text(
                u.location,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 8,
          children: ['Posts', 'Completed', 'Reviews']
              .map(
                (v) => ChoiceChip(
                  label: Text(v),
                  selected: tab == v,
                  onSelected: (_) => setState(() => tab = v),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        if (tab == 'Reviews') ...[
          if (reviewList.isEmpty)
            const Empty(
              'Your story is just starting',
              'Reviews from completed errands will appear here.',
            ),
          for (final r in reviewList)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.users[r.fromId]!.name} · ${r.stars} ★',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(r.text),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: r.scores.entries
                          .map(
                            (v) => Tag('${v.key} ${v.value}/5', color: muted),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
        ] else ...[
          for (final e in s.mine.where(
            (e) => tab == 'Posts'
                ? e.ownerId == s.currentId
                : e.status == ErrandStatus.completed,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                padding: 5,
                child: ListTile(
                  leading: Icon(categoryIcon(e.category), color: teal),
                  title: Text(e.title),
                  subtitle: Text(e.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openDetails(context, s, e),
                ),
              ),
            ),
          if (s.mine
              .where(
                (e) => tab == 'Posts'
                    ? e.ownerId == s.currentId
                    : e.status == ErrandStatus.completed,
              )
              .isEmpty)
            const Empty(
              'Nothing here just yet',
              'Your errands will appear here.',
            ),
        ],
        const SizedBox(height: 24),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your privacy, your choice',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Email and phone are private by default.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              select(
                'Phone visibility',
                u.phonePrivacy,
                ['Private', 'Friends Only', 'Public'],
                (v) {
                  u.phonePrivacy = v!;
                  s.quietly(s.saveProfile);
                },
              ),
              select(
                'Email visibility',
                u.emailPrivacy,
                ['Private', 'Friends Only', 'Public'],
                (v) {
                  u.emailPrivacy = v!;
                  s.quietly(s.saveProfile);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (s.isDemoAccount)
          Panel(
            color: const Color(0xFFFAF5E9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Try both sides of an errand',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Switch demo accounts to follow a request or confirm a delivery.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in ['ben', 'anna', 'maria', 'joshua'])
                      OutlinedButton(
                        onPressed: () => s.quietly(() => s.demo(id)),
                        child: Text(s.users[id]!.firstName),
                      ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () => openGuide(context),
          icon: const Icon(Icons.auto_stories_outlined, size: 18),
          label: const Text('How Errandly works'),
        ),
        TextButton.icon(
          onPressed: () => replayIntro(context),
          icon: const Icon(Icons.play_circle_outline, size: 18),
          label: const Text('Replay Errandly intro'),
        ),
        TextButton.icon(
          onPressed: () => attempt(context, s.logout),
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}

class EditProfile extends StatefulWidget {
  const EditProfile({super.key, required this.store});
  final ErrandStore store;
  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, email, phone, bio, area;
  late bool photo;
  @override
  void initState() {
    super.initState();
    final u = widget.store.user;
    name = TextEditingController(text: u.name);
    email = TextEditingController(text: u.email);
    phone = TextEditingController(text: u.phone);
    bio = TextEditingController(text: u.bio);
    area = TextEditingController(text: u.location);
    photo = u.photo;
  }

  @override
  void dispose() {
    for (final c in [name, email, phone, bio, area]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(26),
    child: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageTitle(
            'Make yourself at home',
            'A little about the person behind the errands.',
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() => photo = !photo),
            icon: Icon(photo ? Icons.check_circle : Icons.add_a_photo_outlined),
            label: Text(
              photo
                  ? 'Sample profile photo selected'
                  : 'Change profile photo (sample)',
            ),
          ),
          const SizedBox(height: 18),
          field('Full name', name),
          field(
            'Email',
            email,
            validator: (v) =>
                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v ?? '')
                ? null
                : 'Enter a valid email',
          ),
          field(
            'Phone',
            phone,
            validator: (v) => RegExp(r'^\+?\d{7,15}$').hasMatch(v ?? '')
                ? null
                : 'Use 7-15 digits, with an optional + country code',
          ),
          field('Home area / city', area),
          field('Bio', bio, lines: 3, validator: (_) => null),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) {
                return;
              }
              final s = widget.store;
              if (s.users.values.any(
                (u) =>
                    u.id != s.currentId &&
                    u.email.toLowerCase() == email.text.trim().toLowerCase(),
              )) {
                toast(context, 'That email belongs to another account.');
                return;
              }
              final u = s.user;
              u.name = name.text.trim();
              u.email = email.text.trim();
              u.phone = phone.text;
              u.bio = bio.text;
              u.location = area.text.trim();
              u.photo = photo;
              if (!await attempt(context, s.saveProfile) || !context.mounted) {
                return;
              }
              Navigator.pop(context);
              toast(context, 'Profile updated.');
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    ),
  );
}

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key, required this.store, required this.onHire});
  final ErrandStore store;
  final VoidCallback onHire;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageTitle(
        'Your trusted people',
        'Keep your trusted runners close.',
      ),
      for (final u in store.users.values.where(
        (u) =>
            u.id != store.currentId &&
            !(store.blocked[store.currentId] ?? {}).contains(u.id),
      ))
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    Avatar(u, size: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${u.rating.toStringAsFixed(1)} ★ · ${u.completed} completed · ${u.location}',
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Favorite runner',
                      onPressed: () =>
                          store.quietly(() => store.toggleFavorite(u.id)),
                      icon: Icon(
                        store.favoriteIds.contains(u.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => sheet(
                        context,
                        MemberProfile(store: store, student: u),
                      ),
                      child: const Text('View profile'),
                    ),
                    if (store.friendIds.contains(u.id))
                      OutlinedButton(
                        onPressed: () =>
                            store.quietly(() => store.toggleFriend(u.id)),
                        child: const Text('Remove friend'),
                      )
                    else if (store.mine.any(
                      (e) =>
                          e.status == ErrandStatus.completed &&
                          (e.ownerId == u.id || e.runnerId == u.id),
                    ))
                      OutlinedButton(
                        onPressed: () =>
                            store.quietly(() => store.toggleFriend(u.id)),
                        child: const Text('Add friend'),
                      ),
                    if (store.friendIds.contains(u.id))
                      FilledButton(
                        onPressed: () async {
                          store.preferredRunnerId = u.id;
                          onHire();
                        },
                        child: const Text('Hire again'),
                      ),
                    OutlinedButton(
                      onPressed: () async {
                        final tasks = store.errands.where(
                          (e) => e.ownerId == u.id || e.runnerId == u.id,
                        );
                        if (tasks.isNotEmpty) {
                          openChat(context, store, tasks.first);
                        } else {
                          toast(
                            context,
                            'Chat is available from a shared errand.',
                          );
                        }
                      },
                      child: const Text('Message'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
      note(
        'Add trusted friends after a completed transaction. Favorite a runner to keep them on your list.',
        icon: Icons.people_outline,
      ),
    ],
  );
}

class MemberProfile extends StatelessWidget {
  const MemberProfile({super.key, required this.store, required this.student});
  final ErrandStore store;
  final UserProfile student;
  @override
  Widget build(BuildContext context) {
    final u = student;
    bool canSee(String p) =>
        p == 'Public' || p == 'Friends Only' && store.friendIds.contains(u.id);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(u, size: 80),
          const SizedBox(height: 18),
          Text(
            u.name,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (u.verified) const Tag('Verified User', icon: Icons.verified),
          const SizedBox(height: 12),
          Text(
            '${u.rating.toStringAsFixed(1)} ★ · ${u.completed} completed errands',
          ),
          const SizedBox(height: 12),
          Text(
            u.bio,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.6),
          ),
          const SizedBox(height: 14),
          infoRow('Home area', u.location),
          infoRow('Phone', canSee(u.phonePrivacy) ? u.phone : 'Private'),
          infoRow('Email', canSee(u.emailPrivacy) ? u.email : 'Private'),
          for (final r in store.reviews.where((r) => r.toId == u.id))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('${r.stars} ★ · ${r.text}'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class SafetyPage extends StatelessWidget {
  const SafetyPage({super.key, required this.store});
  final ErrandStore store;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const PageTitle(
        'A community that looks out for you',
        'A few good habits. A safer community.',
      ),
      if (store.isSupport) ...[
        const Text(
          'Pending cancellation reviews',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        for (final e in store.errands.where((e) => e.cancellationPending))
          ListTile(
            title: Text(e.title),
            subtitle: Text(e.cancellationReason ?? 'Cancellation requested'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openDetails(context, store, e),
          ),
        const SizedBox(height: 20),
      ],
      const Panel(
        color: pale,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: 38, color: teal),
            SizedBox(height: 16),
            Text(
              'Near or far. Shared trust.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 12),
            Text(
              'Never send money outside Errandly for an active transaction.\nMeet at safe, public, well-lit locations.\nShare your completion PIN only after receiving your item.',
              style: TextStyle(color: teal, height: 1.8),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      for (final row in [
        (
          'Verified users',
          'Identity document, email and phone verification help our community know who they’re meeting.',
        ),
        (
          'Transaction records',
          'Every secured payment, status update and refund has a record in your wallet and tracker.',
        ),
        (
          'Community guidelines',
          'Be respectful. Be on time. Communicate changes. Do not accept unsafe or prohibited tasks.',
        ),
        (
          'Local emergency support',
          'If you need urgent help, contact your local emergency services or visit the nearest police or barangay office. This demo does not configure real emergency telephone numbers.',
        ),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.$1,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  row.$2,
                  style: const TextStyle(
                    color: muted,
                    height: 1.6,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => reportDialog(context, store),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Report a user / problem'),
      ),
      const SizedBox(height: 22),
      const Text(
        'Block a user',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
      ),
      const SizedBox(height: 10),
      for (final u in store.users.values.where((u) => u.id != store.currentId))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Avatar(u, size: 32),
          title: Text(u.name, style: const TextStyle(fontSize: 13)),
          trailing: TextButton(
            onPressed: () async {
              final blocked = store.blocked.putIfAbsent(
                store.currentId!,
                () => {},
              );
              if (blocked.contains(u.id)) {
                if (store.databaseBacked) {
                  await attempt(context, () => store.block(u.id));
                } else {
                  blocked.remove(u.id);
                  store.refresh();
                }
              } else {
                await attempt(context, () => store.block(u.id));
              }
            },
            child: Text(
              (store.blocked[store.currentId] ?? {}).contains(u.id)
                  ? 'Unblock'
                  : 'Block',
            ),
          ),
        ),
      const SizedBox(height: 22),
      const Text(
        'Your reports',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
      ),
      const SizedBox(height: 12),
      if (!store.reports.any((r) => r.userId == store.currentId))
        const Empty(
          'No reports',
          'We’re here when you need support.',
          icon: Icons.shield_outlined,
        ),
      for (final r in store.reports.where((r) => r.userId == store.currentId))
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tag(r.status.toUpperCase()),
                const SizedBox(height: 12),
                Text(
                  r.reason,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  r.description,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                if (r.evidence)
                  const Text(
                    'Sample evidence attached',
                    style: TextStyle(fontSize: 11, color: teal),
                  ),
                const SizedBox(height: 12),
                if (r.reason.startsWith('Cancellation request:') &&
                    r.errandId != null)
                  TextButton(
                    onPressed: () => openDetails(
                      context,
                      store,
                      store.errands.firstWhere((e) => e.id == r.errandId),
                    ),
                    child: const Text('Open cancellation details'),
                  )
                else if (r.status != 'Resolved')
                  TextButton(
                    onPressed: () async {
                      await attempt(
                        context,
                        () => store.reportStatus(
                          r,
                          r.status == 'Submitted' ? 'Under Review' : 'Resolved',
                        ),
                      );
                    },
                    child: Text(
                      r.status == 'Submitted'
                          ? 'Simulate support review'
                          : 'Simulate resolved status',
                    ),
                  ),
                const Text(
                  'Support status is simulated. Resolution does not automatically move funds.',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}
