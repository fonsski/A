import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../calls/call_models.dart';
import '../calls/call_service.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

const _acceptGreen = Color(0xFF2E9E5B);

/// Накладывается поверх всего приложения (см. `MaterialApp.builder`):
/// полноэкранный звонок или свёрнутый «островок».
class CallOverlay extends StatelessWidget {
  const CallOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ListenableBuilder(
          listenable: callService,
          builder: (context, _) {
            if (!callService.inCall) return const SizedBox.shrink();
            // Входящий и «завершённый» всегда на весь экран.
            final island =
                callService.minimized &&
                callService.phase != CallPhase.incoming &&
                callService.phase != CallPhase.ended;
            return island ? const CallIsland() : const CallScreen();
          },
        ),
      ],
    );
  }
}

/// Круглая кнопка звонка: белая пилюля с красной иконкой и подписью.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = true,
    this.filled = false,
    this.fillColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// false — функция выключена (микрофон без звука и т.п.): красная заливка.
  final bool active;
  final bool filled;
  final Color? fillColor;

  static const size = 72.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final solid = filled || !active;
    final color = fillColor ?? colors.accent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: solid
                ? BoxDecoration(shape: BoxShape.circle, color: color)
                : pillDecoration(colors.surface, radius: size / 2),
            child: Icon(
              icon,
              size: 30,
              color: solid ? Colors.white : colors.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: colors.textPrimary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  void _toast(BuildContext context, String text) => ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: callService,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) {
    final colors = context.colors;
    final call = callService;
    final peer = call.peer;
    if (peer == null) return const SizedBox.shrink();
    final incoming = call.phase == CallPhase.incoming;
    final showVideo =
        call.video &&
        (call.phase == CallPhase.connecting || call.phase == CallPhase.active);

    return Material(
      color: colors.bg,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(21, 16, 21, 24),
              child: Column(
                children: [
                  if (!incoming && call.phase != CallPhase.ended)
                    GestureDetector(
                      onTap: () => call.setMinimized(true),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: pillDecoration(
                          colors.bubbleOut,
                          radius: 24,
                        ),
                        child: Text(
                          'Свернуть в островок',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 48),
                  Expanded(
                    child: showVideo
                        ? _VideoStage(peer: peer)
                        : _AudioStage(peer: peer),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      call.statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (incoming)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RoundAction(
                          icon: Icons.call_end,
                          label: 'Отклонить',
                          filled: true,
                          onTap: call.decline,
                        ),
                        _RoundAction(
                          icon: call.video ? Icons.videocam : Icons.call,
                          label: 'Принять',
                          filled: true,
                          fillColor: _acceptGreen,
                          onTap: call.accept,
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RoundAction(
                          icon: call.speakerOn
                              ? Icons.volume_up_outlined
                              : Icons.volume_down_outlined,
                          label: 'Звук',
                          onTap: call.phase == CallPhase.ended
                              ? null
                              : call.toggleSpeaker,
                        ),
                        _RoundAction(
                          icon: call.camOn
                              ? Icons.videocam_outlined
                              : Icons.videocam_off_outlined,
                          label: 'Камера',
                          active: call.video ? call.camOn : true,
                          onTap: call.phase == CallPhase.ended
                              ? null
                              : () {
                                  if (!call.toggleCamera()) {
                                    _toast(
                                      context,
                                      'Видео — только в видеозвонке: '
                                      'позвони кнопкой «Видео»',
                                    );
                                  }
                                },
                        ),
                        _RoundAction(
                          icon: call.micOn
                              ? Icons.mic_none_outlined
                              : Icons.mic_off_outlined,
                          label: 'Микрофон',
                          active: call.micOn,
                          onTap: call.phase == CallPhase.ended
                              ? null
                              : call.toggleMic,
                        ),
                        _RoundAction(
                          icon: Icons.call_end,
                          label: 'Завершить',
                          // В макете видеозвонка кнопка залита красным.
                          filled: call.video,
                          onTap: call.phase == CallPhase.ended
                              ? null
                              : call.hangup,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Аудиозвонок: большой круг с аватаром и именем (кадр «Audio call»).
class _AudioStage extends StatelessWidget {
  const _AudioStage({required this.peer});

  final UserSummary peer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, box) {
        final outer = math.min(math.min(box.maxWidth, box.maxHeight), 360.0);
        final avatar = outer * 0.67;
        return Center(
          child: Container(
            width: outer,
            height: outer,
            decoration: pillDecoration(colors.surface, radius: outer / 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.card, width: 4),
                  ),
                  child: AAvatar(size: avatar, url: peer.avatarUrl),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    peer.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Видеозвонок: картинка собеседника и своё превью в углу («Video call»).
class _VideoStage extends StatelessWidget {
  const _VideoStage({required this.peer});

  final UserSummary peer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final call = callService;
    final engine = call.engine;
    final remote = engine != null && engine.hasRemoteVideo
        ? engine.buildRemoteView()
        : ColoredBox(
            color: colors.card,
            child: Center(child: AAvatar(size: 120, url: peer.avatarUrl)),
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(child: remote),
        if (engine != null && call.camOn)
          Positioned(
            right: 0,
            bottom: 0,
            width: 120,
            height: 160,
            child: GestureDetector(
              onDoubleTap: call.switchCamera,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.textSecondary),
                ),
                child: engine.buildLocalView(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Свёрнутый звонок: капсула вверху экрана с именем, временем и «трубкой».
class CallIsland extends StatelessWidget {
  const CallIsland({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: callService,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) {
    final colors = context.colors;
    final call = callService;
    final peer = call.peer;
    if (peer == null) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      right: 16,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () => call.setMinimized(false),
              child: Container(
                height: 52,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                decoration: pillDecoration(colors.accent, radius: 26),
                child: Row(
                  children: [
                    AAvatar(size: 34, url: peer.avatarUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            peer.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.bg,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            call.statusText,
                            style: TextStyle(color: colors.bg, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: call.hangup,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.bg,
                        ),
                        child: Icon(
                          Icons.call_end,
                          size: 20,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
