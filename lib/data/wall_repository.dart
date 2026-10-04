import 'models.dart';

/// Контракт «Стенки».
abstract class WallRepository {
  /// Лента «А?» — все доступные посты (приватность решает бэкенд).
  Stream<List<Post>> watchFeed();

  /// Вкладка «Моё!» — посты на моей стене.
  Stream<List<Post>> watchMine();

  /// Стена конкретного пользователя (видимость решает бэкенд).
  Stream<List<Post>> watchWallOf(String userId);

  /// Один пост со всеми комментариями (экран ветки); null — пост пропал
  /// или недоступен.
  Stream<Post?> watchPost(String postId);

  Future<void> createPost(String text);

  /// Ставит/снимает «Ага!». Если стоял дизлайк — заменяет его.
  Future<void> toggleAga(String postId);

  /// Ставит/снимает дизлайк (∀). Если стояла «Ага!» — заменяет её.
  Future<void> toggleDislike(String postId);

  /// Репостит запись на мою стену, [comment] — необязательная подпись.
  Future<void> repost(String postId, {String comment = ''});

  /// Удаляет запись (автор или владелец стены).
  Future<void> deletePost(String postId);

  /// Комментарий к посту; [parentId] — ответ на другой комментарий.
  Future<void> addComment(String postId, String text, {String? parentId});

  /// Реакция на комментарий, те же правила, что у постов.
  Future<void> toggleCommentReaction(String commentId, PostReaction kind);

  Future<void> deleteComment(String commentId);
}

/// Назначается в main() до runApp (мок или Supabase).
late final WallRepository wallRepository;
