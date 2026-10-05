import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_models.dart';

/// Медиа-часть звонка (микрофон, камера, соединение). Интерфейс — чтобы
/// сервис звонков тестировался без настоящего WebRTC.
abstract class CallEngine {
  /// Запрашивает микрофон (и камеру для видео) и готовит соединение.
  /// Бросает исключение, если доступа нет.
  Future<void> open({required bool video});

  Future<String> createOffer();

  /// Принимает чужой offer и возвращает answer.
  Future<String> acceptOffer(String sdp);

  Future<void> acceptAnswer(String sdp);

  Future<void> addIceCandidate(IceCandidateData candidate);

  /// Свои ICE-кандидаты, которые надо переслать собеседнику.
  Stream<IceCandidateData> get iceCandidates;

  /// true — медиа пошло, false — соединение потеряно.
  Stream<bool> get connection;

  /// Приходит ли от собеседника видео.
  bool get hasRemoteVideo;
  Stream<void> get remoteChanged;

  void setMicEnabled(bool enabled);
  void setCameraEnabled(bool enabled);
  Future<void> setSpeaker(bool enabled);
  Future<void> switchCamera();

  Widget buildLocalView();
  Widget buildRemoteView();

  Future<void> close();
}

/// Реализация на `flutter_webrtc` (web, Windows, Android).
class WebRtcCallEngine implements CallEngine {
  static const _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  RTCPeerConnection? _pc;
  MediaStream? _local;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  final _ice = StreamController<IceCandidateData>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  final _remoteChanged = StreamController<void>.broadcast();
  final _pendingIce = <IceCandidateData>[];
  var _remoteSet = false;
  var _video = false;
  var _hasRemoteVideo = false;

  @override
  Stream<IceCandidateData> get iceCandidates => _ice.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  bool get hasRemoteVideo => _hasRemoteVideo;

  @override
  Stream<void> get remoteChanged => _remoteChanged.stream;

  @override
  Future<void> open({required bool video}) async {
    _video = video;
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _local = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': video ? {'facingMode': 'user'} : false,
    });
    _localRenderer.srcObject = _local;

    final pc = await createPeerConnection(_config);
    _pc = pc;
    for (final track in _local!.getTracks()) {
      await pc.addTrack(track, _local!);
    }
    pc.onIceCandidate = (c) {
      final candidate = c.candidate;
      if (candidate == null || candidate.isEmpty) return;
      _ice.add(
        IceCandidateData(
          candidate: candidate,
          sdpMid: c.sdpMid,
          sdpMLineIndex: c.sdpMLineIndex,
        ),
      );
    };
    pc.onTrack = (event) {
      if (event.streams.isEmpty) return;
      _remoteRenderer.srcObject = event.streams.first;
      _hasRemoteVideo = event.streams.first.getVideoTracks().isNotEmpty;
      _remoteChanged.add(null);
    };
    pc.onConnectionState = (state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _connection.add(true);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _connection.add(false);
        default:
      }
    };
  }

  @override
  Future<String> createOffer() async {
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': _video,
    });
    await _pc!.setLocalDescription(offer);
    return offer.sdp!;
  }

  @override
  Future<String> acceptOffer(String sdp) async {
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    await _flushPendingIce();
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    return answer.sdp!;
  }

  @override
  Future<void> acceptAnswer(String sdp) async {
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    await _flushPendingIce();
  }

  Future<void> _flushPendingIce() async {
    _remoteSet = true;
    for (final c in _pendingIce) {
      await _addIce(c);
    }
    _pendingIce.clear();
  }

  Future<void> _addIce(IceCandidateData c) => _pc!.addCandidate(
    RTCIceCandidate(c.candidate, c.sdpMid, c.sdpMLineIndex),
  );

  @override
  Future<void> addIceCandidate(IceCandidateData candidate) async {
    // Кандидаты могут прийти раньше описания — копим, пока оно не задано.
    if (!_remoteSet) {
      _pendingIce.add(candidate);
      return;
    }
    await _addIce(candidate);
  }

  @override
  void setMicEnabled(bool enabled) {
    for (final t in _local?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = enabled;
    }
  }

  @override
  void setCameraEnabled(bool enabled) {
    for (final t in _local?.getVideoTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = enabled;
    }
  }

  @override
  Future<void> setSpeaker(bool enabled) async {
    // На вебе и десктопе вывод выбирает система; на телефоне — громкая связь.
    if (kIsWeb) return;
    try {
      await Helper.setSpeakerphoneOn(enabled);
    } catch (e) {
      debugPrint('Громкая связь не переключилась: $e');
    }
  }

  @override
  Future<void> switchCamera() async {
    final tracks = _local?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  @override
  Widget buildLocalView() => RTCVideoView(
    _localRenderer,
    mirror: true,
    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
  );

  @override
  Widget buildRemoteView() => RTCVideoView(
    _remoteRenderer,
    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
  );

  @override
  Future<void> close() async {
    _pendingIce.clear();
    for (final t in _local?.getTracks() ?? const <MediaStreamTrack>[]) {
      await t.stop();
    }
    await _local?.dispose();
    await _pc?.close();
    await _localRenderer.dispose();
    await _remoteRenderer.dispose();
    await _ice.close();
    await _connection.close();
    await _remoteChanged.close();
  }
}

/// Демо-движок без настоящего медиа: «соединяется» сразу после answer.
/// Для режима без Supabase и для тестов.
class MockCallEngine implements CallEngine {
  final _ice = StreamController<IceCandidateData>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  final _remoteChanged = StreamController<void>.broadcast();
  var _video = false;

  @override
  Stream<IceCandidateData> get iceCandidates => _ice.stream;

  @override
  Stream<bool> get connection => _connection.stream;

  @override
  bool get hasRemoteVideo => _video;

  @override
  Stream<void> get remoteChanged => _remoteChanged.stream;

  @override
  Future<void> open({required bool video}) async => _video = video;

  @override
  Future<String> createOffer() async => 'mock-offer';

  @override
  Future<String> acceptOffer(String sdp) async {
    scheduleMicrotask(() => _connection.add(true));
    return 'mock-answer';
  }

  @override
  Future<void> acceptAnswer(String sdp) async =>
      scheduleMicrotask(() => _connection.add(true));

  @override
  Future<void> addIceCandidate(IceCandidateData candidate) async {}

  @override
  void setMicEnabled(bool enabled) {}

  @override
  void setCameraEnabled(bool enabled) {}

  @override
  Future<void> setSpeaker(bool enabled) async {}

  @override
  Future<void> switchCamera() async {}

  @override
  Widget buildLocalView() => const ColoredBox(color: Color(0xFF455A64));

  @override
  Widget buildRemoteView() => const ColoredBox(color: Color(0xFF263238));

  @override
  Future<void> close() async {
    await _ice.close();
    await _connection.close();
    await _remoteChanged.close();
  }
}
