import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/data/mock/mock_chat_repository.dart';
import 'package:a_messenger/data/models.dart';
import 'package:a_messenger/media/voice_player.dart';
import 'package:a_messenger/media/wav_tone.dart';
import 'package:a_messenger/media/waveform.dart';

import 'fakes.dart';

Message _voice(String id, {Duration? duration, String? url}) => Message(
  id: id,
  chatId: 'c1',
  text: '',
  sentAt: DateTime(2026, 7, 18, 12),
  mine: false,
  attachmentKind: AttachmentKind.voice,
  attachmentUrl:
      url ??
      'data:audio/wav;base64,${base64Encode(generateDemoWav(const Duration(seconds: 1)))}',
  duration: duration ?? const Duration(seconds: 7),
);

class _ThrowingBackend extends FakeAudioBackend {
  @override
  Future<void> playUrl(String url) => Future.error('нет сети');
}

void main() {
  group('форматы', () {
    test('formatDuration — минуты:секунды', () {
      expect(formatDuration(const Duration(seconds: 7)), '00:07');
      expect(formatDuration(const Duration(minutes: 2, seconds: 5)), '02:05');
      expect(formatDuration(Duration.zero), '00:00');
    });

    test('normalizeDb: тишина → 0, громко → 1', () {
      expect(normalizeDb(-160), 0);
      expect(normalizeDb(-50), 0);
      expect(normalizeDb(0), 1);
      expect(normalizeDb(-25), closeTo(0.5, 1e-9));
    });
  });

  group('buildWaveform', () {
    test('нет данных — ровная тихая полоска нужной длины', () {
      expect(buildWaveform(const [], bars: 10), List.filled(10, 2));
    });

    test('усредняет уровни в столбики и держится в пределах 2..31', () {
      final wave = buildWaveform([
        for (var i = 0; i < 100; i++) i < 50 ? 0.0 : 1.0,
      ], bars: 10);
      expect(wave, hasLength(10));
      expect(wave.first, 2); // тишина — минимальный столбик
      expect(wave.last, kWaveformMax);
      expect(wave.every((v) => v >= 2 && v <= kWaveformMax), isTrue);
    });

    test('коротких данных меньше, чем столбиков, хватает', () {
      expect(buildWaveform([0.5], bars: 8), hasLength(8));
    });

    test('demoWaveform детерминирована и в пределах диапазона', () {
      expect(demoWaveform(7), demoWaveform(7));
      expect(demoWaveform(7), isNot(demoWaveform(8)));
      expect(demoWaveform(7).every((v) => v >= 3 && v <= kWaveformMax), isTrue);
    });
  });

  group('generateDemoWav', () {
    test('корректный WAV-заголовок и размер', () {
      final wav = generateDemoWav(const Duration(seconds: 2));
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(wav.length, 44 + 2 * 8000);
    });
  });

  group('VoicePlayerController', () {
    late FakeAudioBackend backend;
    late VoicePlayerController player;

    setUp(() {
      backend = FakeAudioBackend();
      player = VoicePlayerController(backend);
    });

    tearDown(() => player.dispose());

    test('toggle запускает новое сообщение и ставит на паузу/дальше', () async {
      final m = _voice('v1');
      expect(await player.toggle(m, title: 'Viktor'), isTrue);
      expect(player.isCurrent('v1'), isTrue);
      expect(player.playing, isTrue);
      expect(player.title, 'Viktor');
      expect(backend.log.last, startsWith('bytes:'));
      expect(backend.log.last, endsWith(':audio/wav'));

      await player.toggle(m);
      expect(player.playing, isFalse);
      expect(backend.log.last, 'pause');

      await player.toggle(m);
      expect(player.playing, isTrue);
      expect(backend.log.last, 'resume');
    });

    test('другое сообщение останавливает предыдущее', () async {
      await player.toggle(_voice('v1'));
      await player.toggle(_voice('v2'));
      expect(player.currentId, 'v2');
      expect(backend.log, contains('stop'));
    });

    test('позиция и прогресс идут от движка', () async {
      await player.toggle(_voice('v1', duration: const Duration(seconds: 10)));
      backend.positions.add(const Duration(seconds: 5));
      await Future<void>.delayed(Duration.zero);
      expect(player.position, const Duration(seconds: 5));
      expect(player.progressOf('v1'), closeTo(0.5, 1e-9));
      expect(player.progressOf('другое'), 0);
    });

    test('конец записи закрывает плеер', () async {
      await player.toggle(_voice('v1'));
      backend.completions.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(player.currentId, isNull);
      expect(player.playing, isFalse);
    });

    test('seekFraction перематывает только текущее', () async {
      await player.toggle(_voice('v1', duration: const Duration(seconds: 10)));
      await player.seekFraction('v1', 0.3);
      expect(backend.log.last, 'seek:3000');
      await player.seekFraction('чужое', 0.9);
      expect(backend.log.last, 'seek:3000');
    });

    test('ошибка движка: false и плеер сброшен', () async {
      final broken = VoicePlayerController(_ThrowingBackend());
      final ok = await broken.toggle(
        _voice('v1', url: 'https://example.com/a.webm'),
      );
      expect(ok, isFalse);
      expect(broken.currentId, isNull);
      broken.dispose();
    });

    test('togglePause работает по текущему, stop сбрасывает', () async {
      await player.toggle(_voice('v1'));
      await player.togglePause();
      expect(player.playing, isFalse);
      await player.stop();
      expect(player.currentId, isNull);
    });
  });

  group('MockChatRepository: голосовые', () {
    test('sendAttachment(voice) хранит длительность и волну', () async {
      final repo = MockChatRepository();
      await repo.sendAttachment(
        'c3',
        Uint8List.fromList([1, 2, 3]),
        'audio/webm',
        'voice.webm',
        AttachmentKind.voice,
        duration: const Duration(seconds: 4),
        waveform: const [3, 9, 20],
      );
      final last = (await repo.watchMessages('c3').first).last;
      expect(last.attachmentKind, AttachmentKind.voice);
      expect(last.duration, const Duration(seconds: 4));
      expect(last.waveform, [3, 9, 20]);
      final chat = (await repo.watchChats().first).firstWhere(
        (c) => c.id == 'c3',
      );
      expect(chat.lastText, 'Me: 🎤 Голосовое сообщение');
    });

    test('демо-чат содержит проигрываемое голосовое', () async {
      final messages = await MockChatRepository().watchMessages('c1').first;
      final voice = messages.firstWhere(
        (m) => m.attachmentKind == AttachmentKind.voice,
      );
      expect(voice.duration, const Duration(seconds: 7));
      expect(voice.attachmentUrl, startsWith('data:audio/wav;base64,'));
    });
  });
}
