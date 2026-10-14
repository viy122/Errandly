import 'package:flutter/material.dart';

import '../models/entities.dart';
import '../state/errand_store.dart';
import 'components.dart';
import 'intro.dart';
import 'motion.dart';
import 'onboarding.dart';

class Welcome extends StatelessWidget {
  const Welcome({super.key, required this.store});
  final ErrandStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth > 800;
          final intro = Container(
            padding: EdgeInsets.all(wide ? 60 : 28),
            color: pale,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Brand(size: 90),
                const SizedBox(height: 38),
                const Tag('YOUR DAY. YOUR COMMUNITY.', icon: Icons.public),
                const SizedBox(height: 22),
                const Text(
                  'Small errands.\nMore possibilities.',
                  style: TextStyle(
                    fontSize: 48,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Your time is valuable. Let someone else do the small things.',
                  style: TextStyle(fontSize: 17, height: 1.6, color: muted),
                ),
                const SizedBox(height: 18),
                const ErrandIllustration(height: 195),
                const SizedBox(height: 18),
                const Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    Tag('Verified users', icon: Icons.verified_outlined),
                    Tag('Secure payments', icon: Icons.lock_outline),
                    Tag('Help anywhere', icon: Icons.favorite_outline),
                  ],
                ),
              ],
            ),
          );
          final actions = Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'A little help,\nright around the corner.',
                  style: TextStyle(
                    fontSize: 29,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Post an errand or earn on your own schedule. Nearby or across cities, one account opens up more possibilities.',
                  style: TextStyle(color: muted, height: 1.6),
                ),
                const SizedBox(height: 30),
                FilledButton(
                  onPressed: () => sheet(context, AuthForm(store: store)),
                  child: const Text('Log in'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () =>
                      sheet(context, AuthForm(store: store, signup: true)),
                  child: const Text('Create an account'),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: store.busy || !store.demoEnabled
                      ? null
                      : () => sheet(
                          context,
                          AuthForm(store: store, demoOnly: true),
                        ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Continue as Demo User',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                TextButton.icon(
                  onPressed: () => openGuide(context),
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: const Text('How Errandly works'),
                ),
                TextButton.icon(
                  onPressed: () => replayIntro(context),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Watch the Errandly intro'),
                ),
                note(
                  store.databaseBacked
                      ? 'Connected to MySQL. Accounts, errands and proof images are saved. Payments and verification are simulated.'
                      : 'Interactive prototype. Payments and verification are simulated. Data and proof images last for this session.',
                  icon: Icons.science_outlined,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Everyday errands. Any location.\nPowered by people, wherever life takes you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: muted, height: 1.6),
                ),
              ],
            ),
          );
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: wide
                  ? IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(flex: 6, child: intro),
                          Expanded(
                            flex: 4,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: actions,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(children: [intro, actions]),
            ),
          );
        },
      ),
    ),
  );
}

class AuthForm extends StatefulWidget {
  const AuthForm({
    super.key,
    required this.store,
    this.signup = false,
    this.demoOnly = false,
  });
  final ErrandStore store;
  final bool signup;
  final bool demoOnly;
  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      phone = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController(),
      area = TextEditingController();
  bool agreed = false, photo = false, identityId = false;
  bool runner = false;
  String demoAccount = 'anna';
  late bool demoLogin = widget.demoOnly;
  @override
  void dispose() {
    for (final c in [name, email, phone, password, confirm, area]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!demoLogin && !form.currentState!.validate()) {
      return;
    }
    if (widget.signup && (!agreed || !identityId)) {
      toast(
        context,
        'Agree to the terms and attach a simulated identity document.',
      );
      return;
    }
    if (await attempt(context, () async {
      if (demoLogin) {
        await widget.store.demo(demoAccount);
      } else if (widget.signup) {
        await widget.store.register(
          UserProfile(
            id: 'u${DateTime.now().microsecondsSinceEpoch}',
            name: name.text.trim(),
            email: email.text.trim(),
            phone: phone.text,
            password: password.text,
            location: area.text.trim(),
            verified: false,
            rating: 0,
            completed: 0,
          )..photo = photo,
        );
      } else {
        await widget.store.login(email.text, password.text);
      }
      widget.store.setMode(runner);
    })) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.signup) ...[
            const ErrandIllustration(height: 120),
            const SizedBox(height: 18),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  demoLogin
                      ? 'Try Errandly'
                      : widget.signup
                      ? 'Join Errandly'
                      : 'Welcome back',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close login',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            demoLogin
                ? 'Choose a demo account and how you want to use Errandly.'
                : widget.signup
                ? 'A single account to request and run errands.'
                : 'Choose your role for this session, then log in.',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Text(
            'Continue as',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            key: const ValueKey('login-role'),
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Requester'),
                icon: Icon(Icons.add_task_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Runner'),
                icon: Icon(Icons.directions_run),
              ),
            ],
            selected: {runner},
            onSelectionChanged: widget.store.busy
                ? null
                : (values) => setState(() => runner = values.single),
          ),
          const SizedBox(height: 10),
          Text(
            runner
                ? 'Find errands, accept jobs and earn.'
                : 'Post errands and track your requests.',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 20),
          if (demoLogin) ...[
            const Text(
              'Demo account',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              key: const ValueKey('login-demo-account'),
              segments: const [
                ButtonSegment(value: 'anna', label: Text('Anna')),
                ButtonSegment(value: 'ben', label: Text('Ben')),
              ],
              selected: {demoAccount},
              onSelectionChanged: widget.store.busy
                  ? null
                  : (values) => setState(() {
                      demoAccount = values.single;
                      runner = demoAccount == 'ben';
                    }),
            ),
          ] else ...[
            if (widget.signup) field('Full name', name),
            field(
              'Email',
              email,
              type: TextInputType.emailAddress,
              validator: (v) =>
                  v != null && RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)
                  ? null
                  : 'Enter a valid email',
            ),
            if (widget.signup)
              field(
                'Phone number',
                phone,
                type: TextInputType.phone,
                validator: (v) => RegExp(r'^\+?\d{7,15}$').hasMatch(v ?? '')
                    ? null
                    : 'Use 7–15 digits, with an optional + country code',
              ),
            field(
              'Password',
              password,
              password: true,
              validator: (v) => v != null && v.length >= 6
                  ? null
                  : 'Use at least 6 characters',
            ),
            if (widget.signup) ...[
              field(
                'Confirm password',
                confirm,
                password: true,
                validator: (v) =>
                    v == password.text ? null : 'Passwords must match',
              ),
              field(
                'Home area / city',
                area,
                hint: 'e.g. Makati City or your province',
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => photo = !photo),
                icon: Icon(
                  photo ? Icons.check_circle : Icons.add_a_photo_outlined,
                ),
                label: Text(
                  photo
                      ? 'Profile photo attached (sample)'
                      : 'Attach sample profile photo',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() => identityId = !identityId),
                icon: Icon(
                  identityId ? Icons.check_circle : Icons.badge_outlined,
                ),
                label: Text(
                  identityId
                      ? 'Identity document attached (sample)'
                      : 'Attach sample identity document',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: agreed,
                onChanged: (v) => setState(() => agreed = v!),
                title: const Text(
                  'I agree to the Terms and Privacy Policy',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => sheet(
                  context,
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Community terms & privacy\n\nUse your own identity. Meet in public, well-lit places. Keep payments inside Errandly. Treat other users with respect.\n\nContact details are private by default. The connected app saves data in its MySQL database through an authenticated API. Verification, file attachments and payments are still simulated. Use sample information while testing.',
                    ),
                  ),
                ),
                child: const Text('Read terms & privacy'),
              ),
            ] else
              TextButton(
                onPressed: () =>
                    sheet(context, ForgotPassword(store: widget.store)),
                child: const Text('Forgot password?'),
              ),
          ],
          if (!widget.signup && widget.store.demoEnabled) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.store.busy
                  ? null
                  : () => setState(() => demoLogin = !demoLogin),
              child: Text(
                demoLogin ? 'Use email and password' : 'Use demo accounts',
              ),
            ),
          ],
          const SizedBox(height: 16),
          AsyncActionButton(
            enabled: !widget.store.busy,
            onPressed: submit,
            label: demoLogin
                ? 'Enter demo'
                : widget.signup
                ? 'Create account'
                : 'Log in',
            loadingLabel: widget.signup ? 'Creating account…' : 'Signing in…',
          ),
        ],
      ),
    ),
  );
}

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key, required this.store});
  final ErrandStore store;
  @override
  State<ForgotPassword> createState() => _ForgotPasswordState();
}

class _ForgotPasswordState extends State<ForgotPassword> {
  final email = TextEditingController();
  bool sent = false;
  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageTitle('Reset password', 'A fresh start for your account.'),
        if (sent)
          note(
            'A reset-link email is simulated for ${email.text}. No real email was sent. Existing demo passwords remain demo123.',
          )
        else
          field('Email', email),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            if (sent) {
              Navigator.pop(context);
            } else if (RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email.text)) {
              setState(() => sent = true);
            } else {
              toast(context, 'Enter a valid email address.');
            }
          },
          child: Text(sent ? 'Done' : 'Simulate reset email'),
        ),
      ],
    ),
  );
}

class Verification extends StatelessWidget {
  const Verification({super.key, required this.store});
  final ErrandStore store;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.verified_user_outlined, color: teal, size: 54),
            const SizedBox(height: 22),
            const PageTitle(
              'Let’s build a little trust.',
              'Verify your identity to request and run errands.',
            ),
            const Text(
              'Prototype verification uses sample documents and simulated codes.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 20),
            for (final step in ['Identity document', 'Email', 'Phone number'])
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  (step == 'Identity document'
                          ? store.user.idVerified
                          : step == 'Email'
                          ? store.user.emailVerified
                          : store.user.phoneVerified)
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: teal,
                ),
                title: Text(step),
                trailing: TextButton(
                  onPressed: () {
                    if (step == 'Identity document') {
                      store.user.idVerified = true;
                    } else if (step == 'Email') {
                      store.user.emailVerified = true;
                    } else {
                      store.user.phoneVerified = true;
                    }
                    store.refresh();
                  },
                  child: const Text('Simulate verify'),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use sample locations'),
              subtitle: const Text('Optional. No GPS data is needed.'),
              value: store.user.locationAllowed,
              onChanged: (v) {
                store.user.locationAllowed = v;
                store.refresh();
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => attempt(context, store.verify),
              child: const Text('Finish verification'),
            ),
            TextButton(
              onPressed: () => attempt(context, store.logout),
              child: const Text('Back to welcome'),
            ),
          ],
        ),
      ),
    ),
  );
}
