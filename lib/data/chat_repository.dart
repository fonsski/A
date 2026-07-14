import 'dart:typed_data';

import 'models.dart';

/// Контракт чатов 1:1.
abstract class ChatRepository {
  /// Список чатов, отсортированный по последнему сообщению.
  /// Шлёт текущее значение новым подписчикам.
  Stream<List<ChatSummary>> watchChats();

  /// Сообщения чата от старых к новым.
  Stream<List<Message>> watchMessages(String chatId);

  Future<void> sendMessage(String chatId, String text);

  /// Отправляет фото (Storage, бакет chat-media).
  Future<void> sendImage(String chatId, Uint8List bytes, String mimeType);

  /// Сбрасывает счётчик непрочитанных.
  Future<void> markRead(String chatId);

  /// Поиск людей по @нику или имени (без текущего пользователя).
  Future<List<UserSummary>> searchUsers(String query);

  /// Возвращает id диалога с [peer]: существующего или созданного.
  Future<String> startDm(UserSummary peer);
}

/// Назначается в main() до runApp (мок или Supabase).
late final ChatRepository chatRepository;
