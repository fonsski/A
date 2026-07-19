/// Доменные модели ленты и чатов. Чистый Dart, без зависимостей.
library;

class UserSummary {
  const UserSummary({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.peerName,
    required this.lastText,
    required this.lastAt,
    required this.unread,
    this.peerId,
    this.peerUsername,
    this.peerAvatarUrl,
  });

  final String id;
  final String peerName;
  final String lastText;
  final DateTime? lastAt;
  final int unread;
  final String? peerId;
  final String? peerUsername;
  final String? peerAvatarUrl;

  UserSummary get peer => UserSummary(
    id: peerId ?? '',
    username: peerUsername ?? '',
    displayName: peerName,
    avatarUrl: peerAvatarUrl,
  );
}

enum AttachmentKind { image, video, file }

String attachmentEmoji(AttachmentKind kind) => switch (kind) {
  AttachmentKind.image => '📷',
  AttachmentKind.video => '🎬',
  AttachmentKind.file => '📎',
};

/// Превью для списка чатов: «📷 Фото» или «📷 подпись», если она есть.
String attachmentPreview(AttachmentKind kind, [String caption = '']) {
  final label = switch (kind) {
    AttachmentKind.image => 'Фото',
    AttachmentKind.video => 'Видео',
    AttachmentKind.file => 'Файл',
  };
  return '${attachmentEmoji(kind)} ${caption.isEmpty ? label : caption}';
}

/// Тип сообщения: обычное или системное событие в ленте чата.
enum MessageKind { user, clear, pin }

class Message {
  const Message({
    required this.id,
    required this.chatId,
    required this.text,
    required this.sentAt,
    required this.mine,
    this.kind = MessageKind.user,
    this.replyToId,
    this.attachmentUrl,
    this.attachmentKind,
    this.attachmentName,
  });

  final String id;
  final String chatId;
  final String text;
  final DateTime sentAt;
  final bool mine;
  final MessageKind kind;

  /// id сообщения, на которое это — ответ.
  final String? replyToId;
  final String? attachmentUrl;
  final AttachmentKind? attachmentKind;
  final String? attachmentName;

  /// Короткое превью для плашек ответа/закрепа.
  String get preview =>
      attachmentKind != null ? attachmentPreview(attachmentKind!, text) : text;

  /// Текст системного сообщения («Вы очистили чат» и т.п.).
  String get systemText => switch (kind) {
    MessageKind.clear => mine ? 'Вы очистили чат' : 'Собеседник очистил чат',
    MessageKind.pin =>
      mine ? 'Вы закрепили сообщение' : 'Собеседник закрепил сообщение',
    MessageKind.user => text,
  };
}

/// Сводка одной реакции на сообщении: эмодзи, сколько поставило, моя ли.
class ReactionSummary {
  const ReactionSummary({
    required this.emoji,
    required this.count,
    required this.mine,
  });

  final String emoji;
  final int count;
  final bool mine;
}

/// Набор реакций по умолчанию, как в Telegram (кастомные — в планах).
const kReactionEmojis = [
  '👍',
  '👎',
  '❤️',
  '🔥',
  '🥰',
  '👏',
  '😁',
  '🤔',
  '🤯',
  '😱',
  '🤬',
  '😢',
  '🎉',
  '🤩',
  '🤮',
  '💩',
  '🙏',
  '👌',
  '🕊️',
  '🤡',
  '🥱',
  '🥴',
  '😍',
  '🐳',
  '❤️‍🔥',
  '🌚',
  '🌭',
  '💯',
  '🤣',
  '⚡',
  '🍌',
  '🏆',
  '💔',
  '🤨',
  '😐',
  '🍓',
  '🍾',
  '💋',
  '🖕',
  '😈',
];

final _linkRe = RegExp(r'https?://[^\s<>"]+');

/// Ссылки из текста сообщения (для вкладки «Ссылки» в инфо-чате).
List<String> extractLinks(String text) =>
    _linkRe.allMatches(text).map((m) => m.group(0)!).toList();

class Comment {
  const Comment({
    required this.id,
    required this.authorName,
    required this.text,
    this.imageAsset,
    this.authorAvatarUrl,
  });

  final String id;
  final String authorName;
  final String text;
  final String? imageAsset;
  final String? authorAvatarUrl;
}

class Post {
  const Post({
    required this.id,
    required this.ownerId, // владелец стены (в моке — username автора)
    required this.authorName,
    required this.authorUsername,
    required this.text,
    required this.createdAt,
    required this.agaCount,
    required this.myAga,
    required this.mine,
    this.comments = const <Comment>[],
    this.authorAvatarUrl,
  });

  final String id;
  final String ownerId;
  final String authorName;
  final String authorUsername;
  final String text;
  final DateTime createdAt;
  final int agaCount; // реакции «Ага!»
  final bool myAga;
  final bool mine;
  final List<Comment> comments;
  final String? authorAvatarUrl;
}

String formatTime(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final local = time.toLocal();
  if (now.difference(local).inDays >= 1 || now.day != local.day) {
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}';
  }
  return formatClock(local);
}

/// «12:35» — только время.
String formatClock(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

/// Штамп на пузыре: «12:35» у сегодняшних, «18.07 12:35» у старых.
String formatMessageStamp(DateTime time) {
  final local = time.toLocal();
  if (sameDay(local, DateTime.now())) return formatClock(local);
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')} ${formatClock(local)}';
}

const _monthsGenitive = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

bool sameDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// «Сегодня» / «Вчера» / «18 июля» / «18 июля 2025» — разделители дней.
String formatDayLabel(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  if (sameDay(local, now)) return 'Сегодня';
  if (sameDay(local, now.subtract(const Duration(days: 1)))) return 'Вчера';
  final base = '${local.day} ${_monthsGenitive[local.month - 1]}';
  return local.year == now.year ? base : '$base ${local.year}';
}

/// «в 12:35» / «вчера в 12:35» / «18 июля в 12:35» — последний визит.
String formatLastSeen(DateTime time) {
  final clock = formatClock(time);
  final day = formatDayLabel(time);
  return switch (day) {
    'Сегодня' => 'в $clock',
    'Вчера' => 'вчера в $clock',
    _ => '$day в $clock',
  };
}
