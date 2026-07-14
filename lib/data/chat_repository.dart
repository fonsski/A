import 'models.dart';

/// Контракт чатов 1:1.
abstract class ChatRepository {
  /// Список чатов, отсортированный по последнему сообщению.
  /// Шлёт текущее значение новым подписчикам.
  Stream<List<ChatSummary>> watchChats();

  /// Сообщения чата от старых к новым.
  Stream<List<Message>> watchMessages(String chatId);

  Future<void> sendMessage(String chatId, String text);

  /// Сбрасывает счётчик непрочитанных.
  Future<void> markRead(String chatId);
}

/// Назначается в main() до runApp (мок или Supabase).
late final ChatRepository chatRepository;
