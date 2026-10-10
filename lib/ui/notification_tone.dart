import 'package:audioplayers/audioplayers.dart';

class NotificationTone {
  AudioPlayer? _player;
  Future<void> play() async {
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.play(
        AssetSource('audio/errandly-notification.wav'),
        volume: .55,
        ctx: AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
    } catch (_) {
      // Muted devices and browser autoplay restrictions must not block alerts.
    }
  }

  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
  }
}
