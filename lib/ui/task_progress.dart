import 'package:flutter/material.dart';

import '../models/entities.dart';
import 'components.dart';

class TaskProgress extends StatelessWidget {
  const TaskProgress({super.key, required this.errand});
  final Errand errand;

  @override
  Widget build(BuildContext context) {
    final e = errand;
    final current = switch (e.progress) {
      < 0 => -1,
      0 => 0,
      1 || 2 => 1,
      3 || 4 => 2,
      5 => 3,
      6 => 4,
      _ => 5,
    };
    const labels = [
      'Accepted',
      'Pickup',
      'Delivery',
      'Handoff',
      'Confirm',
      'Done',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: e.progress < 0
              ? 'Not started'
              : progressLabels[e.progress.clamp(0, 7)],
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 5 ? 4 : 0),
                    child: Column(
                      children: [
                        Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: i <= current
                                ? teal
                                : const Color(0xFFDBE5DE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[i],
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: i == current
                                ? FontWeight.w800
                                : FontWeight.w400,
                            color: i <= current ? teal : muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          e.status == ErrandStatus.waiting
              ? 'Awaiting requester confirmation'
              : e.progress < 0
              ? 'Waiting for a runner'
              : progressLabels[e.progress.clamp(0, 7)],
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: teal,
          ),
        ),
      ],
    );
  }
}
