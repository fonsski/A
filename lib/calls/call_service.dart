import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models.dart';
import 'call_engine.dart';
import 'call_models.dart';
import 'call_signaling.dart';

/// Состояние и логика звонка 1:1: приглашение, ответ, обмен SDP/ICE через
/// [CallSignaling], медиа — через [CallEngine]. Экран звонка и «островок»
/// только слушают этот объект.
class CallService extends ChangeNotifier {
  CallService({
    required this.signaling,
    required this.engineFactory,
    required this.self,
    this.ringTimeout = const Duration(seconds: 45),
    this.endedDisplay = const Duration(seconds: 2),
    String Function()? newCallId,
  }) : _newCallId =
           newCallId ??
           (() => DateTime.now().microsecondsSinceEpoch.toString());

  final CallSignaling signaling;
  final CallEngine Function() engineFactory;

  /// Кто я — попадает в приглашение (имя и аватар на экране входящего).
  final UserSummary Function() self;
  final Duration ringTimeout;
  final Duration endedDisplay;
  final String Function() _newCallId;

  var phase = CallPhase.idle;
  UserSummary? peer;
  var video = false;
  String? callId;
  DateTime? startedAt;
  CallEndReason? endReason;

  var micOn = true;
  var camOn = false;
  var speakerOn = false;

  /// Звонок свёрнут в «островок» вместо полного экрана.
  var minimized = false;

  CallEngine? _engine;
  CallEngine? get engine => _engine;

  String _myId = '';
  StreamSubscription<CallSignal>? _signalSub;
  final _engineSubs = <StreamSubscription<Object?>>[];
  Timer? _ringTimer;
  Timer? _tickTimer;
  Timer? _endedTimer;
  // Сигналы обрабатываются строго по очереди: offer/ice зависят от порядка.
  final _pending = <CallSignal>[];
  var _draining = false;

  bool get inCall => phase != CallPhase.idle;

  Duration get elapsed =>
      startedAt == null ? Duration.zero : DateTime.now().difference(startedAt!);

  /// Подпись статуса под именем (кадры «Audio call» / «Video call»).
  String get statusText => switch (phase) {
    CallPhase.idle => '',
    CallPhase.outgoing => 'Звоним…',
    CallPhase.incoming => video ? 'Входящий видеозвонок' : 'Входящий звонок',
    CallPhase.connecting => 'Соединение…',
    CallPhase.active => formatDuration(elapsed),
    CallPhase.ended => callEndText(endReason ?? CallEndReason.localHangup),
  };

  /// Начинает слушать входящие звонки (после входа в аккаунт).
  Future<void> attach(String myUserId) async {
    _myId = myUserId;
    unawaited(_signalSub?.cancel()); // ждать отписки незачем
    await signaling.start();
    _signalSub = signaling.incoming.listen(_enqueue);
  }

  /// Перестаёт слушать (выход из аккаунта); активный звонок обрывается.
  Future<void> detach() async {
    if (inCall && phase != CallPhase.ended) await hangup();
    unawaited(_signalSub?.cancel());
    _signalSub = null;
    await signaling.stop();
  }

  void _enqueue(CallSignal signal) {
    _pending.add(signal);
    if (!_draining) _drain();
  }

  Future<void> _drain() async {
    _draining = true;
    while (_pending.isNotEmpty) {
      try {
        await _onSignal(_pending.removeAt(0));
      } catch (e) {
        debugPrint('Сигнал звонка не обработан: $e');
      }
    }
    _draining = false;
  }

  // ── исходящий ────────────────────────────────────────────────────────────

  Future<void> startCall(UserSummary to, {required bool withVideo}) async {
    if (inCall) return;
    final id = _newCallId();
    callId = id;
    peer = to;
    video = withVideo;
    micOn = true;
    camOn = withVideo;
    speakerOn = withVideo;
    minimized = false;
    startedAt = null;
    endReason = null;
    phase = CallPhase.outgoing;
    notifyListeners();

    if (!await _openEngine(withVideo)) {
      _end(CallEndReason.deviceError);
      return;
    }
    if (callId != id || phase != CallPhase.outgoing) return; // уже отменили

    final me = self();
    await _send(
      CallSignal(
        callId: id,
        from: _myId,
        kind: SignalKind.invite,
        payload: {
          'video': withVideo,
          'name': me.displayName,
          'username': me.username,
          'avatar': me.avatarUrl,
        },
      ),
    );
    _ringTimer = Timer(ringTimeout, () {
      if (phase == CallPhase.outgoing) {
        _send(_signal(SignalKind.cancel));
        _end(CallEndReason.noAnswer);
      }
    });
  }

  // ── входящий ─────────────────────────────────────────────────────────────

  Future<void> accept() async {
    if (phase != CallPhase.incoming) return;
    _ringTimer?.cancel();
    micOn = true;
    camOn = video;
    speakerOn = video;
    phase = CallPhase.connecting;
    notifyListeners();
    if (!await _openEngine(video)) {
      await _send(_signal(SignalKind.decline));
      _end(CallEndReason.deviceError);
      return;
    }
    await _send(_signal(SignalKind.accept));
  }

  Future<void> decline() async {
    if (phase != CallPhase.incoming) return;
    await _send(_signal(SignalKind.decline));
    _end(CallEndReason.declined, show: false);
  }

  /// Завершить звонок в любой фазе (для входящего — отклонить).
  Future<void> hangup() async {
    switch (phase) {
      case CallPhase.idle || CallPhase.ended:
        return;
      case CallPhase.incoming:
        return decline();
      case CallPhase.outgoing:
        await _send(_signal(SignalKind.cancel));
      case CallPhase.connecting || CallPhase.active:
        await _send(_signal(SignalKind.hangup));
    }
    _end(CallEndReason.localHangup);
  }

  // ── управление звонком ───────────────────────────────────────────────────

  void toggleMic() {
    micOn = !micOn;
    _engine?.setMicEnabled(micOn);
    notifyListeners();
  }

  /// Камера доступна только в видеозвонке: добавить видео в идущий
  /// аудиозвонок нельзя (потребовало бы пересогласования соединения).
  bool toggleCamera() {
    if (!video) return false;
    camOn = !camOn;
    _engine?.setCameraEnabled(camOn);
    notifyListeners();
    return true;
  }

  Future<void> toggleSpeaker() async {
    speakerOn = !speakerOn;
    notifyListeners();
    await _engine?.setSpeaker(speakerOn);
  }

  Future<void> switchCamera() async => _engine?.switchCamera();

  void setMinimized(bool value) {
    if (minimized == value) return;
    minimized = value;
    notifyListeners();
  }

  // ── внутренности ─────────────────────────────────────────────────────────

  CallSignal _signal(
    SignalKind kind, [
    Map<String, dynamic> payload = const {},
  ]) => CallSignal(callId: callId!, from: _myId, kind: kind, payload: payload);

  Future<void> _send(CallSignal signal) async {
    final to = peer?.id;
    if (to == null) return;
    try {
      await signaling.send(to, signal);
    } catch (e) {
      debugPrint('Сигнал звонка не отправился: $e');
    }
  }

  Future<bool> _openEngine(bool withVideo) async {
    final engine = engineFactory();
    try {
      await engine.open(video: withVideo);
    } catch (e) {
      debugPrint('Медиа для звонка недоступно: $e');
      await engine.close();
      return false;
    }
    _engine = engine;
    _engineSubs
      ..add(
        engine.iceCandidates.listen(
          (c) => _send(_signal(SignalKind.ice, c.toJson())),
        ),
      )
      ..add(engine.connection.listen(_onConnection))
      ..add(engine.remoteChanged.listen((_) => notifyListeners()));
    await engine.setSpeaker(speakerOn);
    return true;
  }

  void _onConnection(bool connected) {
    if (connected) {
      if (phase == CallPhase.connecting) {
        phase = CallPhase.active;
        startedAt = DateTime.now();
        _tickTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => notifyListeners(),
        );
        notifyListeners();
      }
    } else if (phase == CallPhase.connecting || phase == CallPhase.active) {
      _send(_signal(SignalKind.hangup));
      _end(CallEndReason.failed);
    }
  }

  Future<void> _onSignal(CallSignal signal) async {
    if (signal.kind == SignalKind.invite) {
      if (phase != CallPhase.idle && phase != CallPhase.ended) {
        // Занят: сообщаем звонящему, свой звонок не трогаем.
        try {
          await signaling.send(
            signal.from,
            CallSignal(
              callId: signal.callId,
              from: _myId,
              kind: SignalKind.busy,
            ),
          );
        } catch (_) {}
        return;
      }
      _reset(silent: true);
      callId = signal.callId;
      peer = peerFromInvite(signal);
      video = signal.payload['video'] == true;
      endReason = null;
      minimized = false;
      phase = CallPhase.incoming;
      _ringTimer = Timer(ringTimeout, () {
        if (phase == CallPhase.incoming) {
          _end(CallEndReason.missed, show: false);
        }
      });
      notifyListeners();
      return;
    }
    if (signal.callId != callId || !inCall) return;

    switch (signal.kind) {
      case SignalKind.accept:
        if (phase != CallPhase.outgoing || _engine == null) return;
        _ringTimer?.cancel();
        phase = CallPhase.connecting;
        notifyListeners();
        final sdp = await _engine!.createOffer();
        await _send(_signal(SignalKind.offer, {'sdp': sdp}));
      case SignalKind.decline:
        _end(CallEndReason.declined);
      case SignalKind.busy:
        _end(CallEndReason.busy);
      case SignalKind.cancel:
        if (phase == CallPhase.incoming) {
          _end(CallEndReason.missed, show: false);
        }
      case SignalKind.hangup:
        _end(CallEndReason.remoteHangup);
      case SignalKind.offer:
        if (_engine == null || phase != CallPhase.connecting) return;
        final answer = await _engine!.acceptOffer(
          signal.payload['sdp'] as String,
        );
        await _send(_signal(SignalKind.answer, {'sdp': answer}));
      case SignalKind.answer:
        await _engine?.acceptAnswer(signal.payload['sdp'] as String);
      case SignalKind.ice:
        await _engine?.addIceCandidate(
          IceCandidateData.fromJson(signal.payload),
        );
      case SignalKind.invite:
        break; // обработано выше
    }
  }

  /// Завершает звонок. [show] — на пару секунд показать причину на экране.
  void _end(CallEndReason reason, {bool show = true}) {
    if (phase == CallPhase.idle || phase == CallPhase.ended) return;
    _ringTimer?.cancel();
    _tickTimer?.cancel();
    _closeEngine();
    endReason = reason;
    if (!show) {
      _reset();
      return;
    }
    phase = CallPhase.ended;
    notifyListeners();
    _endedTimer = Timer(endedDisplay, _reset);
  }

  void _closeEngine() {
    for (final sub in _engineSubs) {
      sub.cancel();
    }
    _engineSubs.clear();
    final engine = _engine;
    _engine = null;
    engine?.close();
  }

  void _reset({bool silent = false}) {
    _endedTimer?.cancel();
    _ringTimer?.cancel();
    _tickTimer?.cancel();
    _closeEngine();
    phase = CallPhase.idle;
    peer = null;
    callId = null;
    startedAt = null;
    minimized = false;
    if (!silent) notifyListeners();
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _tickTimer?.cancel();
    _endedTimer?.cancel();
    _signalSub?.cancel();
    _closeEngine();
    super.dispose();
  }
}

/// Назначается в main() до runApp.
late CallService callService;
