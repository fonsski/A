import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Тонкая обёртка над аудио-движком: контроллер плеера работает с ней, а в
/// тестах подставляется заглушка (в `flutter test` нет настоящего аудио).
abstract class AudioBackend {
  Future<void> playBytes(Uint8List bytes, String mimeType);
  Future<void> playUrl(String url);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);

  Stream<Duration> get onPosition;
  Stream<Duration> get onDuration;
  Stream<void> get onComplete;
}

/// Реализация на пакете `audioplayers` (web, Windows, Android).
class AudioplayersBackend implements AudioBackend {
  AudioplayersBackend() {
    _player.setReleaseMode(ReleaseMode.stop);
  }

  final _player = AudioPlayer();

  @override
  Future<void> playBytes(Uint8List bytes, String mimeType) =>
      _player.play(BytesSource(bytes, mimeType: mimeType));

  @override
  Future<void> playUrl(String url) => _player.play(UrlSource(url));

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Stream<Duration> get onPosition => _player.onPositionChanged;

  @override
  Stream<Duration> get onDuration => _player.onDurationChanged;

  @override
  Stream<void> get onComplete => _player.onPlayerComplete;
}
