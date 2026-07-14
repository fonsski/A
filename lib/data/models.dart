/// Доменные модели ленты и чатов. Чистый Dart, без зависимостей.
library;

class UserSummary {
  const UserSummary({
    required this.id,
    required this.username,
    required this.displayName,
  });

  final String id;
  final String username;
  final String displayName;
}

class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.peerName,
    required this.lastText,
    required this.lastAt,
    required this.unread,
  });

  final String id;
  final String peerName;
  final String lastText;
  final DateTime? lastAt;
  final int unread;
}

class Message {
  const Message({
    required this.id,
    required this.chatId,
    required this.text,
    required this.sentAt,
    required this.mine,
  });

  final String id;
  final String chatId;
  final String text;
  final DateTime sentAt;
  final bool mine;
}

class Comment {
  const Comment({
    required this.id,
    required this.authorName,
    required this.text,
    this.imageAsset,
  });

  final String id;
  final String authorName;
  final String text;
  final String? imageAsset;
}

class Post {
  const Post({
    required this.id,
    required this.authorName,
    required this.authorUsername,
    required this.text,
    required this.createdAt,
    required this.agaCount,
    required this.myAga,
    required this.mine,
    this.comments = const <Comment>[],
  });

  final String id;
  final String authorName;
  final String authorUsername;
  final String text;
  final DateTime createdAt;
  final int agaCount; // реакции «Ага!»
  final bool myAga;
  final bool mine;
  final List<Comment> comments;
}

String formatTime(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final local = time.toLocal();
  if (now.difference(local).inDays >= 1 || now.day != local.day) {
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}';
  }
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
