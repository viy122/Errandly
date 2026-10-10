import 'package:flutter/material.dart';

import '../state/errand_store.dart';
import 'components.dart';

/// Switches the two sides of the demo without replacing their session data.
class DemoAccountToggle extends StatelessWidget {
  const DemoAccountToggle({
    super.key,
    required this.store,
    this.compact = false,
  });

  final ErrandStore store;
  final bool compact;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      if (!store.isDemoAccount) return const SizedBox.shrink();
      if (compact) {
        return Row(
          children: [
            const Text(
              'Demo account',
              style: TextStyle(fontSize: 10, color: muted),
            ),
            const Spacer(),
            for (final id in ['anna', 'ben'])
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Semantics(
                  selected: store.currentId == id,
                  child: TextButton(
                    key: ValueKey('demo-account-$id'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(58, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      backgroundColor: store.currentId == id
                          ? pale
                          : Colors.transparent,
                      foregroundColor: ink,
                      disabledForegroundColor: ink,
                      side: BorderSide(
                        color: store.currentId == id ? teal : line,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    onPressed: store.currentId == id || store.busy
                        ? null
                        : () => store.quietly(() => store.demo(id)),
                    child: Text(
                      store.users[id]!.firstName,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
          ],
        );
      }
      final buttons = Row(
        children: [
          accountButton('anna', 'Requester', Icons.add_task_outlined),
          const SizedBox(width: 8),
          accountButton('ben', 'Runner', Icons.directions_run_rounded),
        ],
      );
      const label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz_rounded, size: 17, color: teal),
          SizedBox(width: 6),
          Text('Demo accounts', style: TextStyle(fontSize: 11, color: muted)),
        ],
      );
      return LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 620
            ? Row(
                children: [
                  label,
                  const SizedBox(width: 24),
                  SizedBox(width: 360, child: buttons),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [label, const SizedBox(height: 7), buttons],
              ),
      );
    },
  );

  Widget accountButton(String id, String role, IconData icon) {
    final selected = store.currentId == id;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: selected
            ? '${store.users[id]!.firstName}, current demo account'
            : 'Switch to ${store.users[id]!.firstName}, $role demo',
        child: Material(
          color: selected ? teal : canvas,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: ValueKey('demo-account-$id'),
            borderRadius: BorderRadius.circular(10),
            onTap: selected || store.busy
                ? null
                : () => store.quietly(() => store.demo(id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: selected ? Colors.white : teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.users[id]!.firstName,
                          style: TextStyle(
                            color: selected ? Colors.white : ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selected ? 'Current account' : '$role demo',
                          style: TextStyle(
                            color: selected
                                ? Colors.white.withValues(alpha: .8)
                                : muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.white,
                      size: 15,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
