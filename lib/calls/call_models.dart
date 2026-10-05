import '../data/models.dart';

/// Фаза звонка. [idle] — звонка нет и оверлей скрыт.
enum CallPhase { idle, outgoing, incoming, connecting, active, ended }

/// Почему звонок закончился (для подписи на экране после завершения).
enum CallEndReason {
  localHangup,
  remoteHangup,
  declined,
  busy,
  noAnswer,
  missed,
  failed,
  deviceError,
}

String callEndText(CallEndReason reason) => switch (reason) {
  CallEndReason.localHangup => 'Звонок завершён',
  CallEndReason.remoteHangup => 'Собеседник завершил звонок',
  CallEndReason.declined => 'Звонок отклонён',
  CallEndReason.busy => 'Собеседник занят',
  CallEndReason.noAnswer => 'Нет ответа',
  CallEndReason.missed => 'Пропущенный звонок',
  CallEndReason.failed => 'Не удалось соединиться',
  CallEndReason.deviceError => 'Нет доступа к микрофону или камере',
};

/// Тип служебного сообщения между участниками звонка.
enum SignalKind {
  invite, // звонящий → вызываемому: «звоню» (+ имя, видео/аудио)
  accept, // вызываемый принял
  decline, // вызываемый отклонил
  busy, // вызываемый уже в другом звонке
  cancel, // звонящий передумал, пока не ответили
  hangup, // любой из участников повесил трубку
  offer, // WebRTC SDP offer
  answer, // WebRTC SDP answer
  ice, // WebRTC ICE-кандидат
}

/// Служебное сообщение сигнализации звонка.
class CallSignal {
  const CallSignal({
    required this.callId,
    required this.from,
    required this.kind,
    this.payload = const {},
  });

  final String callId;

  /// id отправителя (в моке — id из справочника).
  final String from;
  final SignalKind kind;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'call_id': callId,
    'kind': kind.name,
    'payload': payload,
  };
}

/// ICE-кандидат WebRTC в нейтральном виде (без привязки к пакету).
class IceCandidateData {
  const IceCandidateData({
    required this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  });

  factory IceCandidateData.fromJson(Map<String, dynamic> json) =>
      IceCandidateData(
        candidate: json['candidate'] as String,
        sdpMid: json['sdpMid'] as String?,
        sdpMLineIndex: (json['sdpMLineIndex'] as num?)?.toInt(),
      );

  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  Map<String, dynamic> toJson() => {
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  };
}

/// Собеседник звонка: кто звонит или кому звоним.
UserSummary peerFromInvite(CallSignal signal) => UserSummary(
  id: signal.from,
  username: (signal.payload['username'] ?? '') as String,
  displayName: (signal.payload['name'] ?? 'Кто-то') as String,
  avatarUrl: signal.payload['avatar'] as String?,
);
