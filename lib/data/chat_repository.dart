import 'dart:typed_data';

import 'models.dart';

/// Контракт чатов 1:1.
abstract class ChatRepository {
  /// Список чатов, отсортированный по последнему сообщению.
  /// Шлёт текущее значение новым подписчикам.
  Stream<List<ChatSummary>> watchChats();

  /// Сообщения чата от старых к новым.
  Stream<List<Message>> watchMessages(String chatId);

  Future<void> sendMessage(String chatId, String text, {String? replyToId});

  /// «Удалить у всех» — только для своих сообщений.
  Future<void> deleteMessageForAll(String chatId, String messageId);

  /// «Удалить у себя» — скрывает сообщение только для меня.
  Future<void> hideMessageForMe(String chatId, String messageId);

  /// Отправляет вложение (Storage, бакет chat-media): фото, видео или файл,
  /// опционально с подписью.
  Future<void> sendAttachment(
    String chatId,
    Uint8List bytes,
    String mimeType,
    String filename,
    AttachmentKind kind, {
    String caption = '',
  });

  /// Сбрасывает счётчик непрочитанных.
  Future<void> markRead(String chatId);

  /// id закреплённого сообщения чата (null — ничего не закреплено).
  Stream<String?> watchPinned(String chatId);

  /// Закрепляет сообщение (+ системная отметка в ленте).
  Future<void> pinMessage(String chatId, String messageId);

  Future<void> unpin(String chatId);

  /// Очищает переписку у обеих сторон, оставляя системную отметку.
  Future<void> clearChat(String chatId);

  /// Удаляет чат целиком у обеих сторон.
  Future<void> deleteChat(String chatId);

  /// Поиск людей по @нику или имени (без текущего пользователя).
  Future<List<UserSummary>> searchUsers(String query);

  /// Возвращает id диалога с [peer]: существующего или созданного.
  Future<String> startDm(UserSummary peer);
}

/// Назначается в main() до runApp (мок или Supabase).
late final ChatRepository chatRepository;
