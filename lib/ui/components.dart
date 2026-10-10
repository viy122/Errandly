import 'dart:async';

import 'package:flutter/material.dart';

import '../models/entities.dart';

const teal = Color(0xFF007A58);
const forest = Color(0xFF073F31);
const lime = Color(0xFFDDF477);
const ink = Color(0xFF111817);
const muted = Color(0xFF52615B);
const canvas = Color(0xFFEEF2EF);
const pale = Color(0xFFD5E9DC);
const line = Color(0xFFA3B6A9);
const amber = Color(0xFFF2B544);

void toast(BuildContext context, String text) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}

Future<bool> attempt(
  BuildContext context,
  FutureOr<void> Function() action, [
  String? success,
]) async {
  try {
    await action();
    if (!context.mounted) return true;
    if (success != null) toast(context, success);
    return true;
  } on StateError catch (e) {
    if (context.mounted) toast(context, e.message);
    return false;
  }
}

Future<T?> sheet<T>(BuildContext context, Widget child) {
  if (MediaQuery.sizeOf(context).width < 650) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboard),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (MediaQuery.sizeOf(context).height * .88 - keyboard)
                    .clamp(100.0, 850.0),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 850),
        child: child,
      ),
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.light = false, this.size = 64});
  final bool light;
  final double size;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size,
        height: size,
        decoration: light
            ? BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Image.asset(
          'assets/brand/errandly-symbol.png',
          excludeFromSemantics: true,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        'errandly',
        style: TextStyle(
          color: light ? Colors.white : ink,
          fontSize: size * .32,
          fontWeight: FontWeight.w800,
          letterSpacing: -.5,
        ),
      ),
    ],
  );
}

class Avatar extends StatelessWidget {
  const Avatar(this.user, {super.key, this.size = 40});
  final UserProfile user;
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = [ink, teal, lime, amber];
    final index = user.id.codeUnits.fold(0, (a, b) => a + b) % 4;
    final foreground = index < 2 ? Colors.white : ink;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: colors[index],
      child: user.photo
          ? Icon(Icons.face_rounded, color: foreground, size: size * .6)
          : Text(
              user.initials,
              style: TextStyle(
                fontSize: size * .3,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = 22,
    this.color = Colors.white,
  });
  final Widget child;
  final double padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10111817),
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = teal, this.icon});
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color == teal ? teal : color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color == teal ? Colors.white : color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color == teal ? Colors.white : color,
              letterSpacing: .3,
            ),
          ),
        ),
      ],
    ),
  );
}

class DetailGrid extends StatelessWidget {
  const DetailGrid({super.key, required this.items});
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Container(
            width: (box.maxWidth - 8) / 2,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: canvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  item.$2,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, this.subtitle, {super.key, this.trailing});
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 13),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class Empty extends StatelessWidget {
  const Empty(
    this.title,
    this.description, {
    super.key,
    this.icon = Icons.inbox_outlined,
  });
  final String title, description;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Panel(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(icon, size: 42, color: teal),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget field(
  String label,
  TextEditingController controller, {
  int lines = 1,
  bool password = false,
  TextInputType? type,
  String? hint,
  String? Function(String?)? validator,
  ValueChanged<String>? onChanged,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: TextFormField(
    controller: controller,
    maxLines: lines,
    obscureText: password,
    keyboardType: type,
    onChanged: onChanged,
    validator:
        validator ??
        (v) => v == null || v.trim().isEmpty ? 'Please enter $label' : null,
    decoration: InputDecoration(labelText: label, hintText: hint),
  ),
);
Widget select(
  String label,
  String value,
  List<String> values,
  ValueChanged<String?> changed,
) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    items: values
        .map(
          (v) => DropdownMenuItem(
            value: v,
            child: Text(v, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: changed,
    decoration: InputDecoration(labelText: label),
  ),
);
Widget infoRow(String label, String value, {bool strong = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 7),
  child: Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: muted, fontSize: 13)),
      ),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            color: strong ? teal : ink,
          ),
        ),
      ),
    ],
  ),
);
Widget note(String text, {IconData icon = Icons.shield_outlined}) => Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: pale,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: teal.withValues(alpha: .22)),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: teal),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: teal, fontSize: 12, height: 1.5),
        ),
      ),
    ],
  ),
);
IconData categoryIcon(String category) => switch (category) {
  'Printing' => Icons.print_outlined,
  'Food' => Icons.restaurant_outlined,
  'Delivery' => Icons.local_shipping_outlined,
  'Pickup' => Icons.inventory_2_outlined,
  'Document Submission' => Icons.description_outlined,
  'Queueing' => Icons.schedule_outlined,
  'School Supplies' => Icons.edit_note_rounded,
  'Purchase' => Icons.shopping_bag_outlined,
  _ => Icons.grid_view_rounded,
};

class NeighborhoodArt extends StatelessWidget {
  const NeighborhoodArt({super.key});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _NeighborhoodPainter(), size: const Size(350, 200));
}

class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Refreshing errands',
    child: Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LinearProgressIndicator(color: teal, backgroundColor: pale),
          const SizedBox(height: 22),
          for (final width in [170.0, 250.0, 210.0])
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: width,
                height: 16,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: pale,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          const SizedBox(height: 60),
        ],
      ),
    ),
  );
}

class _NeighborhoodPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 350, size.height / 200);
    final p = Paint();
    void rect(
      double x,
      double y,
      double w,
      double h,
      Color color,
      double radius,
    ) {
      p.color = color;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(radius),
        ),
        p,
      );
    }

    p.color = const Color(0xFFB7D4BC);
    c.drawCircle(const Offset(195, 106), 87, p);
    p.color = const Color(0xFFD9E7C2);
    c.drawCircle(const Offset(295, 30), 14, p);
    rect(68, 157, 250, 9, const Color(0xFF85AE95), 4);
    rect(127, 86, 154, 72, const Color(0xFFF6EFD9), 3);
    final roof = Path()
      ..moveTo(113, 89)
      ..lineTo(204, 43)
      ..lineTo(296, 89)
      ..close();
    p.color = const Color(0xFF467B60);
    c.drawPath(roof, p);
    rect(137, 92, 134, 8, const Color(0xFFE0D7B8), 0);
    for (final x in [144.0, 178.0, 212.0, 246.0]) {
      rect(x, 103, 13, 48, const Color(0xFFFFFFFF), 1);
      rect(x - 3, 148, 19, 6, const Color(0xFFE2D9BE), 1);
    }
    rect(195, 116, 19, 42, const Color(0xFF719782), 4);
    rect(120, 158, 169, 7, const Color(0xFFE4DDCA), 2);
    p.color = const Color(0xFF467B60);
    c.drawCircle(const Offset(90, 122), 26, p);
    c.drawCircle(const Offset(303, 134), 20, p);
    rect(88, 130, 5, 29, const Color(0xFF6F7860), 1);
    rect(301, 140, 4, 20, const Color(0xFF6F7860), 1);
    rect(35, 76, 67, 38, Colors.white, 10);
    p.color = teal;
    c.drawCircle(const Offset(51, 94), 8, p);
    rect(65, 87, 27, 4, const Color(0xFF719782), 2);
    rect(65, 96, 19, 3, const Color(0xFFC1D0C0), 2);
    rect(260, 96, 61, 35, const Color(0xFFFFE7AB), 9);
    p.color = teal;
    c.drawCircle(const Offset(274, 113), 7, p);
    rect(286, 107, 25, 4, teal, 2);
    rect(286, 116, 18, 3, const Color(0xFFB5A773), 2);
    p.color = const Color(0xFFEABB63);
    c.drawCircle(const Offset(111, 42), 4, p);
    c.drawCircle(const Offset(321, 79), 3, p);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
