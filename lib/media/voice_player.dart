import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import 'audio_backend.dart';

/// Проигрыватель голосовых сообщений. Играет одно сообщение за раз; его
/// состояние слушают и пузырь в ленте, и плашка-плеер под шапкой чата.
class VoicePlayerController extends ChangeNotifier {
  VoicePlayerController(this._backend) {
    _subs = [
      _backend.onPosition.listen((p) {
        position = p;
        notifyListeners();
      }),
      _backend.onDuration.listen((d) {
        // Длительность из метаданных надёжнее присланной, но только если
        // у записи её нет (веб-запись часто отдаёт Infinity/0).
        if (d > Duration.zero && (total == null || total == Duration.zero)) {
          total = d;
          notifyListeners();
        }
      }),
      _backend.onComplete.listen((_) => _reset()),
    ];
  }

  final AudioBackend _backend;
  late final List<StreamSubscription<Object?>> _subs;

  /// id проигрываемого сообщения (на паузе тоже); null — ничего не открыто.
  String? currentId;
  String? chatId;

  /// Подпись плашки-плеера — имя автора голосового.
  String title = '';
  bool playing = false;
  Duration position = Duration.zero;
  Duration? total;

  bool isCurrent(String messageId) => currentId == messageId;

  /// Доля проигранного 0..1 для сообщения [messageId].
  double progressOf(String messageId) {
    if (currentId != messageId) return 0;
    final t = total?.inMilliseconds ?? 0;
    if (t <= 0) return 0;
    return (position.inMilliseconds / t).clamp(0.0, 1.0);
  }

  /// Play/пауза; другое сообщение останавливает предыдущее.
  /// Возвращает false, если файл не удалось воспроизвести.
  Future<bool> toggle(Message message, {String title = ''}) async {
    if (currentId == message.id) {
      if (playing) {
        await _backend.pause();
        playing = false;
      } else {
        await _backend.resume();
        playing = true;
      }
      notifyListeners();
      return true;
    }
    await _backend.stop();
    currentId = message.id;
    chatId = message.chatId;
    this.title = title;
    position = Duration.zero;
    total = message.duration;
    playing = true;
    notifyListeners();
    try {
      await _start(message.attachmentUrl!);
      return true;
    } catch (e) {
      debugPrint('Голосовое не воспроизвелось: $e');
      _reset();
      return false;
    }
  }

  Future<void> _start(String url) async {
    if (url.startsWith('data:')) {
      final comma = url.indexOf(',');
      final mime = url.substring(5, url.indexOf(';'));
      await _backend.playBytes(base64Decode(url.substring(comma + 1)), mime);
    } else if (url.startsWith('asset:')) {
      final data = await rootBundle.load(url.substring('asset:'.length));
      await _backend.playBytes(Uint8List.sublistView(data), 'audio/wav');
    } else {
      await _backend.playUrl(url);
    }
  }

  /// Пауза/продолжение уже открытого голосового (кнопка плашки-плеера).
  Future<void> togglePause() async {
    if (currentId == null) return;
    if (playing) {
      await _backend.pause();
    } else {
      await _backend.resume();
    }
    playing = !playing;
    notifyListeners();
  }

  /// Перемотка по доле полосы (тап по волне).
  Future<void> seekFraction(String messageId, double fraction) async {
    if (currentId != messageId) return;
    final t = total;
    if (t == null || t <= Duration.zero) return;
    position = t * fraction.clamp(0.0, 1.0);
    notifyListeners();
    await _backend.seek(position);
  }

  Future<void> stop() async {
    await _backend.stop();
    _reset();
  }

  void _reset() {
    currentId = null;
    chatId = null;
    playing = false;
    position = Duration.zero;
    total = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}

/// Назначается в main() до runApp (в тестах — с заглушкой движка).
late final VoicePlayerController voicePlayer;
