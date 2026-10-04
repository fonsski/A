import 'dart:async';
import 'dart:typed_data';

import 'package:a_messenger/media/audio_backend.dart';
import 'package:a_messenger/media/voice_recorder.dart';

/// Заглушка аудио-движка: ничего не играет, но позволяет тестам
/// управлять позицией и завершением.
class FakeAudioBackend implements AudioBackend {
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration>.broadcast();
  final completions = StreamController<void>.broadcast();
  final log = <String>[];

  @override
  Future<void> playBytes(Uint8List bytes, String mimeType) async =>
      log.add('bytes:${bytes.length}:$mimeType');

  @override
  Future<void> playUrl(String url) async => log.add('url:$url');

  @override
  Future<void> pause() async => log.add('pause');

  @override
  Future<void> resume() async => log.add('resume');

  @override
  Future<void> stop() async => log.add('stop');

  @override
  Future<void> seek(Duration position) async =>
      log.add('seek:${position.inMilliseconds}');

  @override
  Stream<Duration> get onPosition => positions.stream;

  @override
  Stream<Duration> get onDuration => durations.stream;

  @override
  Stream<void> get onComplete => completions.stream;
}

/// Заглушка рекордера: «записывает» заданную запись, без микрофона.
class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder({this.startResult = RecorderStart.started, this.voice});

  RecorderStart startResult;
  RecordedVoice? voice;
  var _recording = false;
  var cancelled = false;
  final _levels = StreamController<double>.broadcast();

  @override
  Stream<double> get levels => _levels.stream;

  @override
  bool get isRecording => _recording;

  @override
  Future<RecorderStart> start() async {
    if (startResult == RecorderStart.started) _recording = true;
    return startResult;
  }

  @override
  Future<RecordedVoice?> stop() async {
    _recording = false;
    return voice;
  }

  @override
  Future<void> cancel() async {
    _recording = false;
    cancelled = true;
  }
}
