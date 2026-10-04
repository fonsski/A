import 'dart:math' as math;
import 'dart:typed_data';

/// Моно 8-бит WAV с мелодичными «пиками» — демо-звук для голосовых в моке
/// (чтобы кнопка play в демо-режиме реально что-то играла).
Uint8List generateDemoWav(Duration length, {int sampleRate = 8000}) {
  final samples = (length.inMilliseconds * sampleRate / 1000).round();
  final data = Uint8List(44 + samples);
  final b = ByteData.sublistView(data);
  void tag(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data[offset + i] = s.codeUnitAt(i);
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + samples, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // моно
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate, Endian.little); // байт/с
  b.setUint16(32, 1, Endian.little);
  b.setUint16(34, 8, Endian.little);
  tag(36, 'data');
  b.setUint32(40, samples, Endian.little);

  const notes = [440.0, 523.25, 659.25, 587.33, 493.88];
  for (var i = 0; i < samples; i++) {
    final t = i / sampleRate;
    final noteIndex = (t * 3).floor() % notes.length;
    final local = (t * 3) - (t * 3).floorToDouble();
    final envelope = math.sin(math.pi * local); // плавное затухание нот
    final v = math.sin(2 * math.pi * notes[noteIndex] * t) * envelope;
    data[44 + i] = (128 + v * 90).round().clamp(0, 255);
  }
  return data;
}
