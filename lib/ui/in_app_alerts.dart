import 'dart:async';

import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../state/errand_store.dart';
import 'account.dart';
import 'components.dart';
import 'notification_tone.dart';

class InAppAlerts extends StatefulWidget {
  const InAppAlerts({super.key, required this.store, required this.child});
  final ErrandStore store;
  final Widget child;
  @override
  State<InAppAlerts> createState() => _InAppAlertsState();
}

class _InAppAlertsState extends State<InAppAlerts> {
  final tone = NotificationTone();
  String? account;
  Set<String> seen = {};
  String keyFor(Notice n) =>
      n.id ?? '${n.date.microsecondsSinceEpoch}:${n.type}:${n.text}';
  @override
  void initState() {
    super.initState();
    baseline();
    widget.store.addListener(changed);
  }

  void baseline() {
    account = widget.store.currentId;
    seen = widget.store.notifications
        .where((n) => n.userId == account)
        .map(keyFor)
        .toSet();
  }

  @override
  void didUpdateWidget(covariant InAppAlerts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(changed);
      baseline();
      widget.store.addListener(changed);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(changed);
    unawaited(tone.dispose());
    super.dispose();
  }

  void changed() {
    final s = widget.store;
    if (account != s.currentId || account == null) {
      if (account != s.currentId) {
        ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      }
      baseline();
      return;
    }
    final list = s.notifications.where((n) => n.userId == account).toList();
    final prefs = s.preferences.forAccount(account);
    final fresh = list
        .where(
          (n) => !seen.contains(keyFor(n)) && !n.read && prefs.allows(n.type),
        )
        .toList();
    seen = list.map(keyFor).toSet();
    if (fresh.isEmpty) return;
    final user = account;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || s.currentId != user) return;
      final now = s.preferences.forAccount(user);
      if (!now.allows(fresh.first.type)) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${fresh.first.type} · ${fresh.first.text}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Inbox',
            onPressed: () => sheet(context, NotificationsSheet(store: s)),
          ),
        ),
      );
      if (now.sound) unawaited(tone.play());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
