import 'models.dart';

/// Контракт «Стенки».
abstract class WallRepository {
  /// Лента «А?» — все доступные посты (приватность решает бэкенд).
  Stream<List<Post>> watchFeed();

  /// Вкладка «Моё!» — посты на моей стене.
  Stream<List<Post>> watchMine();

  Future<void> createPost(String text);

  /// Ставит/снимает «Ага!».
  Future<void> toggleAga(String postId);

  Future<void> addComment(String postId, String text);
}

/// Назначается в main() до runApp (мок или Supabase).
late final WallRepository wallRepository;
