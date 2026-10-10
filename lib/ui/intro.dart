import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'components.dart';

class IntroPreferences {
  static const key = 'errandly_intro_seen_v1';
  Future<bool> hasSeen() async =>
      await SharedPreferencesAsync().getBool(key) ?? false;
  Future<void> markSeen() => SharedPreferencesAsync().setBool(key, true);
}

/// The welcome screen appears immediately after a completed or skipped intro.
class IntroGate extends StatefulWidget {
  const IntroGate({
    super.key,
    required this.child,
    this.enabled = true,
    this.preferences,
  });
  final Widget child;
  final bool enabled;
  final IntroPreferences? preferences;

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  late final preferences = widget.preferences ?? IntroPreferences();
  bool? _seen;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      unawaited(_load());
    } else {
      _seen = true;
    }
  }

  Future<void> _load() async {
    var seen = false;
    try {
      seen = await preferences.hasSeen().timeout(const Duration(seconds: 1));
    } catch (_) {
      // Storage restrictions must never prevent entering the app.
    }
    if (mounted && _seen != true) setState(() => _seen = seen);
  }

  void _finish() {
    if (_seen == true) return;
    setState(() => _seen = true);
    unawaited(_save());
  }

  Future<void> _save() async {
    try {
      await preferences.markSeen().timeout(const Duration(seconds: 1));
    } catch (_) {
      // A private browser can still use the app without persistent storage.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_seen == true) return widget.child;
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finish();
      });
      return widget.child;
    }
    if (_seen == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7FAF5),
        body: Center(child: Brand(size: 100)),
      );
    }
    return IntroVideo(onFinished: _finish);
  }
}

Future<void> replayIntro(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            IntroVideo(onFinished: () => Navigator.of(context).pop()),
      ),
    );

class IntroVideo extends StatefulWidget {
  const IntroVideo({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<IntroVideo> createState() => _IntroVideoState();
}

class _IntroVideoState extends State<IntroVideo>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _video;
  late final AnimationController _animation;
  Timer? _watchdog;
  bool _started = false;
  bool _finished = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _animation =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && !_ready) _finish();
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _animation.forward();
    _watchdog = Timer(const Duration(seconds: 8), _finish);
    final portrait =
        MediaQuery.sizeOf(context).height > MediaQuery.sizeOf(context).width;
    _video = VideoPlayerController.asset(
      'assets/videos/errandly-intro-${portrait ? 'portrait' : 'landscape'}.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..addListener(_onVideoChanged);
    unawaited(_play());
  }

  Future<void> _play() async {
    final video = _video!;
    try {
      await video.initialize().timeout(const Duration(seconds: 3));
      if (!mounted || _finished) return;
      await video.setVolume(0);
      await video.play();
      if (mounted && !_finished) setState(() => _ready = true);
    } catch (_) {
      // The matching native animation covers unsupported codecs/platforms.
    }
  }

  void _onVideoChanged() {
    if (!mounted || _finished) return;
    final value = _video!.value;
    if (value.isCompleted) {
      _finish();
    } else if (value.hasError && _ready) {
      setState(() => _ready = false);
      if (_animation.isCompleted) _finish();
    }
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    _watchdog?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _animation.dispose();
    _video?.removeListener(_onVideoChanged);
    unawaited(_video?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF5),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready)
            Center(
              child: AspectRatio(
                aspectRatio: _video!.value.aspectRatio,
                child: VideoPlayer(_video!),
              ),
            )
          else
            Center(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  final reveal = reduced
                      ? 1.0
                      : Curves.easeOut.transform(
                          (_animation.value * 3).clamp(0, 1),
                        );
                  return Opacity(
                    opacity: reveal,
                    child: Transform.scale(
                      scale: .94 + .06 * reveal,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/brand/errandly-logo.png',
                            width:
                                MediaQuery.sizeOf(context).shortestSide * .48,
                            semanticLabel: 'Errandly',
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Everyday help. Anywhere.',
                            style: TextStyle(color: teal, fontSize: 17),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip intro'),
                  ),
                  const Spacer(),
                  Center(
                    child: TextButton.icon(
                      onPressed: _finish,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Continue to Errandly'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
