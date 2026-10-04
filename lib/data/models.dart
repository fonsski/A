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

/// Тип вложения. [voice] — голосовое сообщение, [circle] — видеокружок.
enum AttachmentKind { image, video, file, voice, circle }

String attachmentEmoji(AttachmentKind kind) => switch (kind) {
  AttachmentKind.image => '📷',
  AttachmentKind.video => '🎬',
  AttachmentKind.file => '📎',
  AttachmentKind.voice => '🎤',
  AttachmentKind.circle => '⭕',
};

/// Превью для списка чатов: «📷 Фото» или «📷 подпись», если она есть.
String attachmentPreview(AttachmentKind kind, [String caption = '']) {
  final label = switch (kind) {
    AttachmentKind.image => 'Фото',
    AttachmentKind.video => 'Видео',
    AttachmentKind.file => 'Файл',
    AttachmentKind.voice => 'Голосовое сообщение',
    AttachmentKind.circle => 'Видеосообщение',
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
    this.duration,
    this.waveform,
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

  /// Длительность голосового/кружка.
  final Duration? duration;

  /// Столбики волны голосового: значения 0..[kWaveformMax].
  final List<int>? waveform;

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

/// Максимальное значение столбика волны.
const kWaveformMax = 31;

/// «00:07» — длительность голосового или кружка.
String formatDuration(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final sec = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$sec';
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

/// Реакция на пост или комментарий: «Ага!» (А) или дизлайк (∀).
/// Пользователь может поставить только одну из двух.
enum PostReaction { aga, dislike }

class Comment {
  const Comment({
    required this.id,
    required this.authorName,
    required this.text,
    this.imageAsset,
    this.authorAvatarUrl,
    this.parentId,
    this.createdAt,
    this.agaCount = 0,
    this.dislikeCount = 0,
    this.myReaction,
    this.canDelete = false,
  });

  final String id;
  final String authorName;
  final String text;
  final String? imageAsset;
  final String? authorAvatarUrl;

  /// id комментария, на который это — ответ (null — комментарий к посту).
  final String? parentId;
  final DateTime? createdAt;
  final int agaCount;
  final int dislikeCount;
  final PostReaction? myReaction;

  /// Автор комментария или владелец стены.
  final bool canDelete;
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
    required this.mine,
    this.dislikeCount = 0,
    this.myReaction,
    this.comments = const <Comment>[],
    this.authorAvatarUrl,
    this.canDelete = false,
    this.repostOfId,
    this.original,
  });

  final String id;
  final String ownerId;
  final String authorName;
  final String authorUsername;
  final String text;
  final DateTime createdAt;
  final int agaCount; // реакции «Ага!»
  final int dislikeCount; // дизлайки (∀)
  final PostReaction? myReaction;
  final bool mine;
  final List<Comment> comments;
  final String? authorAvatarUrl;

  /// Я автор записи или владелец стены, на которой она лежит.
  final bool canDelete;

  /// Если запись — репост: id оригинала и сам оригинал. Оригинал null,
  /// когда он удалён или скрыт приватностью («запись недоступна»).
  final String? repostOfId;
  final Post? original;

  bool get myAga => myReaction == PostReaction.aga;
  bool get myDislike => myReaction == PostReaction.dislike;
  bool get isRepost => repostOfId != null;
}

/// Ветка комментариев: комментарий и его ответы, вложенные по уровням.
class CommentNode {
  CommentNode(this.comment);

  final Comment comment;
  final replies = <CommentNode>[];

  /// Сколько комментариев в этой ветке, включая корень.
  int get size => 1 + replies.fold(0, (sum, r) => sum + r.size);
}

/// Собирает плоский список комментариев в деревья по [Comment.parentId].
/// Порядок — как во входном списке (старые первыми); ответы на
/// пропавшего родителя поднимаются на верхний уровень.
List<CommentNode> buildCommentTree(List<Comment> comments) {
  final nodes = {for (final c in comments) c.id: CommentNode(c)};
  final roots = <CommentNode>[];
  for (final c in comments) {
    final parent = c.parentId == null ? null : nodes[c.parentId];
    (parent?.replies ?? roots).add(nodes[c.id]!);
  }
  return roots;
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
