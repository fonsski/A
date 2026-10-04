import 'package:flutter/material.dart';

import '../data/models.dart';
import '../media/voice_player.dart';
import '../theme.dart';
import 'common.dart';

/// Волна голосового: столбики, проигранная часть — акцентом.
class WaveformView extends StatelessWidget {
  const WaveformView({
    super.key,
    required this.bars,
    this.progress = 0,
    this.height = 20,
    this.activeColor,
    this.inactiveColor,
  });

  /// Значения 0..[kWaveformMax].
  final List<int> bars;

  /// Доля проигранного 0..1.
  final double progress;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _WaveformPainter(
        bars: bars,
        progress: progress,
        active: activeColor ?? colors.accent,
        inactive: inactiveColor ?? colors.accent.withValues(alpha: 0.28),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.active,
    required this.inactive,
  });

  final List<int> bars;
  final double progress;
  final Color active;
  final Color inactive;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final slot = size.width / bars.length;
    final barWidth = (slot * 0.55).clamp(1.0, 4.0);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;
    for (var i = 0; i < bars.length; i++) {
      final fraction = (bars[i] / kWaveformMax).clamp(0.12, 1.0);
      final barHeight = size.height * fraction;
      final x = slot * i + slot / 2;
      paint.color = (i + 0.5) / bars.length <= progress ? active : inactive;
      canvas.drawLine(
        Offset(x, (size.height - barHeight) / 2 + barWidth / 2),
        Offset(x, (size.height + barHeight) / 2 - barWidth / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.bars != bars || old.active != active;
}

/// Запись без волны (старые данные) рисуем ровной полоской.
final _flatBars = List<int>.filled(32, 6);

/// Голосовое сообщение в пузыре: play/pause, волна с перемоткой и длительность.
class VoiceMessageView extends StatelessWidget {
  const VoiceMessageView({
    super.key,
    required this.message,
    required this.title,
    this.onError,
  });

  final Message message;

  /// Подпись плашки-плеера (имя автора).
  final String title;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: voicePlayer,
      builder: (context, _) {
        final current = voicePlayer.isCurrent(message.id);
        final playing = current && voicePlayer.playing;
        final total = message.duration ?? voicePlayer.total ?? Duration.zero;
        final shown = current ? voicePlayer.position : total;
        return SizedBox(
          width: 190,
          child: Row(
            children: [
              GestureDetector(
                onTap: () async {
                  final ok = await voicePlayer.toggle(message, title: title);
                  if (!ok) onError?.call();
                },
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: colors.accent,
                  size: 34,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => voicePlayer.seekFraction(
                          message.id,
                          d.localPosition.dx / box.maxWidth,
                        ),
                        child: SizedBox(
                          height: 20,
                          child: WaveformView(
                            bars: message.waveform ?? _flatBars,
                            progress: voicePlayer.progressOf(message.id),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDuration(shown),
                      style: TextStyle(color: colors.accent, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Плашка-плеер под шапкой чата (кадр Chat: play, имя, время).
class VoicePlayerBar extends StatelessWidget {
  const VoicePlayerBar({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListenableBuilder(
      listenable: voicePlayer,
      builder: (context, _) {
        if (voicePlayer.chatId != chatId || voicePlayer.currentId == null) {
          return const SizedBox.shrink();
        }
        final total = voicePlayer.total ?? Duration.zero;
        final shown =
            voicePlayer.playing || voicePlayer.position > Duration.zero
            ? voicePlayer.position
            : total;
        return Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 0),
          child: GestureDetector(
            onTap: voicePlayer.togglePause,
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: pillDecoration(
                colors.surface,
                inset: const Offset(0, -2),
              ),
              child: Row(
                children: [
                  Icon(
                    voicePlayer.playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: colors.accent,
                    size: 22,
                  ),
                  Expanded(
                    child: Text(
                      voicePlayer.title,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    formatDuration(shown),
                    style: TextStyle(color: colors.accent, fontSize: 10),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: voicePlayer.stop,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
