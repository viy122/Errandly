import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/wallet_rates.dart';
import '../state/errand_store.dart';
import 'components.dart';

class WalletTopUp extends StatefulWidget {
  const WalletTopUp({super.key, required this.store});
  final ErrandStore store;
  @override
  State<WalletTopUp> createState() => _WalletTopUpState();
}

class _WalletTopUpState extends State<WalletTopUp> {
  PageController pages = PageController(viewportFraction: .64);
  double pesos = 100;
  int selected = 0;
  bool review = false, paying = false, completed = false;
  String? error;
  DateTime? completedAt;
  double? receiptBalance;
  static const methods = ['GCash Simulation', 'Card Simulation'];
  static const labels = ['GCash', 'Debit / Credit Card'];
  double get coins => WalletRates.coinsForTopUp(pesos);
  String get coinsLabel => '${money(coins)} CY';

  @override
  void dispose() {
    pages.dispose();
    super.dispose();
  }

  Future<void> pay() async {
    if (paying || completed) return;
    setState(() {
      paying = true;
      error = null;
    });
    try {
      await widget.store.topUp(pesos, method: methods[selected]);
      if (!mounted) return;
      setState(() {
        completed = true;
        completedAt = DateTime.now();
        receiptBalance = widget.store.wallet.available;
      });
    } on StateError catch (e) {
      if (mounted) setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => paying = false);
    }
  }

  void choose(int index) {
    if (selected == index) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      pages.jumpToPage(index);
    } else {
      pages.animateToPage(
        index,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void edit() => setState(() {
    pages.dispose();
    pages = PageController(initialPage: selected, viewportFraction: .64);
    review = false;
    error = null;
  });

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return PrintedTopUpReceipt(
        pesos: pesos,
        coins: coins,
        method: labels[selected],
        balance: receiptBalance!,
        date: completedAt!,
      );
    }
    return PopScope(
      canPop: !paying,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Close top up',
                      onPressed: paying ? null : () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        review ? 'Confirm top up' : 'Top up',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 48,
                      child: Icon(Icons.bolt_rounded, color: teal),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!review) ...[
                  Text(
                    labels[selected],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Choose how you’d like to pay',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 290,
                    child: PageView.builder(
                      controller: pages,
                      itemCount: methods.length,
                      onPageChanged: (index) =>
                          setState(() => selected = index),
                      itemBuilder: (context, index) => AnimatedBuilder(
                        animation: pages,
                        child: PaymentChoiceCard(
                          index: index,
                          selected: selected == index,
                          onTap: () => choose(index),
                        ),
                        builder: (context, child) {
                          final page =
                              pages.hasClients &&
                                  pages.position.hasContentDimensions
                              ? pages.page ?? selected.toDouble()
                              : selected.toDouble();
                          final distance = (page - index).clamp(-1.0, 1.0);
                          final reduceMotion = MediaQuery.disableAnimationsOf(
                            context,
                          );
                          final matrix = Matrix4.identity()
                            ..setEntry(3, 2, .0018);
                          if (!reduceMotion) matrix.rotateY(distance * .55);
                          return Transform.translate(
                            offset: Offset(0, distance.abs() * 15),
                            child: Transform(
                              alignment: Alignment.center,
                              transform: matrix,
                              child: Transform.scale(
                                scale: 1 - distance.abs() * .14,
                                child: child,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var index = 0; index < methods.length; index++)
                        Semantics(
                          selected: selected == index,
                          child: TextButton(
                            onPressed: () => choose(index),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: selected == index ? 16 : 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: selected == index
                                        ? ink
                                        : const Color(0xFFD5D9D6),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  index == 0 ? 'GCash' : 'Card',
                                  style: TextStyle(
                                    color: selected == index ? ink : muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final amount in [50.0, 100.0, 200.0, 500.0])
                        ChoiceChip(
                          label: Text('₱${money(amount)}'),
                          selected: pesos == amount,
                          onSelected: (_) => setState(() => pesos = amount),
                          selectedColor: pale,
                        ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Review your top up.',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check the details before confirming.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 172,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.58,
                        child: PaymentChoiceCard(
                          index: selected,
                          selected: true,
                          onTap: () {},
                          landscape: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                const SizedBox(height: 16),
                Panel(
                  color: const Color(0xFFF8F9F6),
                  padding: 14,
                  child: Column(
                    children: [
                      infoRow('You pay in pesos', '₱${money(pesos)}'),
                      infoRow(
                        'Coins added to wallet',
                        coinsLabel,
                        strong: true,
                      ),
                      if (review) infoRow('Payment method', labels[selected]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Simulated payment only. No real money will be charged.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 10, height: 1.5),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: paying
                      ? null
                      : review
                      ? pay
                      : () => setState(() => review = true),
                  child: paying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          review
                              ? 'Confirm simulated top up'
                              : 'Continue with ${labels[selected]}',
                        ),
                ),
                TextButton(
                  onPressed: paying
                      ? null
                      : review
                      ? edit
                      : () => Navigator.pop(context),
                  child: Text(review ? 'Edit top up' : 'Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PaymentChoiceCard extends StatelessWidget {
  const PaymentChoiceCard({
    super.key,
    required this.index,
    required this.selected,
    required this.onTap,
    this.landscape = false,
  });
  final int index;
  final bool selected, landscape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gcash = index == 0;
    final foreground = gcash ? Colors.white : const Color(0xFF303833);
    final face = Material(
      color: gcash ? const Color(0xFF155ECD) : const Color(0xFFBFC5C3),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0, .25, .48, .7, 1],
              colors: gcash
                  ? const [
                      Color(0xFF91BDF0),
                      Color(0xFF397DDE),
                      Color(0xFF155CC5),
                      Color(0xFF347ADC),
                      Color(0xFF1257B3),
                    ]
                  : const [
                      Color(0xFFEBEFEC),
                      Color(0xFFB5BCB8),
                      Color(0xFFD0D6D2),
                      Color(0xFFE7EBE8),
                      Color(0xFFADB6B0),
                    ],
            ),
          ),
          child: CustomPaint(
            painter: _BrushedCard(),
            child: Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 18,
                  child: Text(
                    'errandly',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .5,
                    ),
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 16,
                  child: Icon(
                    Icons.contactless_outlined,
                    color: foreground.withValues(alpha: .7),
                    size: 24,
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 58,
                  child: Container(
                    width: 30,
                    height: 23,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDACA95),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFB3A474)),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: Color(0xFF8D825C),
                      size: 19,
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  bottom: 18,
                  child: Text(
                    'SIMULATION',
                    style: TextStyle(
                      color: foreground.withValues(alpha: .6),
                      fontSize: 8,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 14,
                  child: Text(
                    gcash ? 'GCash' : 'CARD',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      fontStyle: gcash ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: gcash ? 'GCash payment' : 'Debit or credit card payment',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: AspectRatio(
            aspectRatio: landscape ? 1.58 : 1 / 1.58,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x28000000),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: landscape
                  ? face
                  : RotatedBox(quarterTurns: 1, child: face),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrushedCard extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .035)
      ..strokeWidth = .6;
    for (double y = 1; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 7), paint);
    }
  }

  @override
  bool shouldRepaint(_BrushedCard oldDelegate) => false;
}

class PrintedTopUpReceipt extends StatefulWidget {
  const PrintedTopUpReceipt({
    super.key,
    required this.pesos,
    required this.coins,
    required this.method,
    required this.balance,
    required this.date,
  });
  final double pesos, coins, balance;
  final String method;
  final DateTime date;
  @override
  State<PrintedTopUpReceipt> createState() => _PrintedTopUpReceiptState();
}

class _PrintedTopUpReceiptState extends State<PrintedTopUpReceipt>
    with SingleTickerProviderStateMixin {
  late final AnimationController printer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  late final CurvedAnimation paper = CurvedAnimation(
    parent: printer,
    curve: Curves.easeInOutCubic,
  );
  bool get reducedMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion) {
      printer.value = 1;
    } else if (printer.status == AnimationStatus.dismissed) {
      printer.forward();
    }
  }

  void printAgain() {
    if (reducedMotion) {
      printer.value = 1;
    } else {
      printer.forward(from: 0);
    }
  }

  @override
  void dispose() {
    paper.dispose();
    printer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.date;
    final stamp =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return LayoutBuilder(
      builder: (context, screen) => ColoredBox(
        color: const Color(0xFF141513),
        child: SizedBox.expand(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, screen.maxHeight - 40),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Back to wallet',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Receipt',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Top up complete',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 46),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 290),
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final width = box.maxWidth - 36;
                            final receipt = ClipPath(
                              clipper: _ReceiptEdge(),
                              child: Container(
                                key: const ValueKey('printed-paper'),
                                width: width,
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  25,
                                  18,
                                  23,
                                ),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFEEEEEB),
                                      Color(0xFFFFFEF7),
                                      Color(0xFFEDECE5),
                                    ],
                                  ),
                                ),
                                child: DefaultTextStyle(
                                  style: const TextStyle(
                                    color: Color(0xFF30342D),
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'E R R A N D L Y',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'WALLET TOP-UP RECEIPT',
                                        style: TextStyle(
                                          fontSize: 8,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      const Text(
                                        'SIMULATED RECEIPT',
                                        style: TextStyle(
                                          fontSize: 7,
                                          color: muted,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      _receiptRow('DATE', stamp),
                                      _receiptRow('METHOD', widget.method),
                                      const _Perforation(),
                                      _receiptRow(
                                        'Amount paid',
                                        '₱${money(widget.pesos)}',
                                      ),
                                      _receiptRow(
                                        'Coins added',
                                        '${money(widget.coins)} CY',
                                      ),
                                      _receiptRow(
                                        'Wallet balance',
                                        '${money(widget.balance)} CY',
                                      ),
                                      const _Perforation(),
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            child: _receiptRow(
                                              'TOTAL',
                                              '₱${money(widget.pesos)}',
                                              strong: true,
                                            ),
                                          ),
                                          Transform.rotate(
                                            angle: -.18,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 7,
                                                  ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: teal.withValues(
                                                    alpha: .6,
                                                  ),
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Text(
                                                'COMPLETE',
                                                style: TextStyle(
                                                  color: teal,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      const SizedBox(
                                        height: 31,
                                        width: double.infinity,
                                        child: ExcludeSemantics(
                                          child: CustomPaint(
                                            painter: _DecorativeBarcode(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'TOP-UP COMPLETE',
                                        style: TextStyle(
                                          fontSize: 7,
                                          letterSpacing: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 15),
                                      const Text(
                                        'Thank you for choosing Errandly.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'serif',
                                          fontStyle: FontStyle.italic,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                            return Column(
                              children: [
                                Container(
                                  height: 43,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: [0, .32, .58, 1],
                                      colors: [
                                        Color(0xFFF1F3ED),
                                        Color(0xFFD4D9D1),
                                        Color(0xFFB9C0B7),
                                        Color(0xFFE5E8E1),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFB4BAB1),
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black54,
                                        blurRadius: 18,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      const Positioned(
                                        left: 15,
                                        top: 6,
                                        child: Text(
                                          'ERRANDLY',
                                          style: TextStyle(
                                            color: Color(0xFF90968D),
                                            fontSize: 6,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 16,
                                        right: 16,
                                        bottom: 8,
                                        child: Container(
                                          height: 9,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF343A32),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFF8D958A),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Positioned(
                                        right: 11,
                                        top: 9,
                                        child: Icon(
                                          Icons.circle,
                                          size: 4,
                                          color: teal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Transform.translate(
                                  offset: const Offset(0, -9),
                                  child: AnimatedBuilder(
                                    animation: paper,
                                    child: receipt,
                                    builder: (context, child) => ClipRect(
                                      child: FractionalTranslation(
                                        key: const ValueKey('receipt-feed'),
                                        translation: Offset(0, paper.value - 1),
                                        child: DecoratedBox(
                                          decoration: const BoxDecoration(
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black45,
                                                blurRadius: 14,
                                                offset: Offset(5, 8),
                                              ),
                                            ],
                                          ),
                                          child: child,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 34),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 290),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(
                                  color: Color(0xFF353931),
                                ),
                              ),
                              onPressed: printAgain,
                              icon: const Icon(Icons.print_outlined, size: 15),
                              label: const Text('Print again'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF5F5F0),
                                foregroundColor: ink,
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Done'),
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
        ),
      ),
    );
  }
}

Widget _receiptRow(String label, String value, {bool strong = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
                fontSize: strong ? 13 : 9,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            fit: FlexFit.tight,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
                fontSize: strong ? 13 : 9,
              ),
            ),
          ),
        ],
      ),
    );

class _Perforation extends StatelessWidget {
  const _Perforation();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashedRule()),
    ),
  );
}

class _DashedRule extends CustomPainter {
  const _DashedRule();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF90958B)
      ..strokeWidth = .6;
    for (double x = 0; x < size.width; x += 5) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + 3, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRule oldDelegate) => false;
}

class _DecorativeBarcode extends CustomPainter {
  const _DecorativeBarcode();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF30342D);
    final unit = size.width / 109;
    double x = 0;
    for (var i = 0; i < 44; i++) {
      final width = i % 3 == 0 ? 2 * unit : unit;
      canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
      x += width + (i % 4 == 0 ? 2 * unit : unit);
    }
  }

  @override
  bool shouldRepaint(_DecorativeBarcode oldDelegate) => false;
}

class _ReceiptEdge extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 4);
    final teeth = (size.width / 6).round().clamp(1, 200);
    final toothWidth = size.width / teeth;
    for (var i = teeth; i > 0; i--) {
      path
        ..lineTo((i - .5) * toothWidth, size.height)
        ..lineTo((i - 1) * toothWidth, size.height - 4);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_ReceiptEdge oldClipper) => false;
}
