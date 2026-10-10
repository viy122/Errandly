import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/errand_api.dart';
import '../data/entity_codec.dart';
import '../models/entities.dart';
import '../models/wallet_rates.dart';
import '../models/proof_image.dart';
import '../models/geo.dart';
import '../data/map_services.dart';
import 'personal_preferences.dart';

/// Local fixtures for tests; the running app uses the authenticated MySQL API.
class ErrandStore extends ChangeNotifier {
  ErrandStore({PersonalPreferences? preferences, this.mapServices})
    : api = null,
      preferences = preferences ?? PersonalPreferences() {
    _seed();
    this.preferences.addListener(notifyListeners);
  }
  ErrandStore.mysql(
    this.api, {
    PersonalPreferences? preferences,
    this.mapServices,
  }) : preferences = preferences ?? PersonalPreferences() {
    this.preferences.addListener(notifyListeners);
  }
  final PersonalPreferences preferences;
  bool _disposed = false;
  bool get hasUnreadAlerts => notifications.any(
    (n) =>
        n.userId == currentId &&
        !n.read &&
        preferences.forAccount(currentId).allows(n.type),
  );
  @override
  void dispose() {
    _disposed = true;
    preferences.removeListener(notifyListeners);
    preferences.dispose();
    api?.close();
    super.dispose();
  }

  final ErrandApi? api;
  final MapServices? mapServices;
  late final MapServices maps = mapServices ?? MapServices(api: api);
  // Device location is session-only and never sent by nearest sorting.
  GeoPoint? browsingPosition;
  void setBrowsingPosition(GeoPoint? point) {
    browsingPosition = point;
    notifyListeners();
  }

  bool busy = false,
      databaseReady = false,
      demoEnabled = true,
      isSupport = false;
  String? connectionError;
  bool get databaseBacked => api != null;

  Future<void> initialize() async {
    await preferences.load();
    if (api == null) {
      if (currentId != null) {
        runnerMode = preferences.roleFor(currentId) ?? runnerMode;
      }
      notifyListeners();
      return;
    }
    await quietly(() async {
      await _perform('health');
      if (api!.token != null) {
        await _perform('state');
        runnerMode = preferences.roleFor(currentId) ?? currentId == 'ben';
        notifyListeners();
      }
    });
  }

  /// Used by background updates and simple buttons. Errors remain visible.
  Future<void> quietly(FutureOr<void> Function() action) async {
    try {
      await action();
    } on StateError catch (e) {
      connectionError = e.message;
      notifyListeners();
    }
  }

  Future<void> _perform(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (busy) throw StateError('A change is still saving. Please wait.');
    busy = true;
    connectionError = null;
    notifyListeners();
    try {
      final response = await api!.call(action, data);
      databaseReady = true;
      if (response['state'] != null) {
        _hydrate(response['state'] as Map<String, dynamic>);
      } else if (response['demo'] is bool) {
        demoEnabled = response['demo'] as bool;
      }
    } on StateError catch (e) {
      connectionError = e.message;
      if (api!.token == null && action == 'state') currentId = null;
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> reload() async {
    if (api == null) {
      expireDue();
      notifyListeners();
    } else if (!busy && currentId != null) {
      await quietly(() => _perform('state'));
    }
  }

  FutureOr<void> saveProfile() {
    if (api != null) return _perform('profile', {'profile': profileJson(user)});
    notifyListeners();
  }

  FutureOr<void> markRead([Notice? notice]) {
    final all = notice == null
        ? notifications.where((n) => n.userId == currentId).toList()
        : [notice];
    if (api != null) {
      return _perform('read', {
        'ids': all.map((n) => n.id).whereType<String>().toList(),
      });
    }
    for (final n in all) {
      n.read = true;
    }
    notifyListeners();
  }

  FutureOr<void> reportStatus(Report r, String status) {
    if (api != null) {
      return _perform('reportStatus', {'reportId': r.id, 'status': status});
    }
    r.status = status;
    notifyListeners();
  }

  void _hydrate(Map<String, dynamic> state) {
    final previous = {for (final e in errands) e.id: e};
    currentId = state['currentId'];
    demoEnabled = state['demo'];
    isSupport = state['support'] == true;
    users.clear();
    for (final j in state['users'] as List) {
      final u = profileFromJson(Map<String, dynamic>.from(j));
      users[u.id] = u;
    }
    errands.clear();
    for (final j in state['errands'] as List) {
      errands.add(
        errandFromJson(
          Map<String, dynamic>.from(j),
          existing: previous[j['id']],
        ),
      );
    }
    wallets.clear();
    final w = state['wallet'];
    wallets[currentId!] = Wallet(
      (w['available'] as num).toDouble(),
      totalEarnings: (w['totalEarnings'] as num).toDouble(),
    )..refunds = (w['refunds'] as num).toDouble();
    transactions.clear();
    for (final j in state['transactions'] as List) {
      transactions.add(
        WalletEntry(
          j['userId'],
          j['type'],
          (j['amount'] as num).toDouble(),
          j['note'],
          status: j['status'],
          currency: j['currency'] ?? 'CY',
          id: j['id']?.toString(),
          errandId: j['errandId'],
          pesoAmount: (j['pesoAmount'] as num?)?.toDouble(),
          date: DateTime.parse(j['date']).toLocal(),
        ),
      );
    }
    notifications.clear();
    for (final j in state['notifications'] as List) {
      notifications.add(
        Notice(
          j['userId'],
          j['type'],
          j['text'],
          id: j['id'],
          errandId: j['errandId'],
          date: DateTime.parse(j['date']).toLocal(),
        )..read = j['read'],
      );
    }
    messages.clear();
    for (final j in state['messages'] as List) {
      messages.add(
        ChatMessage(
          j['errandId'],
          j['senderId'],
          j['text'],
          date: DateTime.parse(j['date']).toLocal(),
          recipientId: j['recipientId'],
        ),
      );
    }
    reviews.clear();
    for (final j in state['reviews'] as List) {
      reviews.add(
        Review(
          j['errandId'],
          j['fromId'],
          j['toId'],
          j['stars'],
          j['text'],
          Map<String, int>.from(j['scores']),
        ),
      );
    }
    reports.clear();
    for (final j in state['reports'] as List) {
      reports.add(
        Report(
          j['userId'],
          j['reason'],
          j['description'],
          id: j['id'],
          errandId: j['errandId'],
          evidence: j['evidence'],
        )..status = j['status'],
      );
    }
    for (final pair in [
      (saved, 'saved'),
      (friends, 'friends'),
      (favorites, 'favorites'),
      (blocked, 'blocked'),
    ]) {
      pair.$1.clear();
      pair.$1[currentId!] = Set<String>.from(state[pair.$2]);
    }
  }

  final Map<String, UserProfile> users = {};
  final Map<String, Wallet> wallets = {};
  final List<Errand> errands = [];
  final List<WalletEntry> transactions = [];
  final List<Notice> notifications = [];
  final List<ChatMessage> messages = [];
  final List<Review> reviews = [];
  final List<Report> reports = [];
  final Map<String, Set<String>> saved = {},
      friends = {},
      favorites = {},
      blocked = {};
  String? currentId;
  String? preferredRunnerId;
  bool runnerMode = true;
  String browseArea = 'All locations';
  List<String> get areaOptions => [
    'All locations',
    ...(errands.map((e) => e.area).toSet().toList()..sort()),
  ];
  void setBrowseArea(String area) {
    browseArea = area;
    notifyListeners();
  }

  bool get isDemoAccount =>
      demoEnabled &&
      const {'ben', 'anna', 'maria', 'joshua'}.contains(currentId);
  UserProfile get user => users[currentId]!;
  Wallet get wallet => wallets[currentId]!;
  Set<String> get savedIds => saved.putIfAbsent(currentId!, () => {});
  Set<String> get friendIds => friends.putIfAbsent(currentId!, () => {});
  Set<String> get favoriteIds => favorites.putIfAbsent(currentId!, () => {});
  List<Errand> get mine => errands
      .where((e) => e.ownerId == currentId || e.runnerId == currentId)
      .toList();
  List<Errand> get requests =>
      errands.where((e) => e.ownerId == currentId).toList();
  List<Errand> get jobs =>
      errands.where((e) => e.runnerId == currentId).toList();
  List<Errand> get activeJobs => jobs.where((e) => !e.terminal).toList();
  List<Errand> get runnerOpportunities =>
      available.where((e) => e.ownerId != currentId).toList();
  double get securedPayments =>
      requests.where((e) => !e.terminal).fold(0, (total, e) => total + e.total);
  List<Errand> get available => errands
      .where(
        (e) =>
            e.available &&
            (browseArea == 'All locations' || e.area == browseArea) &&
            !(blocked[currentId] ?? {}).contains(e.ownerId),
      )
      .toList();
  double get locked => mine
      .where((e) => e.ownerId == currentId && !e.terminal)
      .fold(0, (v, e) => v + (e.pesoPurchase ? 0 : e.budget) + e.fee);
  double get purchaseBudget => mine
      .where((e) => e.ownerId == currentId && !e.terminal && e.pesoPurchase)
      .fold(0, (v, e) => v + e.budget);
  double get pesoRefunds => transactions
      .where(
        (t) =>
            t.userId == currentId && t.type == 'Refund' && t.currency == 'PHP',
      )
      .fold(0, (v, t) => v + t.amount);
  double get reimbursements => transactions
      .where((t) => t.userId == currentId && t.type == 'Purchase Reimbursement')
      .fold(0, (v, t) => v + t.amount);
  double get pending => mine
      .where((e) => e.runnerId == currentId && !e.terminal)
      .fold(0, (v, e) => v + e.fee);
  void refresh() => notifyListeners();
  FutureOr<void> demo([String id = 'ben']) {
    if (api != null) {
      return _perform('demo', {'userId': id}).then((_) async {
        browsingPosition = null;
        preferredRunnerId = null;
        await preferences.load();
        runnerMode = preferences.roleFor(id) ?? id == 'ben';
        notifyListeners();
      });
    }
    preferredRunnerId = null;
    currentId = id;
    browsingPosition = null;
    runnerMode = preferences.roleFor(id) ?? id == 'ben';
    expireDue();
    notifyListeners();
  }

  FutureOr<void> logout() {
    if (api != null) {
      return _perform('logout').then((_) {
        api!.clearSession();
        currentId = null;
        browsingPosition = null;
        preferredRunnerId = null;
        notifyListeners();
      });
    }
    preferredRunnerId = null;
    currentId = null;
    browsingPosition = null;
    notifyListeners();
  }

  void setMode(bool runner) {
    runnerMode = runner;
    final id = currentId;
    if (id != null) {
      unawaited(
        preferences.setRole(id, runner).catchError((_) {
          if (!_disposed) {
            connectionError =
                'Your role changed, but could not be saved on this device.';
            notifyListeners();
          }
        }),
      );
    }
    notifyListeners();
  }

  FutureOr<void> login(String email, String password) {
    if (api != null) {
      return _perform('login', {
        'email': email.trim(),
        'password': password,
      }).then((_) async {
        browsingPosition = null;
        await preferences.load();
        runnerMode = preferences.roleFor(currentId) ?? currentId == 'ben';
        notifyListeners();
      });
    }
    final found = users.values.where(
      (u) =>
          u.email.toLowerCase() == email.trim().toLowerCase() &&
          u.password == password,
    );
    if (found.isEmpty) {
      throw StateError('Email or password is incorrect.');
    }
    currentId = found.first.id;
    browsingPosition = null;
    runnerMode = preferences.roleFor(currentId) ?? currentId == 'ben';
    expireDue();
    notifyListeners();
  }

  FutureOr<void> register(UserProfile student) {
    if (api != null) {
      return _perform('register', {
        'profile': profileJson(student),
        'password': student.password,
      });
    }
    if (users.values.any(
      (u) => u.email.toLowerCase() == student.email.toLowerCase(),
    )) {
      throw StateError('This email already has an account.');
    }
    users[student.id] = student;
    wallets[student.id] = Wallet(0);
    currentId = student.id;
    notifyListeners();
  }

  FutureOr<void> verify() {
    if (api != null) return _perform('verify', {'profile': profileJson(user)});
    if (!user.emailVerified || !user.phoneVerified || !user.idVerified) {
      throw StateError('Complete all three verification steps first.');
    }
    user.verified = true;
    notice(
      currentId!,
      'Errands',
      'Your account is verified. Welcome to Errandly!',
    );
    notifyListeners();
  }

  void notice(String id, String type, String text, [String? errandId]) =>
      notifications.insert(0, Notice(id, type, text, errandId: errandId));
  void entry(
    String id,
    String type,
    double amount,
    String note, {
    String currency = 'CY',
    String? errandId,
    double? pesoAmount,
  }) => transactions.insert(
    0,
    WalletEntry(
      id,
      type,
      amount,
      note,
      currency: currency,
      errandId: errandId,
      pesoAmount: pesoAmount,
    ),
  );
  FutureOr<void> toggleSave(Errand e) {
    if (api != null) return _perform('save', {'errandId': e.id});
    savedIds.contains(e.id) ? savedIds.remove(e.id) : savedIds.add(e.id);
    notifyListeners();
  }

  FutureOr<void> toggleFriend(String id) {
    if (api != null) return _perform('friend', {'targetId': id});
    final other = friends.putIfAbsent(id, () => {});
    if (friendIds.contains(id)) {
      friendIds.remove(id);
      other.remove(currentId);
    } else {
      friendIds.add(id);
      other.add(currentId!);
    }
    notifyListeners();
  }

  FutureOr<void> toggleFavorite(String id) {
    if (api != null) return _perform('favorite', {'targetId': id});
    favoriteIds.contains(id) ? favoriteIds.remove(id) : favoriteIds.add(id);
    notifyListeners();
  }

  FutureOr<void> block(String id) {
    if (api != null) return _perform('block', {'targetId': id});
    blocked.putIfAbsent(currentId!, () => {}).add(id);
    notifyListeners();
  }

  FutureOr<void> post(
    Errand e,
    String method, {
    String budgetMethod = 'GCash Simulation',
  }) {
    if (api != null) {
      return _perform('post', {
        'errand': errandJson(e),
        'method': method,
        'budgetMethod': budgetMethod,
        'preferredRunnerId': preferredRunnerId,
      }).then((_) {
        preferredRunnerId = null;
      });
    }
    for (final existing in errands.where((existing) => existing.id == e.id)) {
      if (existing.ownerId != currentId ||
          jsonEncode(errandJson(existing)) != jsonEncode(errandJson(e))) {
        throw StateError(
          'This draft was already published. Open the existing errand or start a new draft.',
        );
      }
      return null;
    }
    if (!user.verified) {
      throw StateError('Verify your account before posting.');
    }
    if (!const [
          'Errandly Wallet',
          'GCash Simulation',
          'Debit / Card Simulation',
        ].contains(method) ||
        !const [
          'GCash Simulation',
          'Debit / Card Simulation',
        ].contains(budgetMethod)) {
      throw StateError('Choose a valid payment method.');
    }
    if (e.ownerId != currentId ||
        !e.budget.isFinite ||
        !e.fee.isFinite ||
        e.budget < 0 ||
        e.fee <= 0 ||
        !e.distance.isFinite ||
        e.distance <= 0 ||
        e.area.trim().isEmpty ||
        e.pickup.trim().isEmpty ||
        e.destination.trim().isEmpty ||
        !e.deadline.isAfter(DateTime.now())) {
      throw StateError('Check your budget, fee, and future deadline.');
    }
    if (method == 'Errandly Wallet') {
      if (wallet.available < e.total) {
        throw StateError(
          'Not enough coins. Top up or choose a simulated payment.',
        );
      }
      wallet.available -= e.total;
    }
    entry(
      currentId!,
      'Errand Payment',
      -e.total,
      '${e.title} • $method • secured',
      errandId: e.id,
    );
    if (e.pesoPurchase && e.budget > 0) {
      entry(
        currentId!,
        'Purchase Funding',
        -e.budget,
        '${e.title} • $budgetMethod • secured separately',
        errandId: e.id,
        currency: 'PHP',
      );
    }
    errands.insert(0, e);
    if (preferredRunnerId != null) {
      notice(
        preferredRunnerId!,
        'Errands',
        '${user.firstName} invited you to help: ${e.title}.',
        e.id,
      );
      preferredRunnerId = null;
    }
    notice(
      currentId!,
      'Errands',
      'Payment secured. Your errand is now posted.',
      e.id,
    );
    notifyListeners();
  }

  FutureOr<void> accept(Errand e) {
    if (api != null) return _perform('accept', {'errandId': e.id});
    expireDue();
    if (!user.verified) {
      throw StateError('Verify your account before accepting.');
    }
    if (e.ownerId == currentId) {
      throw StateError('You cannot accept your own errand.');
    }
    if (!e.available) {
      throw StateError('This errand is no longer available.');
    }
    e.runnerId = currentId;
    e.status = ErrandStatus.accepted;
    e.progress = 0;
    e.history[0] = DateTime.now();
    notice(
      e.ownerId,
      'Errands',
      '${user.firstName} accepted your errand.',
      e.id,
    );
    notice(
      currentId!,
      'Errands',
      'You accepted ${users[e.ownerId]!.firstName}\'s errand.',
      e.id,
    );
    notifyListeners();
  }

  FutureOr<void> uploadProof(
    Errand e,
    double cost, {
    required bool receipt,
    required bool photo,
    SelectedProof? receiptFile,
    SelectedProof? itemFile,
  }) {
    _checkCancellation(e);
    if (api != null) {
      if (!cost.isFinite || cost < 0 || cost > e.budget) {
        throw StateError('Actual cost must be within the purchase budget.');
      }
      if ((receiptFile == null && e.proof('receipt') == null) ||
          (itemFile == null && e.proof('item') == null)) {
        throw StateError('Attach a receipt and item photo.');
      }
      return _upload(
        'proof',
        {'errandId': e.id, 'cost': cost.toString()},
        {'receipt': ?receiptFile, 'item': ?itemFile},
      );
    }
    if (e.runnerId != currentId || e.progress != 2) {
      throw StateError('Record purchase proof at the pickup location.');
    }
    if (!receipt || !photo) {
      throw StateError('Attach both a receipt and item photo.');
    }
    if (!cost.isFinite || cost < 0 || cost > e.budget) {
      throw StateError(
        'Actual cost must be between 0 and ₱${money(e.budget)}.',
      );
    }
    e.actualCost = cost;
    e.receipt = receipt;
    e.itemPhoto = photo;
    if (receiptFile != null) _localProof(e, 'receipt', receiptFile);
    if (itemFile != null) _localProof(e, 'item', itemFile);
    notice(e.ownerId, 'Errands', 'Purchase proof is ready to review.', e.id);
    notifyListeners();
  }

  Future<void> _upload(
    String action,
    Map<String, String> fields,
    Map<String, SelectedProof> files,
  ) async {
    if (busy) throw StateError('A change is still saving. Please wait.');
    busy = true;
    connectionError = null;
    notifyListeners();
    try {
      final result = await api!.upload(action, fields, files);
      _hydrate(result['state'] as Map<String, dynamic>);
    } on StateError catch (error) {
      connectionError = error.message;
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void _localProof(Errand e, String kind, SelectedProof file) {
    e.proofFiles.removeWhere((p) => p.kind == kind);
    e.proofFiles.add(
      ProofImage(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}-$kind',
        kind: kind,
        name: file.name,
        mime: file.mime!,
        size: file.bytes.length,
        date: DateTime.now(),
        bytes: file.bytes,
      ),
    );
  }

  FutureOr<void> uploadDeliveryProof(Errand e, SelectedProof file) {
    _checkCancellation(e);
    if (e.runnerId != currentId ||
        e.progress != 5 ||
        e.terminal ||
        e.handoffVerified) {
      throw StateError(
        'Add a delivery photo when you arrive, before verifying handoff.',
      );
    }
    if (api != null) {
      return _upload('deliveryProof', {'errandId': e.id}, {'delivery': file});
    }
    _localProof(e, 'delivery', file);
    notice(e.ownerId, 'Errands', 'Your runner added a delivery photo.', e.id);
    notifyListeners();
  }

  FutureOr<void> advance(Errand e) {
    _checkCancellation(e);
    if (api != null) return _perform('advance', {'errandId': e.id});
    if (e.runnerId != currentId ||
        e.progress < 0 ||
        e.progress >= 5 ||
        e.terminal) {
      throw StateError('This task cannot advance.');
    }
    if (e.progress == 2 &&
        e.budget > 0 &&
        (!e.receipt || !e.itemPhoto || e.actualCost == null)) {
      throw StateError('Add your receipt and item photo first.');
    }
    e.progress++;
    e.history[e.progress] = DateTime.now();
    e.status = ErrandStatus.ongoing;
    if (e.progress == 5) {
      e.makePin();
    }
    notice(
      e.ownerId,
      'Errands',
      '${user.firstName}: ${progressLabels[e.progress]}.',
      e.id,
    );
    notifyListeners();
  }

  FutureOr<void> verifyPin(Errand e, String pin) {
    _checkCancellation(e);
    if (api != null) {
      return _perform('pin', {'errandId': e.id, 'pin': pin.trim()}).catchError((
        Object error,
      ) async {
        await reload();
        throw error;
      });
    }
    if (e.runnerId != currentId || e.progress != 5 || e.terminal) {
      throw StateError('Only the assigned runner can verify handoff.');
    }
    if (e.pinAttempts >= 5) {
      throw StateError('PIN locked. Ask the requester to replace the PIN.');
    }
    if (e.pin != pin.trim()) {
      e.pinAttempts++;
      notifyListeners();
      throw StateError(
        'Incorrect completion PIN. Ask the requester after handoff.',
      );
    }
    e.handoffVerified = true;
    e.progress = 6;
    e.history[6] = DateTime.now();
    e.status = ErrandStatus.waiting;
    notice(
      e.ownerId,
      'Errands',
      'Handoff verified. Please confirm that you received your errand.',
      e.id,
    );
    notifyListeners();
  }

  FutureOr<void> complete(Errand e) {
    _checkCancellation(e);
    if (api != null) return _perform('complete', {'errandId': e.id});
    if (currentId != e.ownerId ||
        !e.handoffVerified ||
        e.status != ErrandStatus.waiting) {
      throw StateError('Only the requester can confirm a verified handoff.');
    }
    e.status = ErrandStatus.completed;
    e.progress = 7;
    e.history[7] = DateTime.now();
    final runner = wallets[e.runnerId]!;
    runner.available += e.fee;
    runner.totalEarnings += e.fee;
    entry(e.runnerId!, 'Runner Earnings', e.fee, e.title, errandId: e.id);
    entry(
      e.ownerId,
      'Purchase Budget',
      -(e.actualCost ?? e.budget),
      '${e.title} • paid from secured funds',
      errandId: e.id,
      currency: e.pesoPurchase ? 'PHP' : 'CY',
    );
    if (e.pesoPurchase && (e.actualCost ?? e.budget) > 0) {
      entry(
        e.runnerId!,
        'Purchase Reimbursement',
        e.actualCost ?? e.budget,
        '${e.title} • simulated peso transfer • no conversion fee',
        errandId: e.id,
        currency: 'PHP',
      );
    }
    entry(
      e.ownerId,
      'Service Fee',
      -e.serviceFee,
      '${e.title} • paid from secured funds',
      errandId: e.id,
    );
    if (e.refund > 0) {
      if (!e.pesoPurchase) {
        wallets[e.ownerId]!.available += e.refund;
        wallets[e.ownerId]!.refunds += e.refund;
      }
      entry(
        e.ownerId,
        'Refund',
        e.refund,
        '${e.title} • ${e.pesoPurchase ? 'simulated peso refund' : 'coin refund'}',
        errandId: e.id,
        currency: e.pesoPurchase ? 'PHP' : 'CY',
      );
      notice(
        e.ownerId,
        'Wallet',
        '${e.pesoPurchase ? '₱${money(e.refund)}' : '${money(e.refund)} CY'} unused purchase budget was refunded.',
        e.id,
      );
    }
    users[e.ownerId]!.completed++;
    users[e.runnerId]!.completed++;
    notice(
      e.runnerId!,
      'Wallet',
      'You earned ${money(e.fee)} CY. Your errand is completed!',
      e.id,
    );
    notice(e.ownerId, 'Errands', 'Your errand has been completed.', e.id);
    notifyListeners();
  }

  FutureOr<void> cancel(Errand e, String reason) {
    if (api != null) {
      return _perform('cancel', {'errandId': e.id, 'reason': reason});
    }
    if ((e.ownerId != currentId && e.runnerId != currentId) || e.terminal) {
      throw StateError('Only task participants can request cancellation.');
    }
    if (e.runnerId != null) {
      if (e.cancellationPending) {
        throw StateError('A cancellation request is already pending.');
      }
      e.cancelRequestedBy = currentId;
      e.cancellationReason = reason;
      notice(
        e.ownerId,
        'Errands',
        'Cancellation requested. Respond in task details; funds remain secured.',
        e.id,
      );
      notice(
        e.runnerId!,
        'Errands',
        'Cancellation requested. Respond in task details; funds remain secured.',
        e.id,
      );
      return report(
        'Cancellation request: $reason',
        'Please review cancellation of this accepted errand.',
        errand: e,
      );
    }
    e.cancellationReason = reason;
    _refund(e, ErrandStatus.cancelled);
    notifyListeners();
  }

  void _checkCancellation(Errand e) {
    if (e.cancellationPending) {
      throw StateError(
        'Resolve or withdraw the cancellation request before continuing.',
      );
    }
  }

  FutureOr<void> resetPin(Errand e) {
    _checkCancellation(e);
    if (api != null) return _perform('resetPin', {'errandId': e.id});
    if (currentId != e.ownerId ||
        e.progress != 5 ||
        e.terminal ||
        e.handoffVerified) {
      throw StateError(
        'Only the requester can replace a PIN before verified handoff.',
      );
    }
    if (e.pinResetAt != null &&
        DateTime.now().difference(e.pinResetAt!) < const Duration(minutes: 1)) {
      throw StateError('Wait one minute before replacing the PIN again.');
    }
    final old = e.pin;
    do {
      e.pin = null;
      e.makePin();
    } while (e.pin == old);
    e.pinAttempts = 0;
    e.pinResetAt = DateTime.now();
    notice(
      e.runnerId!,
      'Errands',
      'The requester replaced the PIN. Ask for the new PIN after handoff.',
      e.id,
    );
    notifyListeners();
  }

  FutureOr<void> respondCancellation(
    Errand e,
    String decision, {
    bool support = false,
    double runnerPayment = 0,
  }) {
    if (api != null) {
      return _perform(support ? 'supportCancel' : 'cancelResponse', {
        'errandId': e.id,
        'decision': decision,
        'runnerPayment': runnerPayment,
      });
    }
    if (!e.cancellationPending) {
      throw StateError('There is no pending cancellation to resolve.');
    }
    final participant = currentId == e.ownerId || currentId == e.runnerId;
    if (support
        ? (!isSupport && !(demoEnabled && participant))
        : !participant) {
      throw StateError('You cannot review this cancellation.');
    }
    if (!support &&
        (decision == 'withdraw'
            ? e.cancelRequestedBy != currentId
            : e.cancelRequestedBy == currentId)) {
      throw StateError(
        'The other participant must answer; only the requester of cancellation can withdraw.',
      );
    }
    if (!['approve', 'reject', 'withdraw'].contains(decision) ||
        (support && decision == 'withdraw')) {
      throw StateError('Choose a valid cancellation decision.');
    }
    if (!support && decision == 'reject') {
      for (final r in reports.where(
        (r) =>
            r.errandId == e.id &&
            r.reason.startsWith('Cancellation request:') &&
            r.status == 'Submitted',
      )) {
        r.status = 'Under Review';
      }
      notifyListeners();
      return null;
    }
    if (decision == 'approve') {
      if (!support && e.needsCancellationReview) {
        throw StateError(
          'Recorded purchases or delivery work require support review.',
        );
      }
      if (!runnerPayment.isFinite ||
          runnerPayment < 0 ||
          runnerPayment > e.fee) {
        throw StateError(
          'Compensation must stay within the secured runner payment.',
        );
      }
      final cost = e.actualCost ?? 0;
      if (cost > 0 && (!e.receipt || !e.itemPhoto)) {
        throw StateError('Purchase proof must be reviewed first.');
      }
      final compensation = support ? runnerPayment : 0.0;
      final coins = e.total - (e.pesoPurchase ? 0 : cost) - compensation;
      final purchaseRefund = e.pesoPurchase ? e.budget - cost : 0.0;
      e.status = ErrandStatus.cancelled;
      e.cancelRefundCoins = coins;
      e.cancelRefundPurchase = purchaseRefund;
      e.cancelRunnerPayment = compensation;
      wallets[e.ownerId]!.available += coins;
      wallets[e.ownerId]!.refunds += coins;
      entry(
        e.ownerId,
        'Refund',
        coins,
        '${e.title} • cancellation',
        errandId: e.id,
      );
      if (purchaseRefund > 0) {
        entry(
          e.ownerId,
          'Refund',
          purchaseRefund,
          '${e.title} • simulated peso refund',
          errandId: e.id,
          currency: 'PHP',
        );
      }
      if (cost > 0) {
        entry(
          e.ownerId,
          'Purchase Budget',
          -cost,
          '${e.title} • allocated from secured funds',
          errandId: e.id,
          currency: e.pesoPurchase ? 'PHP' : 'CY',
        );
        if (!e.pesoPurchase) wallets[e.runnerId]!.available += cost;
        entry(
          e.runnerId!,
          'Purchase Reimbursement',
          cost,
          '${e.title} • cancellation reimbursement',
          errandId: e.id,
          currency: e.pesoPurchase ? 'PHP' : 'CY',
        );
      }
      if (compensation > 0) {
        wallets[e.runnerId]!.available += compensation;
        wallets[e.runnerId]!.totalEarnings += compensation;
        entry(
          e.runnerId!,
          'Runner Earnings',
          compensation,
          '${e.title} • cancellation compensation',
          errandId: e.id,
        );
      }
      notice(
        e.ownerId,
        'Wallet',
        'Cancellation resolved. Refund recorded in your wallet.',
        e.id,
      );
      notice(
        e.runnerId!,
        'Wallet',
        'Cancellation resolved. Reimbursement and compensation recorded in your wallet.',
        e.id,
      );
    }
    e.cancelRequestedBy = null;
    for (final r in reports.where(
      (r) =>
          r.errandId == e.id &&
          r.reason.startsWith('Cancellation request:') &&
          ['Submitted', 'Under Review'].contains(r.status),
    )) {
      r.status = decision == 'approve'
          ? 'Resolved'
          : decision == 'withdraw'
          ? 'Withdrawn'
          : 'Rejected';
    }
    notifyListeners();
  }

  void _refund(Errand e, ErrandStatus status) {
    e.status = status;
    wallets[e.ownerId]!.available += e.total;
    wallets[e.ownerId]!.refunds += e.total;
    entry(
      e.ownerId,
      'Refund',
      e.total,
      '${e.title} • ${status.name}',
      errandId: e.id,
    );
    if (e.pesoPurchase && e.budget > 0) {
      entry(
        e.ownerId,
        'Refund',
        e.budget,
        '${e.title} • simulated peso refund • ${status.name}',
        errandId: e.id,
        currency: 'PHP',
      );
    }
    notice(
      e.ownerId,
      'Wallet',
      '${e.title}: ${status.name}. ${money(e.total)} CY${e.pesoPurchase && e.budget > 0 ? ' and ₱${money(e.budget)}' : ''} refunded.',
      e.id,
    );
  }

  void expireDue() {
    if (api != null) return;
    for (final e in errands) {
      if (e.status == ErrandStatus.posted &&
          !e.deadline.isAfter(DateTime.now())) {
        _refund(e, ErrandStatus.expired);
      }
    }
  }

  FutureOr<void> simulateExpiry(Errand e) {
    if (api != null) return _perform('expire', {'errandId': e.id});
    if (e.ownerId != currentId || e.status != ErrandStatus.posted) {
      throw StateError('Only your unaccepted posts can expire.');
    }
    _refund(e, ErrandStatus.expired);
    notifyListeners();
  }

  FutureOr<void> topUp(double pesos, {String method = 'GCash Simulation'}) {
    if (!['GCash Simulation', 'Card Simulation'].contains(method)) {
      throw StateError('Choose a valid top-up payment method.');
    }
    if (api != null) {
      return _perform('topUp', {'pesos': pesos, 'method': method});
    }
    if (![50, 100, 200, 500].contains(pesos)) {
      throw StateError('Choose a valid top-up amount.');
    }
    final coins = WalletRates.coinsForTopUp(pesos);
    wallet.available += coins;
    entry(
      currentId!,
      'Top Up',
      coins,
      '$method • ₱${money(pesos)}',
      pesoAmount: pesos,
    );
    notice(
      currentId!,
      'Wallet',
      'Top up successful! ${money(coins)} CY added.',
    );
    notifyListeners();
  }

  FutureOr<void> cashOut(double coins, String phone) {
    if (api != null) {
      return _perform('cashOut', {'coins': coins, 'phone': phone});
    }
    if (!coins.isFinite || coins <= 0 || coins > wallet.available) {
      throw StateError('Enter an amount within your available balance.');
    }
    if (!RegExp(r'^09\d{9}$').hasMatch(phone)) {
      throw StateError('Enter an 11-digit GCash number starting with 09.');
    }
    wallet.available -= coins;
    entry(
      currentId!,
      'Cash Out',
      -coins,
      'Simulated GCash • ₱${money(WalletRates.pesosForCashOut(coins))}',
      pesoAmount: WalletRates.pesosForCashOut(coins),
    );
    notice(
      currentId!,
      'Wallet',
      'Cash out simulated: ₱${money(WalletRates.pesosForCashOut(coins))}.',
    );
    notifyListeners();
  }

  List<ChatMessage> conversationMessages(Errand e, String otherId) =>
      messages.where((m) {
        if (m.errandId != e.id) return false;
        if (m.recipientId != null) {
          return (m.senderId == currentId && m.recipientId == otherId) ||
              (m.senderId == otherId && m.recipientId == currentId);
        }
        return (currentId == e.ownerId && otherId == e.runnerId) ||
            (currentId == e.runnerId && otherId == e.ownerId);
      }).toList();

  List<(Errand, String)> get conversations {
    final threads = <(String, String), (Errand, String)>{};
    for (final e in errands) {
      final peer = currentId == e.ownerId
          ? e.runnerId
          : currentId == e.runnerId
          ? e.ownerId
          : null;
      if (peer != null) threads[(e.id, peer)] = (e, peer);
      for (final m in messages.where(
        (m) => m.errandId == e.id && m.recipientId != null,
      )) {
        final other = m.senderId == currentId
            ? m.recipientId
            : m.recipientId == currentId
            ? m.senderId
            : null;
        if (other != null && other != currentId && users.containsKey(other)) {
          threads[(e.id, other)] = (e, other);
        }
      }
    }
    return threads.values.toList();
  }

  FutureOr<void> send(Errand e, String text, {String? recipientId}) {
    if (text.trim().isEmpty) return null;
    final recipient =
        recipientId ?? (currentId == e.ownerId ? e.runnerId : e.ownerId);
    if (api != null) {
      return _perform('send', {
        'errandId': e.id,
        'text': text.trim(),
        'recipientId': recipient,
      });
    }
    if (recipient == null ||
        recipient == currentId ||
        !users.containsKey(recipient)) {
      throw StateError('Choose an existing errand conversation.');
    }
    final thread = conversationMessages(e, recipient).isNotEmpty;
    if (currentId == e.ownerId && recipient != e.runnerId && !thread) {
      throw StateError('Reply to an existing inquiry from your inbox.');
    }
    if (currentId != e.ownerId && recipient != e.ownerId) {
      throw StateError('This conversation is private.');
    }
    if (currentId != e.ownerId &&
        currentId != e.runnerId &&
        !e.available &&
        !thread) {
      throw StateError('Only task participants can use this conversation.');
    }
    if ((blocked[currentId] ?? {}).contains(recipient) ||
        (blocked[recipient] ?? {}).contains(currentId)) {
      throw StateError('This conversation is unavailable.');
    }
    messages.add(
      ChatMessage(e.id, currentId!, text.trim(), recipientId: recipient),
    );
    notice(recipient, 'Messages', '${user.firstName}: $text', e.id);
    notifyListeners();
  }

  FutureOr<void> rate(
    Errand e,
    int stars,
    String text,
    Map<String, int> scores,
  ) {
    if (api != null) {
      return _perform('rate', {
        'errandId': e.id,
        'stars': stars,
        'text': text,
        'scores': scores,
      });
    }
    if (e.status != ErrandStatus.completed ||
        (currentId != e.ownerId && currentId != e.runnerId)) {
      throw StateError('Complete a transaction before reviewing.');
    }
    if (reviews.any((r) => r.errandId == e.id && r.fromId == currentId)) {
      throw StateError('You already reviewed this errand.');
    }
    final other = currentId == e.ownerId ? e.runnerId! : e.ownerId;
    reviews.add(Review(e.id, currentId!, other, stars, text, Map.of(scores)));
    final all = reviews.where((r) => r.toId == other).toList();
    users[other]!.rating =
        all.fold<double>(0, (n, r) => n + r.stars) / all.length;
    notifyListeners();
  }

  FutureOr<void> report(
    String reason,
    String description, {
    Errand? errand,
    bool evidence = false,
  }) {
    if (api != null) {
      return _perform('report', {
        'errandId': errand?.id,
        'reason': reason,
        'description': description,
        'evidence': evidence,
      });
    }
    reports.add(
      Report(
        currentId!,
        reason,
        description,
        errandId: errand?.id,
        evidence: evidence,
      ),
    );
    notice(
      currentId!,
      'Errands',
      'Your report was submitted for review.',
      errand?.id,
    );
    notifyListeners();
  }

  void _seed() {
    users['ben'] = UserProfile(
      id: 'ben',
      name: 'Ben Santos',
      email: 'ben@example.com',
    );
    users['anna'] = UserProfile(
      id: 'anna',
      name: 'Anna Cruz',
      email: 'anna@example.com',
      rating: 4.8,
      completed: 23,
    );
    users['maria'] = UserProfile(
      id: 'maria',
      name: 'Maria Reyes',
      email: 'maria@example.com',
      rating: 4.7,
      completed: 18,
      location: 'Cebu City',
    );
    users['joshua'] = UserProfile(
      id: 'joshua',
      name: 'Joshua Mendoza',
      email: 'joshua@example.com',
      rating: 4.6,
      completed: 31,
      location: 'Metro Manila',
    );
    for (final id in users.keys) {
      wallets[id] = Wallet(
        id == 'ben' ? 450 : 1500,
        totalEarnings: id == 'ben' ? 1280 : 420,
      );
    }
    final rows = [
      [
        'anna',
        'Buy 1 Yellow Pad',
        'School Supplies',
        'Campus Store, Nasugbu',
        'CEA Building Room 204, Nasugbu',
        50,
        40,
        350,
        true,
        'Please buy an 80-sheet yellow pad and bring it to Room 204. I have a class in a bit!',
        'Nasugbu, Batangas',
      ],
      [
        'maria',
        'Print and deliver my documents',
        'Printing',
        'Print shop, Katipunan Avenue',
        'UP Town Center, Quezon City',
        30,
        85,
        4200,
        false,
        'Print 15 pages, black and white, single-sided. The PDF is ready at the printing shop.',
        'Quezon City',
      ],
      [
        'joshua',
        'Submit a document to the registrar',
        'Document Submission',
        'CEA Building, Nasugbu',
        'Registrar Office, Nasugbu',
        0,
        30,
        450,
        false,
        'Drop off my signed enrollment form at Window 2.',
        'Nasugbu, Batangas',
      ],
      [
        'anna',
        'Pick up my parcel',
        'Pickup',
        'Parcel collection point, Nasugbu',
        'Barangay Bucana, Nasugbu',
        0,
        150,
        8500,
        true,
        'Collect my prepaid parcel and bring it to my home. Message me before pickup.',
        'Nasugbu, Batangas',
      ],
      [
        'maria',
        'A little lunch rescue, please',
        'Food',
        'Food court, Ayala Center Cebu',
        'Talamban, Cebu City',
        185,
        120,
        12000,
        false,
        'One chicken rice meal and bottled water. Please keep the meal upright.',
        'Cebu City',
      ],
      [
        'joshua',
        'Deliver a book to my friend',
        'Delivery',
        'Poblacion, Makati City',
        'BGC, Taguig City',
        0,
        100,
        6500,
        false,
        'Bring the wrapped book to the building reception. Message on arrival.',
        'Metro Manila',
      ],
      [
        'anna',
        'Queue at the government service center',
        'Queueing',
        'Service center, Nasugbu town proper',
        'Service center, Nasugbu town proper',
        0,
        80,
        1000,
        false,
        'Hold my place for 30 minutes while I travel to the service center.',
        'Nasugbu, Batangas',
      ],
      [
        'maria',
        'Deliver documents to another city',
        'Delivery',
        'Quezon City, Metro Manila',
        'Dasmarinas, Cavite',
        0,
        450,
        65000,
        false,
        'Deliver a sealed document envelope tomorrow. Confirm the exact meeting point and travel arrangements in chat.',
        'Metro Manila',
      ],
      [
        'joshua',
        'Pick up groceries for the weekend',
        'Purchase',
        'Public market, Davao City',
        'Matina, Davao City',
        300,
        120,
        7000,
        false,
        'Buy the vegetables on my list. Upload a receipt and return any unused budget.',
        'Davao City',
      ],
      [
        'anna',
        'Bring my charger across town',
        'Others',
        'Barangay Bucana, Nasugbu',
        'Nasugbu town proper',
        0,
        100,
        11000,
        false,
        'My friend has my charger. Collect it and bring it to my office.',
        'Nasugbu, Batangas',
      ],
    ];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final e = Errand(
        id: 'e$i',
        ownerId: r[0] as String,
        title: r[1] as String,
        category: r[2] as String,
        pickup: r[3] as String,
        destination: r[4] as String,
        budget: (r[5] as num).toDouble(),
        fee: (r[6] as num).toDouble(),
        distance: (r[7] as num).toDouble(),
        urgent: r[8] as bool,
        description: r[9] as String,
        area: r[10] as String,
        transport: (r[7] as num) >= 1000 ? 'Motorcycle' : 'On foot',
        deadline: DateTime.now().add(Duration(hours: i == 7 ? 48 : i + 1)),
        postedAt: DateTime.now().subtract(Duration(minutes: 4 + i * 3)),
      );
      errands.add(e);
      wallets[e.ownerId]!.available -= e.total;
      entry(e.ownerId, 'Errand Payment', -e.total, '${e.title} • secured');
      if (e.budget > 0) {
        entry(
          e.ownerId,
          'Purchase Funding',
          -e.budget,
          '${e.title} • simulated peso funds secured separately',
          currency: 'PHP',
        );
      }
    }
    friends['ben'] = {'anna', 'maria'};
    friends['anna'] = {'ben'};
    friends['maria'] = {'ben'};
    favorites['ben'] = {'anna'};
    entry('ben', 'Top Up', 110, 'GCash simulation');
    entry('ben', 'Runner Earnings', 40, 'Delivered a notebook');
    notice(
      'ben',
      'Wallet',
      'Your wallet is ready. You have 450 CY to get started.',
    );
    notice('ben', 'Errands', 'Welcome back! Someone could use a hand today.');
    messages.add(
      ChatMessage(
        'e0',
        'anna',
        'Hi! Please make sure it’s the yellow pad with 80 sheets. Thank you 😊',
      ),
    );
    reviews.add(
      Review(
        'sample',
        'anna',
        'ben',
        5,
        'Ben was quick and communicated well. The item arrived safely.',
        {
          'Communication': 5,
          'Speed': 5,
          'Reliability': 5,
          'Item Handling': 5,
          'Overall Experience': 5,
        },
      ),
    );
  }
}
