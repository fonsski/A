import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/models.dart';
import '../media/circle_camera.dart';
import '../theme.dart';
import 'common.dart';

/// Максимальная длина кружка, как в Telegram.
const kMaxCircleDuration = Duration(seconds: 60);
const kMinCircleDuration = Duration(seconds: 1);

/// Диалог записи кружка: живая картинка в круге, таймер, запись/стоп.
/// Возвращает запись по «стоп» (она же отправка) или null при отмене.
Future<RecordedCircle?> showCircleRecorder(BuildContext context) {
  return showDialog<RecordedCircle>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CircleRecorderDialog(),
  );
}

class _CircleRecorderDialog extends StatefulWidget {
  const _CircleRecorderDialog();

  @override
  State<_CircleRecorderDialog> createState() => _CircleRecorderDialogState();
}

class _CircleRecorderDialogState extends State<_CircleRecorderDialog> {
  final _camera = circleCameraFactory();
  final _clock = Stopwatch();
  Timer? _ticker;
  CameraOpen? _state;
  var _recording = false;
  var _closing = false;

  @override
  void initState() {
    super.initState();
    _camera.open().then((result) {
      if (!mounted) return;
      setState(() => _state = result);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_closing || _state != CameraOpen.ready) return;
    if (!_recording) {
      await _camera.startRecording();
      _clock
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (_clock.elapsed >= kMaxCircleDuration) {
          _finish();
        } else if (mounted) {
          setState(() {});
        }
      });
      if (mounted) setState(() => _recording = true);
    } else {
      await _finish();
    }
  }

  /// Стоп = отправка; слишком короткая запись отбрасывается.
  Future<void> _finish() async {
    if (_closing) return;
    _closing = true;
    _ticker?.cancel();
    _clock.stop();
    final circle = await _camera.stopRecording();
    if (!mounted) return;
    final tooShort = circle != null && circle.duration < kMinCircleDuration;
    if (tooShort) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Слишком коротко')));
    }
    Navigator.of(context).pop(tooShort ? null : circle);
  }

  Future<void> _cancel() async {
    _closing = true;
    _ticker?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = math.min(MediaQuery.sizeOf(context).width - 96, 280.0);
    final message = switch (_state) {
      CameraOpen.denied => 'Нет доступа к камере — разреши его в настройках',
      CameraOpen.unavailable => 'Камера здесь недоступна',
      _ => null,
    };
    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Видеосообщение',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.bg,
                border: Border.all(
                  color: _recording ? colors.accent : colors.card,
                  width: 3,
                ),
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: Colors.black12,
                  child: message != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          ),
                        )
                      : _state == CameraOpen.ready
                      ? _camera.buildPreview(context)
                      : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              formatDuration(_clock.elapsed),
              style: TextStyle(
                color: _recording ? colors.accent : colors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'Отмена',
                  icon: Icon(Icons.close, color: colors.textSecondary),
                  onPressed: _cancel,
                ),
                GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.accent, width: 3),
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _recording ? 24 : 44,
                      height: _recording ? 24 : 44,
                      decoration: BoxDecoration(
                        color: _state == CameraOpen.ready
                            ? colors.accent
                            : colors.textSecondary,
                        borderRadius: BorderRadius.circular(
                          _recording ? 6 : 22,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Сменить камеру',
                  icon: Icon(
                    Icons.cameraswitch_outlined,
                    color: _camera.canSwitch && !_recording
                        ? colors.textSecondary
                        : colors.card,
                  ),
                  onPressed: _camera.canSwitch && !_recording
                      ? () async {
                          await _camera.switchCamera();
                          if (mounted) setState(() {});
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _recording
                  ? 'Нажми ещё раз — отправим'
                  : 'Нажми круг, чтобы начать запись',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Видеокружок в ленте (кадр Chat): круг с кольцом, тап — play/пауза,
/// внизу две плашки — длительность и время отправки.
class CircleMessageView extends StatefulWidget {
  const CircleMessageView({super.key, required this.message});

  final Message message;

  @override
  State<CircleMessageView> createState() => _CircleMessageViewState();
}

class _CircleMessageViewState extends State<CircleMessageView> {
  static const _size = 180.0;

  VideoPlayerController? _video;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    final url = widget.message.attachmentUrl;
    // Играть умеем сетевое и data:-видео; демо-плейсхолдеры (asset:) — нет.
    if (url == null || url.startsWith('asset:')) {
      _failed = true;
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = controller;
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          controller.setLooping(false);
          controller.addListener(_onVideo);
          setState(() {});
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  void _onVideo() {
    final video = _video!;
    // Дошли до конца — возвращаемся к первому кадру.
    if (video.value.isInitialized &&
        !video.value.isPlaying &&
        video.value.position >= video.value.duration &&
        video.value.duration > Duration.zero) {
      video.seekTo(Duration.zero);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video
      ?..removeListener(_onVideo)
      ..dispose();
    super.dispose();
  }

  void _toggle() {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    video.value.isPlaying ? video.pause() : video.play();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final message = widget.message;
    final video = _video;
    final ready = video != null && video.value.isInitialized && !_failed;
    final playing = ready && video.value.isPlaying;
    final total = message.duration ?? (ready ? video.value.duration : null);
    final shownTime = ready && playing
        ? video.value.position
        : (total ?? Duration.zero);
    final progress = ready && video.value.duration > Duration.zero
        ? video.value.position.inMilliseconds /
              video.value.duration.inMilliseconds
        : 0.0;

    Widget content;
    if (ready) {
      content = FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: video.value.size.width,
          height: video.value.size.height,
          child: VideoPlayer(video),
        ),
      );
    } else if (message.attachmentUrl?.startsWith('asset:') ?? false) {
      content = Image(
        image: imageProviderFor(message.attachmentUrl!),
        fit: BoxFit.cover,
      );
    } else {
      content = ColoredBox(
        color: colors.card,
        child: Icon(
          _failed ? Icons.videocam_off_outlined : Icons.videocam_outlined,
          color: colors.textSecondary,
          size: 40,
        ),
      );
    }

    return Column(
      crossAxisAlignment: message.mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(
            width: _size + 16,
            height: _size + 16,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surface,
              boxShadow: const [
                BoxShadow(color: Color(0x1A000000), blurRadius: 4),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipOval(child: content),
                if (ready && playing)
                  CustomPaint(
                    painter: _ProgressRingPainter(progress, colors.accent),
                  ),
                if (!playing)
                  Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x66000000),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: _size + 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Pill(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatDuration(shownTime),
                      style: TextStyle(color: colors.accent, fontSize: 10),
                    ),
                    if (playing) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _Pill(
                child: Text(
                  message.mine
                      ? '${formatMessageStamp(message.sentAt)} АА'
                      : formatMessageStamp(message.sentAt),
                  style: TextStyle(color: colors.accent, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x33D9D9D9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(1.5),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress || old.color != color;
}
