import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Готовый видеокружок.
class RecordedCircle {
  const RecordedCircle({
    required this.bytes,
    required this.mimeType,
    required this.filename,
    required this.duration,
  });

  final Uint8List bytes;
  final String mimeType;
  final String filename;
  final Duration duration;
}

enum CameraOpen { ready, denied, unavailable }

/// Камера для записи видеокружков. Интерфейс — чтобы в тестах не трогать
/// настоящую камеру.
abstract class CircleCamera {
  Future<CameraOpen> open();

  /// Живая картинка камеры (квадратная область заполняется с обрезкой).
  Widget buildPreview(BuildContext context);

  bool get canSwitch;
  Future<void> switchCamera();

  Future<void> startRecording();

  /// Останавливает запись и отдаёт видео; null — запись не удалась.
  Future<RecordedCircle?> stopRecording();

  /// Освобождает камеру (останавливая запись, если она шла).
  Future<void> dispose();
}

/// Реализация на пакете `camera` (web, Windows, Android).
class CameraPackageCircleCamera implements CircleCamera {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  var _index = 0;
  final _clock = Stopwatch();

  @override
  bool get canSwitch => _cameras.length > 1;

  @override
  Future<CameraOpen> open() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return CameraOpen.unavailable;
      // Для кружков берём фронтальную камеру, если она есть.
      final front = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _index = front < 0 ? 0 : front;
      return await _init();
    } on CameraException catch (e) {
      debugPrint('Камера не открылась: ${e.code}');
      return e.code.toLowerCase().contains('denied')
          ? CameraOpen.denied
          : CameraOpen.unavailable;
    } catch (e) {
      debugPrint('Камера не открылась: $e');
      return CameraOpen.unavailable;
    }
  }

  Future<CameraOpen> _init() async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
    final controller = CameraController(
      _cameras[_index],
      ResolutionPreset.medium,
      enableAudio: true,
    );
    await controller.initialize();
    _controller = controller;
    return CameraOpen.ready;
  }

  @override
  Future<void> switchCamera() async {
    if (!canSwitch) return;
    _index = (_index + 1) % _cameras.length;
    await _init();
  }

  @override
  Widget buildPreview(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final aspect = controller.value.aspectRatio;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: 100 * aspect,
        height: 100,
        child: CameraPreview(controller),
      ),
    );
  }

  @override
  Future<void> startRecording() async {
    await _controller!.startVideoRecording();
    _clock
      ..reset()
      ..start();
  }

  @override
  Future<RecordedCircle?> stopRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isRecordingVideo) return null;
    _clock.stop();
    try {
      final file = await controller.stopVideoRecording();
      final bytes = await file.readAsBytes();
      final mime = kIsWeb ? 'video/webm' : 'video/mp4';
      final ext = kIsWeb ? 'webm' : 'mp4';
      return RecordedCircle(
        bytes: bytes,
        mimeType: mime,
        filename: 'circle_${DateTime.now().millisecondsSinceEpoch}.$ext',
        duration: _clock.elapsed,
      );
    } catch (e) {
      debugPrint('Кружок не записался: $e');
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    try {
      if (controller != null && controller.value.isRecordingVideo) {
        await controller.stopVideoRecording();
      }
    } catch (_) {}
    await controller?.dispose();
  }
}

/// Создаёт камеру под одну сессию записи. Назначается в main() до runApp;
/// в тестах возвращает заглушку.
late CircleCamera Function() circleCameraFactory;
