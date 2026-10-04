import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:record/record.dart';

import 'waveform.dart';

/// Готовая запись голосового.
class RecordedVoice {
  const RecordedVoice({
    required this.bytes,
    required this.mimeType,
    required this.filename,
    required this.duration,
    required this.waveform,
  });

  final Uint8List bytes;
  final String mimeType;
  final String filename;
  final Duration duration;
  final List<int> waveform;
}

enum RecorderStart { started, denied, unavailable }

/// Запись голосовых. Интерфейс — чтобы в тестах не трогать микрофон.
abstract class VoiceRecorder {
  Future<RecorderStart> start();

  /// Уровень громкости 0..1 примерно раз в 100 мс, пока идёт запись.
  Stream<double> get levels;

  bool get isRecording;

  /// Останавливает и отдаёт запись; null — запись не удалась.
  Future<RecordedVoice?> stop();

  /// Останавливает и выбрасывает запись.
  Future<void> cancel();
}

/// Реализация на пакете `record` (web, Windows, Android).
class RecordPackageVoiceRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();
  final _levels = StreamController<double>.broadcast();
  final _samples = <double>[];
  final _clock = Stopwatch();
  StreamSubscription<Amplitude>? _ampSub;
  AudioEncoder? _encoder;
  String? _path;
  var _recording = false;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  bool get isRecording => _recording;

  Future<AudioEncoder?> _pickEncoder() async {
    // Предпочитаем компактные кодеки; wav — запасной вариант.
    for (final e in [AudioEncoder.opus, AudioEncoder.aacLc, AudioEncoder.wav]) {
      if (await _recorder.isEncoderSupported(e)) return e;
    }
    return null;
  }

  static ({String ext, String mime}) _format(AudioEncoder e) => switch (e) {
    AudioEncoder.opus =>
      kIsWeb
          ? (ext: 'webm', mime: 'audio/webm')
          : (ext: 'opus', mime: 'audio/ogg'),
    AudioEncoder.aacLc => (ext: 'm4a', mime: 'audio/mp4'),
    _ => (ext: 'wav', mime: 'audio/wav'),
  };

  @override
  Future<RecorderStart> start() async {
    try {
      if (!await _recorder.hasPermission()) return RecorderStart.denied;
      final encoder = await _pickEncoder();
      if (encoder == null) return RecorderStart.unavailable;
      _encoder = encoder;
      final ext = _format(encoder).ext;
      _path = kIsWeb
          ? ''
          : '${Directory.systemTemp.path}/a_voice_'
                '${DateTime.now().millisecondsSinceEpoch}.$ext';
      _samples.clear();
      await _recorder.start(RecordConfig(encoder: encoder), path: _path!);
      _clock
        ..reset()
        ..start();
      _recording = true;
      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((a) {
            final level = normalizeDb(a.current);
            _samples.add(level);
            _levels.add(level);
          });
      return RecorderStart.started;
    } catch (e) {
      debugPrint('Запись не началась: $e');
      _recording = false;
      return RecorderStart.unavailable;
    }
  }

  @override
  Future<RecordedVoice?> stop() async {
    if (!_recording) return null;
    _recording = false;
    _clock.stop();
    await _ampSub?.cancel();
    try {
      final path = await _recorder.stop();
      if (path == null) return null;
      final bytes = await XFile(path).readAsBytes();
      if (!kIsWeb) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      final format = _format(_encoder ?? AudioEncoder.wav);
      return RecordedVoice(
        bytes: bytes,
        mimeType: format.mime,
        filename:
            'voice_${DateTime.now().millisecondsSinceEpoch}.${format.ext}',
        duration: _clock.elapsed,
        waveform: buildWaveform(_samples),
      );
    } catch (e) {
      debugPrint('Запись не сохранилась: $e');
      return null;
    }
  }

  @override
  Future<void> cancel() async {
    if (!_recording) return;
    _recording = false;
    _clock.stop();
    await _ampSub?.cancel();
    try {
      await _recorder.cancel();
    } catch (_) {}
  }
}

/// Назначается в main() до runApp (в тестах — заглушка).
late final VoiceRecorder voiceRecorder;
