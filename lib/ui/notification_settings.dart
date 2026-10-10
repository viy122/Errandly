import 'dart:async';

import 'package:flutter/material.dart';

import '../state/errand_store.dart';
import 'components.dart';
import 'onboarding.dart';
import 'notification_tone.dart';

void openNotificationSettings(BuildContext context, ErrandStore store) =>
    sheet(context, NotificationSettings(store: store));

class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key, required this.store});
  final ErrandStore store;
  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  final tone = NotificationTone();
  @override
  void dispose() {
    unawaited(tone.dispose());
    super.dispose();
  }

  bool saving = false;
  Future<void> change(String type, bool value) async {
    if (saving) return;
    setState(() => saving = true);
    await attempt(
      context,
      () => widget.store.preferences.setAlert(
        widget.store.currentId!,
        type,
        value,
      ),
    );
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final prefs = widget.store.preferences.forAccount(widget.store.currentId);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Notification settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Close settings',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'For ${widget.store.user.firstName} on this device.',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            Panel(
              padding: 4,
              color: canvas,
              child: Column(
                children: [
                  for (final setting in [
                    (
                      'Errands',
                      'Errand updates',
                      'Acceptance, progress, and confirmation.',
                      Icons.route_outlined,
                      prefs.errands,
                    ),
                    (
                      'Messages',
                      'Chat messages',
                      'Private inquiries and job conversations.',
                      Icons.chat_bubble_outline,
                      prefs.messages,
                    ),
                    (
                      'Wallet',
                      'Wallet activity',
                      'Funding, earnings, refunds, and cash-outs.',
                      Icons.account_balance_wallet_outlined,
                      prefs.wallet,
                    ),
                  ])
                    SwitchListTile(
                      key: ValueKey('notification-${setting.$1}'),
                      secondary: Icon(setting.$4, color: teal),
                      title: Text(
                        setting.$2,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        setting.$3,
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                      value: setting.$5,
                      onChanged: saving
                          ? null
                          : (value) => change(setting.$1, value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Panel(
              padding: 4,
              color: canvas,
              child: SwitchListTile(
                key: const ValueKey('notification-Sound'),
                secondary: const Icon(Icons.volume_up_outlined, color: teal),
                title: const Text(
                  'Notification sound',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Play a short Errandly chime.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
                value: prefs.sound,
                onChanged: saving ? null : (value) => change('Sound', value),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'These settings control badges and alerts while Errandly is open. Your notification history stays available. Background push notifications are not connected yet.',
              style: TextStyle(fontSize: 11, color: muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                final enabled = prefs.errands || prefs.messages || prefs.wallet;
                toast(
                  context,
                  enabled
                      ? 'Preview: You have a new Errandly update.'
                      : 'All notification categories are muted.',
                );
                if (enabled && prefs.sound) {
                  unawaited(tone.play());
                }
              },
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Preview notification'),
            ),
            TextButton.icon(
              onPressed: () => openGuide(context),
              icon: const Icon(Icons.help_outline),
              label: const Text('How Errandly works'),
            ),
            if (saving)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      );
    },
  );
}
