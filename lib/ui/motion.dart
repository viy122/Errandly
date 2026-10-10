import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'components.dart';

class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
      end: 1,
    ),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 22),
        child: child,
      ),
    ),
    child: child,
  );
}

class AsyncActionButton extends StatefulWidget {
  const AsyncActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loadingLabel = 'Saving…',
    this.enabled = true,
  });
  final String label, loadingLabel;
  final Future<void> Function() onPressed;
  final bool enabled;
  @override
  State<AsyncActionButton> createState() => _AsyncActionButtonState();
}

class _AsyncActionButtonState extends State<AsyncActionButton> {
  bool working = false;
  Future<void> run() async {
    if (working) return;
    setState(() => working = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: working || !widget.enabled ? null : run,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: working
          ? Row(
              key: const ValueKey('working'),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Text(widget.loadingLabel),
              ],
            )
          : Text(widget.label, key: const ValueKey('ready')),
    ),
  );
}

class ErrandIllustration extends StatelessWidget {
  const ErrandIllustration({super.key, this.height = 155});
  final double height;
  @override
  Widget build(BuildContext context) => Entrance(
    child: Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [pale, Color(0xFFD6EADF)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -25,
            top: -55,
            child: Container(
              width: 185,
              height: 185,
              decoration: const BoxDecoration(
                color: Color(0xFFF3D999),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -15,
            bottom: -55,
            child: Container(
              width: 180,
              height: 180,
              decoration: const BoxDecoration(
                color: Color(0xFFC3DFD0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _tile(Icons.shopping_bag_outlined, 'Request'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(Icons.more_horiz, color: teal, size: 28),
              ),
              Transform.rotate(
                angle: -.05,
                child: _tile(Icons.directions_run, 'Deliver'),
              ),
            ],
          ),
          const Positioned(
            right: 15,
            bottom: 12,
            child: Tag('A LITTLE HELP', icon: Icons.favorite_outline),
          ),
        ],
      ),
    ),
  );
  Widget _tile(IconData icon, String label) => Container(
    width: 82,
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14006A50),
          blurRadius: 14,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: teal),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class SuccessMark extends StatelessWidget {
  const SuccessMark({super.key, this.pending = false});
  final bool pending;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
      end: 1,
    ),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 650),
    curve: Curves.easeOutBack,
    builder: (_, value, child) =>
        Transform.scale(scale: math.max(.01, value), child: child),
    child: Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: pending ? const Color(0xFFFFF1D4) : pale,
        shape: BoxShape.circle,
      ),
      child: Icon(
        pending ? Icons.verified_user_outlined : Icons.check_rounded,
        size: 43,
        color: pending ? const Color(0xFF8B651B) : teal,
      ),
    ),
  );
}

class SuccessFeedback extends StatelessWidget {
  const SuccessFeedback({
    super.key,
    required this.title,
    required this.message,
    this.pending = false,
  });
  final String title, message;
  final bool pending;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: SuccessMark(pending: pending)),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: muted, height: 1.6),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
