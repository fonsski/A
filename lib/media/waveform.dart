import 'dart:math' as math;

import '../data/models.dart';

/// Громкость в дБ (record отдаёт -160..0) → 0..1. Тише -50 дБ считаем тишиной.
double normalizeDb(double db) => ((db + 50) / 50).clamp(0.0, 1.0);

/// Сжимает уровни громкости (0..1, по одному на ~100 мс) в [bars] столбиков
/// 0..[kWaveformMax]. Без данных — ровная тихая полоска.
List<int> buildWaveform(List<double> levels, {int bars = 40}) {
  if (levels.isEmpty) return List.filled(bars, 2);
  final out = <int>[];
  for (var i = 0; i < bars; i++) {
    final from = (i * levels.length / bars).floor();
    final to = math.max(from + 1, ((i + 1) * levels.length / bars).ceil());
    final slice = levels.sublist(from, math.min(to, levels.length));
    final avg = slice.reduce((a, b) => a + b) / slice.length;
    out.add(math.max(2, (avg * kWaveformMax).round()));
  }
  return out;
}

/// Правдоподобная волна для демо-данных, детерминированная по [seed].
List<int> demoWaveform(int seed, {int bars = 40}) {
  final rnd = math.Random(seed);
  return [
    for (var i = 0; i < bars; i++)
      math.max(
        3,
        (kWaveformMax *
                (0.35 +
                    0.45 * math.sin(i / 3.2 + seed).abs() +
                    0.2 * rnd.nextDouble()))
            .round()
            .clamp(0, kWaveformMax),
      ),
  ];
}
