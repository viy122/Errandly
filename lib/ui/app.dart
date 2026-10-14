import 'dart:async';

import 'package:flutter/material.dart';

import '../state/errand_store.dart';
import 'components.dart';
import 'auth.dart';
import 'marketplace.dart';
import 'post_form.dart';
import 'account.dart';
import 'details.dart';
import 'location_picker.dart';
import 'role_dashboard.dart';
import 'mobile_header.dart';
import 'intro.dart';
import 'onboarding.dart';
import 'in_app_alerts.dart';
import 'notification_settings.dart';
import 'theme.dart';

class ErrandlyApp extends StatelessWidget {
  const ErrandlyApp({super.key, required this.store, this.showIntro = false});
  final ErrandStore store;
  final bool showIntro;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Errandly — Everyday help, anywhere',
    debugShowCheckedModeBanner: false,
    theme: errandlyTheme(),
    home: IntroGate(
      enabled: showIntro,
      child: OnboardingGate(
        preferences: store.preferences,
        enabled: showIntro,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => Column(
            children: [
              if (store.databaseBacked && store.busy)
                const LinearProgressIndicator(minHeight: 3),
              if (store.databaseBacked && store.connectionError != null)
                Material(
                  color: const Color(0xFFFFE7AB),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              store.connectionError!,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: store.busy
                                ? null
                                : () => store.currentId == null
                                      ? store.initialize()
                                      : store.reload(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: store.currentId == null
                    ? Welcome(store: store)
                    : InAppAlerts(
                        store: store,
                        child: Shell(store: store),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.store});
  final ErrandStore store;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int page = 0;
  final scroll = ScrollController();
  Timer? expiry;
  bool foreground = true;
  late bool previousRunnerMode;
  String? previousAccount;
  ErrandStore get s => widget.store;
  List<String> get names => [
    s.runnerMode ? 'Find errands' : 'Home',
    'My Errands',
    'Post an errand',
    'Wallet',
    'My profile',
    'Messages',
    'Saved errands',
    'Friends & favorites',
    'Notifications',
    'Safety center',
  ];
  List<IconData> get icons => [
    s.runnerMode ? Icons.explore_outlined : Icons.grid_view_outlined,
    Icons.assignment_outlined,
    s.runnerMode ? Icons.route_outlined : Icons.add,
    Icons.account_balance_wallet_outlined,
    Icons.person_outline,
    Icons.chat_bubble_outline,
    Icons.bookmark_border,
    Icons.people_outline,
    Icons.notifications_none,
    Icons.shield_outlined,
  ];
  @override
  void initState() {
    super.initState();
    previousRunnerMode = s.runnerMode;
    previousAccount = s.currentId;
    WidgetsBinding.instance.addObserver(this);
    expiry = Timer.periodic(const Duration(seconds: 5), (_) {
      if (foreground) unawaited(s.reload());
    });
  }

  @override
  void dispose() {
    expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) unawaited(s.reload());
  }

  @override
  void didUpdateWidget(covariant Shell oldWidget) {
    super.didUpdateWidget(oldWidget);
    var resetScroll = previousAccount != s.currentId;
    if (s.runnerMode && !previousRunnerMode && (page == 1 || page == 2)) {
      page = 0;
      resetScroll = true;
    }
    previousRunnerMode = s.runnerMode;
    previousAccount = s.currentId;
    if (resetScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) scroll.jumpTo(0);
      });
    }
  }

  void navigate(int v) {
    if (scroll.hasClients) scroll.jumpTo(0);
    setState(() => page = v);
  }

  int get parentPage => page == 2
      ? 1
      : page >= 6
      ? 4
      : 0;
  int get selectedTab => page == 2
      ? 1
      : page >= 6
      ? 4
      : page;

  void postRequest() {
    if (s.runnerMode) {
      toast(
        context,
        'Log out and choose Requester at login to post an errand.',
      );
      return;
    }
    navigate(2);
  }

  Widget navigation(int i) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Material(
      color: page == i ? ink : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        key: ValueKey('nav-$i'),
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          icons[i],
          size: 21,
          color: page == i ? Colors.white : muted,
        ),
        title: Text(
          names[i],
          style: TextStyle(
            fontSize: 13,
            color: page == i ? Colors.white : muted,
            fontWeight: page == i ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: i == 0
            ? Tag(
                '${s.runnerMode ? s.runnerOpportunities.length : s.requests.where((e) => !e.terminal).length}',
              )
            : null,
        onTap: () => navigate(i),
      ),
    ),
  );
  Widget sidebar() => Container(
    width: 228,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: line)),
    ),
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 30, 24, 32),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Brand(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 0, 12),
                    child: Text(
                      'YOUR ERRANDLY SPACE',
                      style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  navigation(0),
                  navigation(1),
                  navigation(5),
                  navigation(3),
                  navigation(4),
                  navigation(6),
                  navigation(7),
                  const SizedBox(height: 22),
                  if (!s.runnerMode)
                    FilledButton.icon(
                      onPressed: postRequest,
                      icon: const Icon(Icons.add, size: 19),
                      label: const Text('Post an errand'),
                    ),
                  const SizedBox(height: 34),
                  const Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 8),
                    child: Text(
                      'GOOD TO KNOW',
                      style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  navigation(9),
                  Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      leading: const Icon(
                        Icons.settings_outlined,
                        color: muted,
                        size: 21,
                      ),
                      title: const Text(
                        'Settings',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                      onTap: () {
                        openNotificationSettings(context, s);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Panel(
                    padding: 16,
                    color: const Color(0xFFFAF5E9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.volunteer_activism_outlined,
                          color: teal,
                          size: 26,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'A little help.\nA big difference.',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Make someone’s day a little easier.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                        TextButton(
                          onPressed: () => navigate(s.runnerMode ? 0 : 2),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          child: Text(
                            s.runnerMode
                                ? 'Find an errand →'
                                : 'Post a request →',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: Avatar(s.user),
              title: Text(
                s.user.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'View your profile',
                style: TextStyle(fontSize: 11, color: muted),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => navigate(4),
            ),
          ),
        ],
      ),
    ),
  );
  Widget content() => switch (page) {
    0 =>
      s.runnerMode
          ? Marketplace(
              key: ValueKey('runner-feed-${s.currentId}'),
              store: s,
              onPost: postRequest,
              onWallet: () => navigate(3),
              onJobs: () => navigate(1),
            )
          : RequesterDashboard(
              store: s,
              onPost: postRequest,
              onRequests: () => navigate(1),
              onWallet: () => navigate(3),
            ),
    1 => MyErrands(store: s, onFind: () => navigate(0), onPost: postRequest),
    2 => PostForm(
      key: ValueKey('post-${s.currentId}'),
      store: s,
      onPublished: () => navigate(1),
    ),
    3 => WalletPage(store: s),
    4 => ProfilePage(
      store: s,
      onSaved: () => navigate(6),
      onFriends: () => navigate(7),
      onSafety: () => navigate(9),
    ),
    5 => MessagesPage(store: s),
    6 => Marketplace(
      key: ValueKey('saved-feed-${s.currentId}'),
      store: s,
      onPost: postRequest,
      onWallet: () => navigate(3),
      onJobs: () => navigate(1),
      savedOnly: true,
    ),
    7 => FriendsPage(store: s, onHire: postRequest),
    8 => NotificationsPage(store: s),
    _ => SafetyPage(store: s),
  };
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final desktop = box.maxWidth >= 980;
      return PopScope(
        canPop: page == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) navigate(parentPage);
        },
        child: Scaffold(
          bottomNavigationBar: desktop
              ? null
              : SafeArea(
                  top: false,
                  child: Container(
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: line)),
                    ),
                    child: Row(
                      children: List.generate(5, (i) {
                        final target = [0, 1, 5, 3, 4][i];
                        final label = [
                          s.runnerMode ? 'Find Errands' : 'Home',
                          'My Errands',
                          'Messages',
                          'Wallet',
                          'Profile',
                        ][i];
                        final selected = selectedTab == target;
                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: selected,
                            label: label,
                            onTap: () => navigate(target),
                            excludeSemantics: true,
                            child: InkWell(
                              key: ValueKey('nav-$target'),
                              onTap: () => navigate(target),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    icons[target],
                                    color: selected ? teal : muted,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.2,
                                      color: selected ? teal : muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
          body: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (desktop) sidebar(),
                Expanded(
                  child: Column(
                    children: [
                      if (!desktop)
                        MobileHeader(
                          store: s,
                          onProfile: () => navigate(4),
                          onNotifications: () =>
                              sheet(context, NotificationsSheet(store: s)),
                          onWallet: () => navigate(3),
                        ),
                      if (desktop)
                        Container(
                          height: 82,
                          padding: EdgeInsets.symmetric(
                            horizontal: desktop ? 32 : 16,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(bottom: BorderSide(color: line)),
                          ),
                          child: Row(
                            children: [
                              if (s.runnerMode) LocationPicker(store: s),
                              if (!s.runnerMode) const Tag('REQUESTER'),
                              const Spacer(),
                              const Tag(
                                'LIVE DEMO',
                                icon: Icons.circle,
                                color: muted,
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                tooltip: 'Notifications',
                                onPressed: () => sheet(
                                  context,
                                  NotificationsSheet(store: s),
                                ),
                                icon: Badge(
                                  isLabelVisible: s.hasUnreadAlerts,
                                  smallSize: 7,
                                  child: const Icon(
                                    Icons.notifications_none,
                                    size: 23,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              InkWell(
                                onTap: () => navigate(4),
                                child: Avatar(s.user, size: 36),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scroll,
                          padding: EdgeInsets.all(desktop ? 32 : 14),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1240),
                              child: s.user.verified
                                  ? AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      child: KeyedSubtree(
                                        key: ValueKey((
                                          s.currentId,
                                          s.runnerMode,
                                          page,
                                        )),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (page == 2 || page >= 6)
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: TextButton.icon(
                                                  onPressed: () =>
                                                      navigate(parentPage),
                                                  icon: const Icon(
                                                    Icons.arrow_back,
                                                    size: 18,
                                                  ),
                                                  label: Text(
                                                    page == 2
                                                        ? 'Back to My Errands'
                                                        : 'Back to Profile',
                                                  ),
                                                ),
                                              ),
                                            content(),
                                          ],
                                        ),
                                      ),
                                    )
                                  : Verification(store: s),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
