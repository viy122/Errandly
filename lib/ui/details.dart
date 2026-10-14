import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/wallet_rates.dart';
import '../state/errand_store.dart';
import '../data/proof_picker.dart';
import 'components.dart';
import 'task_progress.dart';
import 'accept_confirmation.dart';
import 'pin_input.dart';
import 'motion.dart';
import 'errand_recovery.dart';
import 'proof_uploads.dart';
import 'errand_map.dart';

void openDetails(BuildContext context, ErrandStore s, Errand e) =>
    sheet(context, TaskDetails(store: s, errand: e));
void openChat(
  BuildContext context,
  ErrandStore s,
  Errand e, {
  String? otherId,
}) {
  if (e.ownerId == s.currentId && e.runnerId == null && otherId == null) {
    sheet(
      context,
      SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: MessagesPage(store: s, modal: true),
      ),
    );
  } else {
    sheet(context, ChatPanel(store: s, errand: e, otherId: otherId));
  }
}

Future<void> acceptDialog(
  BuildContext context,
  ErrandStore s,
  Errand e, {
  bool showTaskAfter = true,
}) async {
  final yes = await sheet<bool>(context, AcceptConfirmation(errand: e));
  if (yes == true &&
      context.mounted &&
      await attempt(
        context,
        () => s.accept(e),
        'You accepted ${s.users[e.ownerId]!.firstName}’s errand.',
      )) {
    if (context.mounted && showTaskAfter) openDetails(context, s, e);
  }
}

class TaskDetails extends StatefulWidget {
  const TaskDetails({
    super.key,
    required this.store,
    required this.errand,
    this.proofPicker,
  });
  final ErrandStore store;
  final Errand errand;
  final ProofPicker? proofPicker;
  @override
  State<TaskDetails> createState() => _TaskDetailsState();
}

class _TaskDetailsState extends State<TaskDetails> {
  final pin = TextEditingController();
  String? pinError;
  ErrandStore get s => widget.store;
  Errand get e => widget.errand;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    pin.dispose();
    super.dispose();
  }

  Future<void> verifyHandoff() async {
    try {
      if (pin.text.length != 6) throw StateError('Enter all six digits.');
      await s.verifyPin(e, pin.text);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() => pinError = null);
      sheet(
        context,
        SuccessFeedback(
          pending: true,
          title: 'Handoff verified',
          message:
              '${money(e.fee)} CY is still pending. The requester must confirm receipt before your earnings are released.',
        ),
      );
    } on StateError catch (error) {
      if (mounted) setState(() => pinError = error.message);
    }
  }

  Future<void> confirmCompletion() async {
    if (!await attempt(context, () => s.complete(e)) || !mounted) return;
    sheet(
      context,
      SuccessFeedback(
        title: 'Payment released',
        message:
            '${s.users[e.runnerId]!.firstName} earned ${money(e.fee)} CY.\n${e.pesoPurchase ? '${e.purchaseAmount(e.actualCost ?? e.budget)} purchase reimbursement sent separately.\n${e.purchaseAmount(e.refund)} refunded in pesos.' : '${e.purchaseAmount(e.refund)} returned to your coin wallet.'}',
      ),
    );
  }

  Widget tracker() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 18),
      Text(
        e.ownerId == s.currentId ? 'Runner progress' : 'Your job progress',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      TaskProgress(errand: e),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        shape: const Border(),
        collapsedShape: const Border(),
        title: const Text(
          'View progress history',
          style: TextStyle(fontSize: 11, color: muted),
        ),
        children: [
          for (var i = 0; i < 8; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Icon(
                    i <= e.progress
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: i <= e.progress ? teal : muted,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      progressLabels[i],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    e.history[i] == null ? '—' : timeLabel(e.history[i]!),
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
            ),
        ],
      ),
      if (e.runnerId == s.currentId &&
          !e.terminal &&
          !e.cancellationPending &&
          e.progress < 5) ...[
        if (e.progress == 2 && e.budget > 0)
          ProofUploadPanel(store: s, errand: e, picker: widget.proofPicker),
        const SizedBox(height: 14),
        if (e.progress != 2 ||
            e.budget == 0 ||
            (e.receipt && e.itemPhoto && e.actualCost != null))
          FilledButton.icon(
            onPressed: () => attempt(context, () => s.advance(e)),
            icon: const Icon(Icons.arrow_forward, size: 17),
            label: Text(
              [
                'Start Errand',
                'Arrived at Store / Pickup',
                'Item Purchased / Picked Up',
                'Start Delivery',
                'I’ve Arrived',
              ][e.progress],
            ),
          ),
      ],
      if (e.progress == 5 && !e.terminal && !e.cancellationPending) ...[
        const SizedBox(height: 12),
        if (e.ownerId == s.currentId) ...[
          note(
            'Only give this PIN to the Runner after receiving your item or confirming the task is complete.',
          ),
          const SizedBox(height: 18),
          Text(
            'Completion PIN: ${e.pin}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: teal,
              letterSpacing: 2,
            ),
          ),
          if (e.pinAttempts >= 5)
            note(
              'The runner has reached five incorrect attempts. Replace the PIN to unlock handoff.',
            ),
          TextButton.icon(
            onPressed: s.busy
                ? null
                : () => attempt(
                    context,
                    () => s.resetPin(e),
                    'New PIN generated. The old PIN no longer works.',
                  ),
            icon: const Icon(Icons.lock_reset, size: 18),
            label: const Text('Replace handoff PIN'),
          ),
        ] else if (e.runnerId == s.currentId) ...[
          ProofUploadPanel(
            store: s,
            errand: e,
            picker: widget.proofPicker,
            delivery: true,
          ),
          const SizedBox(height: 16),
          CompletionPinInput(
            controller: pin,
            error: pinError,
            onChanged: (_) {
              if (pinError != null) setState(() => pinError = null);
            },
          ),
          const SizedBox(height: 12),
          AsyncActionButton(
            label: 'Verify handoff',
            loadingLabel: 'Verifying…',
            onPressed: verifyHandoff,
            enabled: !s.busy && e.pinAttempts < 5,
          ),
          const SizedBox(height: 10),
          note(
            e.pinAttempts >= 5
                ? 'PIN locked after five incorrect attempts. Ask the requester to replace the handoff PIN.'
                : 'Ask the requester for the PIN after handing over the item. Only the requester can view it. ${5 - e.pinAttempts} attempts remaining.',
            icon: Icons.lock_outline,
          ),
        ],
      ],
      if (e.status == ErrandStatus.waiting && !e.cancellationPending) ...[
        Panel(
          padding: 16,
          color: pale,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: teal),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Handoff verified',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: teal,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Awaiting requester confirmation. ${money(e.fee)} CY stays pending until the requester confirms receipt.',
                style: const TextStyle(fontSize: 12, color: muted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (e.ownerId == s.currentId) ...[
          const Text(
            'Did you receive your errand?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 12),
          AsyncActionButton(
            label: 'Yes, Complete Errand',
            loadingLabel: 'Releasing payment…',
            enabled: !s.busy,
            onPressed: confirmCompletion,
          ),
          TextButton(
            onPressed: () => reportDialog(context, s, e),
            child: const Text('Report a Problem'),
          ),
        ],
      ],
      if (e.status == ErrandStatus.completed) ...[
        note(
          'Completed! Runner earned ${money(e.fee)} CY. Purchase: ${e.purchaseAmount(e.actualCost ?? e.budget)} · Refund: ${e.purchaseAmount(e.refund)} · Service fee: ${money(e.serviceFee)} CY.${e.pesoPurchase ? ' Purchase reimbursement and refund are separate simulated peso transfers.' : ''}',
        ),
        const SizedBox(height: 12),
        if ((e.ownerId == s.currentId || e.runnerId == s.currentId) &&
            !s.reviews.any(
              (r) => r.errandId == e.id && r.fromId == s.currentId,
            ))
          FilledButton.icon(
            onPressed: () => sheet(context, ReviewForm(store: s, errand: e)),
            icon: const Icon(Icons.star_outline),
            label: const Text('Leave a review'),
          ),
        const SizedBox(height: 8),
        if (e.runnerId != null &&
            (e.ownerId == s.currentId || e.runnerId == s.currentId))
          OutlinedButton.icon(
            onPressed: () => s.quietly(
              () => s.toggleFriend(
                s.currentId == e.ownerId ? e.runnerId! : e.ownerId,
              ),
            ),
            icon: const Icon(Icons.person_add_outlined),
            label: Text(
              s.friendIds.contains(
                    s.currentId == e.ownerId ? e.runnerId! : e.ownerId,
                  )
                  ? 'Remove friend'
                  : 'Add trusted friend',
            ),
          ),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) {
      final owner = s.users[e.ownerId]!;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Errand details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Close details',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
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
                              style: const TextStyle(
                                fontSize: 12,
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
                      Text(
                        '${owner.rating.toStringAsFixed(1)} ★ · ${owner.completed} completed',
                        style: const TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),
                Tag(
                  e.status == ErrandStatus.waiting
                      ? 'AWAITING CONFIRMATION'
                      : e.label,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              e.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 6),
            if (e.ownerId == s.currentId)
              const Tag('YOUR REQUEST')
            else if (e.runnerId == s.currentId)
              const Tag('YOUR JOB'),
            const SizedBox(height: 8),
            Text(
              e.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            DetailGrid(
              items: [
                ('Pickup', e.pickup),
                ('Drop-off', e.destination),
                ('Deadline', deadlineLabel(e.deadline)),
                (
                  e.distanceSource == 'osrm_driving'
                      ? 'Road trip estimate'
                      : 'Manual trip estimate',
                  distanceLabel(e.distance),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (e.pickupPoint != null || e.destinationPoint != null) ...[
              OutlinedButton.icon(
                onPressed: () => sheet(
                  context,
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Pickup & drop-off pins',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close errand map',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 330,
                          child: ErrandMap(
                            points: [
                              if (e.pickupPoint != null) e.pickupPoint!,
                              if (e.destinationPoint != null)
                                e.destinationPoint!,
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Green: pickup · Orange: drop-off',
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('View map pins'),
              ),
              const SizedBox(height: 14),
            ],
            Panel(
              color: canvas,
              padding: 16,
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lock_outline, color: teal, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Payment summary',
                        style: TextStyle(
                          color: teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  infoRow('Purchase budget', e.purchaseAmount(e.budget)),
                  infoRow(
                    e.runnerId == s.currentId
                        ? 'Your earnings'
                        : 'Runner payment',
                    '${money(e.fee)} CY',
                  ),
                  infoRow('Errandly service fee', '${money(e.serviceFee)} CY'),
                  infoRow(
                    'Coins secured',
                    '${money(e.total)} CY',
                    strong: true,
                  ),
                  infoRow(
                    'Runner cash-out value',
                    '₱${money(WalletRates.pesosForCashOut(e.fee))}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.pesoPurchase
                        ? 'Actual purchase costs are reimbursed in pesos. Coin earnings are released after requester confirmation.'
                        : 'This older errand uses its original coin purchase budget and refund terms.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (e.proofFiles.isNotEmpty &&
                (e.ownerId == s.currentId ||
                    e.runnerId == s.currentId ||
                    s.isSupport))
              ProofGallery(store: s, errand: e),
            if (e.proofFiles.isEmpty && (e.receipt || e.itemPhoto)) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  if (e.receipt)
                    Tag(
                      'Legacy sample receipt: ${e.purchaseAmount(e.actualCost ?? 0)}',
                      icon: Icons.receipt_long,
                    ),
                  if (e.itemPhoto)
                    const Tag(
                      'Legacy sample item photo',
                      icon: Icons.image_outlined,
                    ),
                ],
              ),
            ],
            if (e.runnerId != null) tracker(),
            if (e.cancellationPending) CancellationPanel(store: s, errand: e),
            const SizedBox(height: 12),
            if (e.available && s.currentId != e.ownerId && s.runnerMode)
              FilledButton(
                onPressed: () =>
                    acceptDialog(context, s, e, showTaskAfter: false),
                child: const Text('Accept Errand'),
              ),
            if (e.available && s.currentId != e.ownerId && !s.runnerMode)
              OutlinedButton.icon(
                onPressed: () => s.setMode(true),
                icon: const Icon(Icons.directions_run),
                label: const Text('Switch to Runner to accept'),
              ),
            OutlinedButton.icon(
              onPressed: () => openChat(context, s, e),
              icon: const Icon(Icons.chat_bubble_outline, size: 17),
              label: Text(
                e.ownerId == s.currentId
                    ? e.runnerId == null
                          ? 'Messages'
                          : 'Message runner'
                    : 'Message requester',
              ),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              shape: const Border(),
              collapsedShape: const Border(),
              title: const Text(
                'Instructions & details',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              children: [
                Text(
                  e.description,
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
                infoRow('Category', e.category),
                infoRow('Listing area', e.area),
                infoRow('Travel / delivery method', e.transport),
                note(e.instructions, icon: Icons.info_outline),
                for (final r in s.reviews.where((r) => r.toId == owner.id))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '${r.stars} ★ · ${r.text}',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
              ],
            ),
            if (e.ownerId == s.currentId &&
                !e.terminal &&
                !e.cancellationPending) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => cancelDialog(context, s, e),
                child: const Text('Cancel errand'),
              ),
              if (e.status == ErrandStatus.posted)
                TextButton(
                  onPressed: () => attempt(
                    context,
                    () => s.simulateExpiry(e),
                    'Deadline simulated. Payment refunded.',
                  ),
                  child: const Text('Simulate deadline expiry'),
                ),
            ],
            if (e.runnerId == s.currentId &&
                !e.terminal &&
                !e.cancellationPending)
              TextButton(
                onPressed: () => cancelDialog(context, s, e),
                child: const Text('Request cancellation'),
              ),
            if (e.status == ErrandStatus.expired)
              note(
                'No Runner accepted this task before the deadline. ${money(e.total)} CY${e.pesoPurchase && e.budget > 0 ? ' and ₱${money(e.budget)}' : ''} was refunded.',
              ),
            if (e.status == ErrandStatus.cancelled)
              note(
                'Cancelled: ${e.cancellationReason}. ${money(e.cancelRefundCoins ?? e.total)} CY${e.pesoPurchase && e.budget > 0 ? ' and ₱${money(e.cancelRefundPurchase ?? e.budget)}' : ''} refunded.${(e.actualCost ?? 0) > 0 && e.cancelRefundCoins != null ? ' Recorded purchase cost reimbursed: ${e.purchaseAmount(e.actualCost!)}.' : ''}${(e.cancelRunnerPayment ?? 0) > 0 ? ' Runner compensation: ${money(e.cancelRunnerPayment!)} CY.' : ''}',
              ),
            TextButton(
              onPressed: () => reportDialog(context, s, e),
              child: const Text('Report Post / Problem'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> cancelDialog(BuildContext context, ErrandStore s, Errand e) =>
    sheet(context, _CancelForm(store: s, errand: e));

class _CancelForm extends StatefulWidget {
  const _CancelForm({required this.store, required this.errand});
  final ErrandStore store;
  final Errand errand;
  @override
  State<_CancelForm> createState() => _CancelFormState();
}

class _CancelFormState extends State<_CancelForm> {
  String reason = 'No longer needed';
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageTitle('Cancel this errand?', 'Tell us what changed.'),
        if (widget.errand.runnerId != null) ...[
          note(
            'This errand has an assigned runner. The other participant must agree, or support must review recorded purchases and work. Funds stay secured until resolved.',
          ),
          const SizedBox(height: 16),
        ],
        select('Reason', reason, [
          'No longer needed',
          'Incorrect details',
          'Found another solution',
          'Runner issue',
          'Other',
        ], (v) => setState(() => reason = v!)),
        AsyncActionButton(
          enabled: !widget.store.busy,
          onPressed: () async {
            if (await attempt(
              context,
              () => widget.store.cancel(widget.errand, reason),
              widget.errand.runnerId == null
                  ? 'Errand cancelled and refunded.'
                  : 'Cancellation request submitted for review.',
            )) {
              if (context.mounted) Navigator.pop(context);
            }
          },
          label: widget.errand.runnerId == null
              ? 'Cancel and refund'
              : 'Request cancellation',
        ),
      ],
    ),
  );
}

void reportDialog(BuildContext context, ErrandStore s, [Errand? e]) =>
    sheet(context, ReportForm(store: s, errand: e));

class ReportForm extends StatefulWidget {
  const ReportForm({super.key, required this.store, this.errand});
  final ErrandStore store;
  final Errand? errand;
  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  String reason = 'Wrong item purchased';
  final description = TextEditingController();
  bool evidence = false;
  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageTitle(
          'Let’s make it right',
          'Submit a report for community support.',
        ),
        select('Reason', reason, [
          'Runner did not arrive',
          'Requester unavailable',
          'Wrong item purchased',
          'Missing item',
          'Damaged item',
          'Payment issue',
          'Harassment / Inappropriate behavior',
          'Fraud / Suspicious activity',
          'Other',
        ], (v) => setState(() => reason = v!)),
        field('Describe the problem', description, lines: 3),
        OutlinedButton.icon(
          onPressed: () => setState(() => evidence = !evidence),
          icon: Icon(evidence ? Icons.check_circle : Icons.attach_file),
          label: Text(
            evidence
                ? 'Sample evidence attached'
                : 'Attach sample evidence / receipt',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () async {
            if (description.text.trim().isEmpty) {
              toast(context, 'Describe the problem first.');
              return;
            }
            if (!await attempt(
              context,
              () => widget.store.report(
                reason,
                description.text,
                errand: widget.errand,
                evidence: evidence,
              ),
            )) {
              return;
            }
            if (!context.mounted) return;
            Navigator.pop(context);
            toast(context, 'Report Submitted. Track it in Safety Center.');
          },
          child: const Text('Submit Report'),
        ),
      ],
    ),
  );
}

class ReviewForm extends StatefulWidget {
  const ReviewForm({super.key, required this.store, required this.errand});
  final ErrandStore store;
  final Errand errand;
  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  final text = TextEditingController();
  final scores = {
    'Communication': 5,
    'Speed': 5,
    'Reliability': 5,
    'Item Handling': 5,
    'Overall Experience': 5,
  };
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageTitle(
          'How was your errand?',
          'Your feedback helps our community.',
        ),
        for (final key in scores.keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(key, style: const TextStyle(fontSize: 12)),
                Row(
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      tooltip: '$key ${i + 1} stars',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => scores[key] = i + 1),
                      icon: Icon(
                        i < scores[key]!
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: amber,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        field('Short review', text, lines: 3),
        FilledButton(
          onPressed: () async {
            if (text.text.trim().isEmpty) {
              toast(context, 'Add a short review.');
              return;
            }
            if (await attempt(
              context,
              () => widget.store.rate(
                widget.errand,
                scores['Overall Experience']!,
                text.text,
                scores,
              ),
              'Thank you for your review!',
            )) {
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Publish review'),
        ),
      ],
    ),
  );
}

class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.store,
    required this.errand,
    this.otherId,
  });
  final ErrandStore store;
  final Errand errand;
  final String? otherId;
  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final text = TextEditingController();
  final scroll = ScrollController();
  bool sending = false;
  int seenMessages = -1;
  String get otherId =>
      widget.otherId ??
      (widget.store.currentId == widget.errand.ownerId
          ? widget.errand.runnerId ?? widget.errand.ownerId
          : widget.errand.ownerId);
  @override
  void dispose() {
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> send([String? message]) async {
    if (sending || widget.store.busy) return;
    final body = message ?? text.text;
    if (body.trim().isEmpty) return;
    setState(() => sending = true);
    try {
      if (await attempt(
            context,
            () => widget.store.send(widget.errand, body, recipientId: otherId),
          ) &&
          mounted) {
        if (message == null) text.clear();
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final s = widget.store, e = widget.errand;
      final other = s.users[otherId]!;
      final messages = s.conversationMessages(e, otherId);
      if (messages.length != seenMessages) {
        final nearEnd =
            !scroll.hasClients ||
            scroll.offset >= scroll.position.maxScrollExtent - 80;
        seenMessages = messages.length;
        if (nearEnd) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && scroll.hasClients) {
              scroll.jumpTo(scroll.position.maxScrollExtent);
            }
          });
        }
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Avatar(other),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        other.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        e.title,
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close chat',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Tag(e.label),
            const SizedBox(height: 16),
            const Text(
              'Keep payments and conversations inside Errandly.',
              style: TextStyle(fontSize: 11, color: muted),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    for (final m in messages)
                      Align(
                        alignment: m.senderId == s.currentId
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 360),
                          decoration: BoxDecoration(
                            color: m.senderId == s.currentId ? teal : canvas,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.users[m.senderId]!.firstName,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: m.senderId == s.currentId
                                      ? Colors.white70
                                      : teal,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                m.text,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: m.senderId == s.currentId
                                      ? Colors.white
                                      : ink,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                timeLabel(m.date),
                                style: TextStyle(
                                  color: m.senderId == s.currentId
                                      ? Colors.white70
                                      : muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: text,
                    enabled: !sending,
                    onSubmitted: (_) => send(),
                    decoration: const InputDecoration(
                      hintText: 'Write a message…',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending || s.busy ? null : () => send(),
                  tooltip: 'Send message',
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (e.proofFiles.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => sheet(
                      context,
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: ProofGallery(store: s, errand: e),
                      ),
                    ),
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: const Text(
                      'View saved proof',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                TextButton.icon(
                  onPressed: sending || s.busy
                      ? null
                      : () => send(
                          '📍 I’m at ${e.progress < 3 ? e.pickup : e.destination}.',
                        ),
                  icon: const Icon(Icons.location_on_outlined, size: 16),
                  label: const Text(
                    'Location update',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key, required this.store, this.modal = false});
  final ErrandStore store;
  final bool modal;

  Widget thread(BuildContext context, Errand e, String otherId) {
    final entries = store.conversationMessages(e, otherId);
    final other = store.users[otherId]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: 4,
        child: ListTile(
          leading: Avatar(other),
          title: Text(other.name),
          subtitle: Text(
            '${e.title}\n${entries.isEmpty ? 'Start your conversation' : entries.last.text}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openChat(context, store, e, otherId: otherId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final list = store.conversations;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageTitle(
            'Messages',
            'Private conversations with requesters and runners.',
            trailing: modal
                ? IconButton(
                    tooltip: 'Close messages',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  )
                : null,
          ),
          if (list.isEmpty)
            const Empty(
              'No conversations yet',
              'Message a requester from an errand to start a conversation.',
            ),
          for (final entry in list) thread(context, entry.$1, entry.$2),
        ],
      );
    },
  );
}
