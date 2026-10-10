import 'dart:async';

import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../models/wallet_rates.dart';
import '../state/errand_store.dart';
import 'components.dart';
import 'motion.dart';
import '../models/geo.dart';
import 'map_point_picker.dart';
import 'errand_map.dart';
import 'payment_choices.dart';

class PostForm extends StatefulWidget {
  const PostForm({super.key, required this.store, required this.onPublished});
  final ErrandStore store;
  final VoidCallback onPublished;
  @override
  State<PostForm> createState() => _PostFormState();
}

class _PostFormState extends State<PostForm> {
  Timer? _draftTimer;
  bool _edited = false,
      _restoring = false,
      _published = false,
      _publishing = false;
  String? _draftMessage;
  late final String _draftOwner;
  String _postId = 'e${DateTime.now().microsecondsSinceEpoch}';
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      description = TextEditingController(),
      instructions = TextEditingController(),
      pickup = TextEditingController(),
      destination = TextEditingController(),
      area = TextEditingController(),
      distance = TextEditingController(text: '5'),
      budget = TextEditingController(text: '50'),
      fee = TextEditingController(text: '40');
  int step = 0;
  String category = 'Purchase',
      deadline = 'In 4 hours',
      transport = 'Motorcycle',
      payment = 'Errandly Wallet';
  String budgetPayment = 'GCash Simulation';
  DateTime deadlineAt = DateTime.now().add(const Duration(hours: 4));
  bool urgent = false;
  GeoPoint? pickupPoint, destinationPoint;
  String distanceSource = 'manual';
  double? routeSeconds;
  List<GeoPoint> routeLine = [];
  bool routeWorking = false;
  String? routeError;
  int routeVersion = 0;
  List<TextEditingController> get _controllers => [
    title,
    description,
    instructions,
    pickup,
    destination,
    area,
    distance,
    budget,
    fee,
  ];
  Map<String, dynamic> get _snapshot => {
    'postId': _postId,
    'fields': _controllers.map((c) => c.text).toList(),
    'step': step,
    'category': category,
    'deadline': deadline,
    'deadlineAt': deadlineAt.toIso8601String(),
    'transport': transport,
    'payment': payment,
    'budgetPayment': budgetPayment,
    'urgent': urgent,
    'pickupPoint': pickupPoint?.toJson(),
    'destinationPoint': destinationPoint?.toJson(),
    'distanceSource': distanceSource,
    'routeSeconds': routeSeconds,
    'routeLine': routeLine.map((p) => p.toJson()).toList(),
    'preferredRunnerId': widget.store.preferredRunnerId,
  };
  @override
  void initState() {
    super.initState();
    _draftOwner = widget.store.currentId!;
    for (final c in _controllers) {
      c.addListener(_changed);
    }
    unawaited(_restoreDraft());
  }

  Future<void> _restoreDraft() async {
    await widget.store.preferences.load();
    if (!mounted || _edited || _published) return;
    final data = widget.store.preferences.draftFor(_draftOwner);
    if (data == null) return;
    _restoring = true;
    final fields = data['fields'];
    if (fields is List && fields.length == _controllers.length) {
      for (var i = 0; i < fields.length; i++) {
        _controllers[i].text = fields[i].toString();
      }
    }
    _postId = data['postId'] as String? ?? _postId;
    step = ((data['step'] as int?) ?? 0).clamp(0, 2);
    category = categories.contains(data['category'])
        ? data['category']
        : 'Purchase';
    transport = travelMethods.contains(data['transport'])
        ? data['transport']
        : 'Motorcycle';
    deadline = data['deadline'] as String? ?? 'In 4 hours';
    deadlineAt = DateTime.tryParse(data['deadlineAt'] ?? '') ?? deadlineAt;
    budgetPayment = data['budgetPayment'] as String? ?? budgetPayment;
    urgent = data['urgent'] == true;
    pickupPoint = GeoPoint.parse(data['pickupPoint']);
    destinationPoint = GeoPoint.parse(data['destinationPoint']);
    distanceSource = data['distanceSource'] as String? ?? 'manual';
    routeSeconds = (data['routeSeconds'] as num?)?.toDouble();
    routeLine = (data['routeLine'] as List? ?? [])
        .map((p) => GeoPoint.parse(p)!)
        .toList();
    final preferred = data['preferredRunnerId'];
    if (preferred is String && widget.store.users.containsKey(preferred)) {
      widget.store.preferredRunnerId = preferred;
    }
    _restoring = false;
    setState(() => _draftMessage = 'Your saved draft has been restored.');
  }

  void _changed() {
    if (_restoring || _published) return;
    _edited = true;
    _draftTimer?.cancel();
    final snapshot = _snapshot;
    _draftTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_saveDraft(snapshot)),
    );
  }

  Future<void> _saveDraft(Map<String, dynamic> data) async {
    try {
      await widget.store.preferences.saveDraft(_draftOwner, data);
      if (mounted && !_published) {
        setState(() => _draftMessage = 'Draft saved on this device.');
      }
    } on StateError {
      if (mounted) {
        setState(
          () => _draftMessage =
              'Could not save this draft on your device. Keep this form open.',
        );
      }
    }
  }

  Future<void> _discardDraft() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this draft?'),
        content: const Text(
          'This clears the current form. Published errands are unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep draft'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard draft'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    _draftTimer?.cancel();
    _restoring = true;
    for (final c in _controllers) {
      c.clear();
    }
    distance.text = '5';
    budget.text = '50';
    fee.text = '40';
    step = 0;
    category = 'Purchase';
    transport = 'Motorcycle';
    urgent = false;
    pickupPoint = null;
    destinationPoint = null;
    distanceSource = 'manual';
    routeSeconds = null;
    routeLine = [];
    routeVersion++;
    deadline = 'In 4 hours';
    deadlineAt = DateTime.now().add(const Duration(hours: 4));
    budgetPayment = 'GCash Simulation';
    payment = 'Errandly Wallet';
    widget.store.preferredRunnerId = null;
    _postId = 'e${DateTime.now().microsecondsSinceEpoch}';
    _restoring = false;
    _edited = false;
    try {
      await widget.store.preferences.saveDraft(_draftOwner, null);
    } on StateError {
      /* Fields are still cleared for this session. */
    }
    if (mounted) setState(() => _draftMessage = null);
  }

  double parsedAmount(String text) {
    final value = double.tryParse(text);
    return value != null && value.isFinite && value >= 0 ? value : 0;
  }

  double get total => parsedAmount(fee.text) + 5;
  @override
  void dispose() {
    _draftTimer?.cancel();
    if (_edited && !_published) unawaited(_saveDraft(_snapshot));
    for (final c in [
      title,
      description,
      instructions,
      budget,
      fee,
      pickup,
      destination,
      area,
      distance,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void next() {
    if (routeWorking) return;
    if (!form.currentState!.validate()) {
      return;
    }
    if (!deadlineAt.isAfter(DateTime.now())) {
      toast(context, 'Choose a future deadline.');
      return;
    }
    setState(() => step++);
    _changed();
  }

  Future<void> publish() async {
    if (routeWorking ||
        _publishing ||
        _published ||
        widget.store.currentId != _draftOwner) {
      return;
    }
    if (!deadlineAt.isAfter(DateTime.now())) {
      setState(() => step = 0);
      toast(
        context,
        'This draft deadline has passed. Choose a future deadline.',
      );
      return;
    }
    _publishing = true;
    _draftTimer?.cancel();
    await _saveDraft(_snapshot);
    if (!mounted || widget.store.currentId != _draftOwner) {
      _publishing = false;
      return;
    }
    final e = Errand(
      id: _postId,
      ownerId: widget.store.currentId!,
      title: title.text.trim(),
      category: category,
      description: description.text.trim(),
      pickup: pickup.text.trim(),
      destination: destination.text.trim(),
      area: area.text.trim(),
      transport: transport,
      budget: double.parse(budget.text),
      fee: double.parse(fee.text),
      distance: double.parse(distance.text) * 1000,
      pickupPoint: pickupPoint,
      destinationPoint: destinationPoint,
      distanceSource: distanceSource,
      routeSeconds: routeSeconds,
      deadline: deadlineAt,
      urgent: urgent,
      instructions: instructions.text.trim().isEmpty
          ? 'Message me on arrival, please.'
          : instructions.text.trim(),
    );
    if (await attempt(
      context,
      () => widget.store.post(e, payment, budgetMethod: budgetPayment),
      'Payment Secured. Your errand is published!',
    )) {
      _published = true;
      try {
        await widget.store.preferences.saveDraft(_draftOwner, null);
      } on StateError {
        /* The saved post ID prevents a retry from charging twice. */
      }
      if (mounted) widget.onPublished();
    }
    _publishing = false;
  }

  void invalidateRoute({bool clearDistance = true}) {
    routeVersion++;
    if (clearDistance && distanceSource == 'osrm_driving') distance.clear();
    distanceSource = 'manual';
    routeSeconds = null;
    routeLine = [];
    routeError = null;
  }

  Future<void> choosePin(bool isPickup) async {
    final place = await sheet<MapPlace>(
      context,
      MapPointPicker(
        services: widget.store.maps,
        title: isPickup ? 'Choose pickup pin' : 'Choose drop-off pin',
        initial: isPickup ? pickupPoint : destinationPoint,
        initialAddress: isPickup ? pickup.text : destination.text,
      ),
    );
    if (place == null || !mounted || widget.store.currentId != _draftOwner) {
      return;
    }
    setState(() {
      invalidateRoute();
      if (isPickup) {
        pickupPoint = place.point;
        pickup.text = place.label;
      } else {
        destinationPoint = place.point;
        destination.text = place.label;
      }
    });
    _changed();
  }

  Future<void> calculateRoute() async {
    if (routeWorking || pickupPoint == null || destinationPoint == null) return;
    final version = routeVersion;
    setState(() {
      routeWorking = true;
      routeError = null;
    });
    try {
      final route = await widget.store.maps.route(
        pickupPoint!,
        destinationPoint!,
      );
      if (!mounted ||
          version != routeVersion ||
          widget.store.currentId != _draftOwner) {
        return;
      }
      setState(() {
        distance.text = (route.meters / 1000).toStringAsFixed(6);
        distanceSource = 'osrm_driving';
        routeSeconds = route.seconds;
        routeLine = route.points;
      });
      _changed();
    } on StateError catch (e) {
      if (mounted && version == routeVersion) {
        setState(() => routeError = e.message);
      }
    } finally {
      if (mounted) setState(() => routeWorking = false);
    }
  }

  Future<void> chooseDeadline(String choice) async {
    if (choice == 'Choose date & time') {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: deadlineAt.isAfter(now) ? deadlineAt : now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 365)),
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(deadlineAt),
      );
      if (time == null || !mounted) return;
      final selected = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!selected.isAfter(DateTime.now())) {
        toast(context, 'Choose a future deadline.');
        return;
      }
      setState(() {
        deadline = choice;
        deadlineAt = selected;
      });
    } else {
      final minutes = {
        'In 30 minutes': 30,
        'In 1 hour': 60,
        'In 4 hours': 240,
        'Tomorrow': 1440,
        'In 3 days': 4320,
        'In 1 week': 10080,
      }[choice]!;
      setState(() {
        deadline = choice;
        deadlineAt = DateTime.now().add(Duration(minutes: minutes));
      });
    }
    _changed();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageTitle(
            'A little help starts here',
            'Tell the community what you need. We’ll take it from there.',
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _draftMessage ??
                      'Your draft is saved automatically on this device.',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ),
              TextButton(
                onPressed: _publishing ? null : _discardDraft,
                child: const Text(
                  'Discard draft',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: i <= step ? teal : pale,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: i <= step ? Colors.white : muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ['The errand', 'Your budget', 'Secure payment'][i],
                        style: TextStyle(
                          fontSize: 11,
                          color: i == step ? teal : muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          Panel(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    [
                      'What do you need?',
                      'Make it worth their while',
                      'All set? Let’s secure your payment.',
                    ][step],
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (step == 0) ...[
                    if (widget.store.preferredRunnerId != null) ...[
                      note(
                        '${widget.store.users[widget.store.preferredRunnerId]!.firstName} will receive an invitation when you publish. Your errand is also available to the community.',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                    ],
                    field('Errand title', title, hint: 'e.g. Buy 1 Yellow Pad'),
                    select('Category', category, categories.skip(1).toList(), (
                      v,
                    ) {
                      setState(() => category = v!);
                      _changed();
                    }),
                    field(
                      'Description',
                      description,
                      lines: 3,
                      hint: 'What should your runner know?',
                    ),
                    field(
                      'Pickup address',
                      pickup,
                      hint: 'Street, barangay, city / province',
                      lines: 2,
                      onChanged: (_) {
                        setState(() {
                          pickupPoint = null;
                          invalidateRoute();
                        });
                        _changed();
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: routeWorking ? null : () => choosePin(true),
                      icon: const Icon(Icons.place_outlined),
                      label: Text(
                        pickupPoint == null
                            ? 'Choose pickup on map'
                            : 'Change pickup pin',
                      ),
                    ),
                    const SizedBox(height: 12),
                    field(
                      'Delivery address',
                      destination,
                      hint: 'Any address, nearby or in another city',
                      lines: 2,
                      onChanged: (_) {
                        setState(() {
                          destinationPoint = null;
                          invalidateRoute();
                        });
                        _changed();
                      },
                    ),
                    OutlinedButton.icon(
                      onPressed: routeWorking ? null : () => choosePin(false),
                      icon: const Icon(Icons.place_outlined),
                      label: Text(
                        destinationPoint == null
                            ? 'Choose drop-off on map'
                            : 'Change drop-off pin',
                      ),
                    ),
                    const SizedBox(height: 12),
                    field(
                      'Listing area / city',
                      area,
                      hint: 'e.g. Metro Manila, Cebu City, or your town',
                    ),
                    field(
                      'Estimated distance (km)',
                      distance,
                      type: TextInputType.number,
                      onChanged: (_) {
                        setState(() => invalidateRoute(clearDistance: false));
                        _changed();
                      },
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return n == null || !n.isFinite || n <= 0
                            ? 'Enter a distance greater than zero'
                            : null;
                      },
                    ),
                    select(
                      'Travel / delivery method',
                      transport,
                      travelMethods,
                      (v) {
                        setState(() {
                          transport = v!;
                          invalidateRoute();
                        });
                        _changed();
                      },
                    ),
                    if (['Car', 'Motorcycle'].contains(transport)) ...[
                      OutlinedButton.icon(
                        onPressed:
                            routeWorking ||
                                pickupPoint == null ||
                                destinationPoint == null
                            ? null
                            : calculateRoute,
                        icon: routeWorking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.route_outlined),
                        label: Text(
                          routeWorking
                              ? 'Calculating route…'
                              : 'Calculate road route',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Uses pickup and drop-off pins with OSRM. Car-road estimate; motorcycle restrictions and traffic may differ.',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ] else
                      const Text(
                        'For walking, cycling, transit or shipping, enter your trip distance manually.',
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    if (routeError != null)
                      Text(
                        routeError!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFAD5743),
                        ),
                      ),
                    if (distanceSource == 'osrm_driving') ...[
                      const SizedBox(height: 12),
                      Text(
                        'Road estimate: ${distance.text} km · about ${(routeSeconds! / 60).ceil()} min by car',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220,
                        child: ErrandMap(
                          points: [pickupPoint!, destinationPoint!],
                          route: routeLine,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    select('Deadline', deadline, [
                      'In 30 minutes',
                      'In 1 hour',
                      'In 4 hours',
                      'Tomorrow',
                      'In 3 days',
                      'In 1 week',
                      'Choose date & time',
                    ], (v) => chooseDeadline(v!)),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Due ${deadlineLabel(deadlineAt)}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'This is urgent',
                        style: TextStyle(fontSize: 13),
                      ),
                      subtitle: const Text(
                        'Let nearby runners know you’re short on time.',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: urgent,
                      onChanged: (v) {
                        setState(() => urgent = v);
                        _changed();
                      },
                    ),
                    const SizedBox(height: 16),
                    field(
                      'Special instructions (optional)',
                      instructions,
                      lines: 2,
                      validator: (_) => null,
                    ),
                    note(
                      'Addresses remain editable. Changing an address clears its map pin and road estimate. Manual distances work for any delivery method.',
                      icon: Icons.location_on_outlined,
                    ),
                  ],
                  if (step == 1) ...[
                    field(
                      'Item / purchase budget (₱)',
                      budget,
                      type: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return n == null || !n.isFinite || n < 0
                            ? 'Enter a non-negative budget'
                            : null;
                      },
                    ),
                    field(
                      'Runner payment (CY)',
                      fee,
                      type: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        return n == null || !n.isFinite || n <= 0
                            ? 'Enter a runner fee greater than zero'
                            : null;
                      },
                    ),
                    infoRow(
                      'Purchase budget',
                      '₱${money(parsedAmount(budget.text))}',
                    ),
                    infoRow(
                      'Runner earnings',
                      '${money(parsedAmount(fee.text))} CY',
                    ),
                    infoRow(
                      'Runner cash-out value',
                      '₱${money(WalletRates.pesosForCashOut(parsedAmount(fee.text)))}',
                    ),
                    infoRow('Errandly service fee', '5 CY'),
                    const Divider(),
                    infoRow(
                      'Coins to secure',
                      '${money(total)} CY',
                      strong: true,
                    ),
                    infoRow(
                      'Peso budget to secure separately',
                      '₱${money(parsedAmount(budget.text))}',
                      strong: true,
                    ),
                    const SizedBox(height: 16),
                    note(
                      'The purchase budget stays in pesos. The runner receives the full actual cost as a separate reimbursement after completion; unused pesos return to you. Only the runner’s coin earnings use the cash-out rate.',
                    ),
                  ],
                  if (step == 2) ...[
                    Panel(
                      color: canvas,
                      padding: 16,
                      child: Column(
                        children: [
                          infoRow('Your errand', title.text),
                          infoRow(
                            'Coins to secure',
                            '${money(total)} CY',
                            strong: true,
                          ),
                          infoRow(
                            'Wallet available',
                            '${money(widget.store.wallet.available)} CY',
                          ),
                          infoRow(
                            'Separate peso purchase budget',
                            '₱${money(parsedAmount(budget.text))}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    infoRow('Coin payment method', 'Errandly Wallet'),
                    if (parsedAmount(budget.text) > 0)
                      PurchasePaymentChoices(
                        value: budgetPayment,
                        amount: parsedAmount(budget.text),
                        onChanged: (v) {
                          setState(() => budgetPayment = v);
                          _changed();
                        },
                      ),
                    const SizedBox(height: 16),
                    note(
                      'Publishing secures coins from your wallet and the separate peso budget through the selected simulated payment. No real money moves. Both are released only after verified handoff and requester confirmation.',
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (step > 0) ...[
                        OutlinedButton(
                          onPressed: () {
                            setState(() => step--);
                            _changed();
                          },
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: step < 2
                            ? FilledButton(
                                onPressed: next,
                                child: const Text('Continue'),
                              )
                            : AsyncActionButton(
                                label: 'Secure payment & publish',
                                loadingLabel: 'Publishing…',
                                enabled: !widget.store.busy,
                                onPressed: publish,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
