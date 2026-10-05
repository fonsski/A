import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../wall_repository.dart';
import 'snapshot_stream.dart';

/// Стенка поверх Supabase: посты с вложенными комментариями и реакциями,
/// realtime-подписка обновляет ленту при любых изменениях.
class SupabaseWallRepository implements WallRepository {
  SupabaseWallRepository() : _client = Supabase.instance.client {
    final channel = _client.channel('wall-feed');
    for (final table in [
      'posts',
      'comments',
      'reactions',
      'comment_reactions',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _refresh(),
      );
    }
    channel.subscribe();
  }

  final SupabaseClient _client;
  final _controller = StreamController<List<Post>>.broadcast();
  List<Post>? _last;
  var _feedScores = <String, double>{};

  String get _uid => _client.auth.currentUser!.id;

  Future<void> _refresh() async {
    // Скоры рекомендаций считает БД (feed_for_me, см. fix_005).
    // Любая ошибка здесь не должна ломать саму выдачу постов.
    try {
      final scored = await _client.rpc<dynamic>('feed_for_me');
      _feedScores = {
        if (scored is List)
          for (final r in scored.whereType<Map<String, dynamic>>())
            r['post_id'] as String: (r['score'] as num?)?.toDouble() ?? 0,
      };
    } catch (_) {
      _feedScores = {};
    }
    try {
      await _refreshPosts();
    } catch (e) {
      // Показываем ошибку в UI вместо вечно пустого экрана.
      _controller.addError(e);
    }
  }

  Future<void> _refreshPosts() async {
    final rows = await _client
        .from('posts')
        .select('''
          id, wall_owner_id, author_id, body, repost_of, created_at,
          author:profiles!posts_author_id_fkey(username, display_name, avatar_url),
          comments(id, body, image_url, parent_id, author_id, created_at,
                   author:profiles!comments_author_id_fkey(username, display_name, avatar_url),
                   comment_reactions(user_id, kind)),
          reactions(user_id, kind)
        ''')
        .order('created_at', ascending: false);

    // Оригиналы репостов берём из тех же строк: что не пришло — для меня
    // скрыто приватностью (RLS), и такая запись покажется «недоступной».
    final byId = {for (final r in rows) r['id'] as String: r};
    _last = [for (final r in rows) _toPost(r, byId)];
    _controller.add(_last!);
  }

  /// (сколько «Ага!», сколько дизлайков, моя реакция) по строкам реакций.
  (int, int, PostReaction?) _tally(List<dynamic> reactions) {
    var aga = 0;
    var dislike = 0;
    PostReaction? mine;
    for (final x in reactions.cast<Map<String, dynamic>>()) {
      final kind = x['kind'] == 'dislike'
          ? PostReaction.dislike
          : PostReaction.aga;
      kind == PostReaction.aga ? aga++ : dislike++;
      if (x['user_id'] == _uid) mine = kind;
    }
    return (aga, dislike, mine);
  }

  Post _toPost(
    Map<String, dynamic> r,
    Map<String, Map<String, dynamic>> byId, {
    bool withOriginal = true,
  }) {
    final author = (r['author'] ?? const {}) as Map<String, dynamic>;
    final (aga, dislike, mine) = _tally((r['reactions'] as List?) ?? const []);
    final comments =
        ((r['comments'] as List?) ?? const []).cast<Map<String, dynamic>>()
          ..sort(
            (a, b) => (a['created_at'] as String).compareTo(
              b['created_at'] as String,
            ),
          );
    final repostOfId = r['repost_of'] as String?;
    final originalRow = repostOfId == null ? null : byId[repostOfId];
    final isOwner = r['wall_owner_id'] == _uid;
    return Post(
      id: r['id'] as String,
      ownerId: r['wall_owner_id'] as String,
      authorName:
          (author['display_name'] ?? author['username'] ?? 'Кто-то') as String,
      authorUsername: (author['username'] ?? '') as String,
      text: r['body'] as String,
      createdAt: DateTime.parse(r['created_at'] as String),
      agaCount: aga,
      dislikeCount: dislike,
      myReaction: mine,
      mine: isOwner,
      canDelete: isOwner || r['author_id'] == _uid,
      authorAvatarUrl: author['avatar_url'] as String?,
      repostOfId: repostOfId,
      original: withOriginal && originalRow != null
          ? _toPost(originalRow, byId, withOriginal: false)
          : null,
      comments: [
        for (final c in comments)
          () {
            final cAuthor = (c['author'] ?? const {}) as Map<String, dynamic>;
            final (cAga, cDislike, cMine) = _tally(
              (c['comment_reactions'] as List?) ?? const [],
            );
            return Comment(
              id: c['id'] as String,
              authorName:
                  (cAuthor['display_name'] ?? cAuthor['username'] ?? 'Кто-то')
                      as String,
              text: c['body'] as String,
              authorAvatarUrl: cAuthor['avatar_url'] as String?,
              parentId: c['parent_id'] as String?,
              createdAt: DateTime.parse(c['created_at'] as String),
              agaCount: cAga,
              dislikeCount: cDislike,
              myReaction: cMine,
              canDelete: isOwner || c['author_id'] == _uid,
            );
          }(),
      ],
    );
  }

  /// Лента «А?»: чужие посты по убыванию скора рекомендаций.
  List<Post> _rankedFeed(List<Post> posts) {
    return posts.where((p) => !p.mine).toList()..sort((a, b) {
      final cmp = (_feedScores[b.id] ?? 0).compareTo(_feedScores[a.id] ?? 0);
      return cmp != 0 ? cmp : b.createdAt.compareTo(a.createdAt);
    });
  }

  Stream<List<Post>> _all() => snapshotThenUpdates(
    _controller.stream,
    snapshot: () => _last,
    afterSubscribe: () => unawaited(_refresh()),
  );

  @override
  Stream<List<Post>> watchFeed() => snapshotThenUpdates(
    _controller.stream.map(_rankedFeed),
    snapshot: () => _last == null ? null : _rankedFeed(_last!),
    afterSubscribe: () => unawaited(_refresh()),
  );

  @override
  Stream<List<Post>> watchMine() =>
      _all().map((posts) => posts.where((p) => p.mine).toList());

  @override
  Stream<List<Post>> watchWallOf(String userId) =>
      _all().map((posts) => posts.where((p) => p.ownerId == userId).toList());

  @override
  Stream<Post?> watchPost(String postId) =>
      _all().map((posts) => posts.where((p) => p.id == postId).firstOrNull);

  @override
  Future<void> createPost(String text) async {
    await _client.from('posts').insert({
      'wall_owner_id': _uid,
      'author_id': _uid,
      'body': text,
    });
    await _refresh();
  }

  Future<void> _setPostReaction(String postId, PostReaction kind) async {
    final current = _last
        ?.where((p) => p.id == postId)
        .map((p) => p.myReaction)
        .firstOrNull;
    if (current == kind) {
      await _client
          .from('reactions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', _uid);
    } else {
      // upsert по первичному ключу (post_id, user_id) заменяет прежний вид.
      await _client.from('reactions').upsert({
        'post_id': postId,
        'user_id': _uid,
        'kind': kind.name,
      });
    }
    await _refresh();
  }

  @override
  Future<void> toggleAga(String postId) =>
      _setPostReaction(postId, PostReaction.aga);

  @override
  Future<void> toggleDislike(String postId) =>
      _setPostReaction(postId, PostReaction.dislike);

  @override
  Future<void> repost(String postId, {String comment = ''}) async {
    // Репост репоста ведёт к исходной записи, а не к цепочке.
    final target = _last?.where((p) => p.id == postId).firstOrNull;
    await _client.from('posts').insert({
      'wall_owner_id': _uid,
      'author_id': _uid,
      'body': comment.trim(),
      'repost_of': target?.repostOfId ?? postId,
    });
    await _refresh();
  }

  @override
  Future<void> deletePost(String postId) async {
    await _client.from('posts').delete().eq('id', postId);
    await _refresh();
  }

  @override
  Future<void> addComment(
    String postId,
    String text, {
    String? parentId,
  }) async {
    await _client.from('comments').insert({
      'post_id': postId,
      'author_id': _uid,
      'body': text,
      'parent_id': ?parentId,
    });
    await _refresh();
  }

  @override
  Future<void> toggleCommentReaction(
    String commentId,
    PostReaction kind,
  ) async {
    final current = _last
        ?.expand((p) => p.comments)
        .where((c) => c.id == commentId)
        .map((c) => c.myReaction)
        .firstOrNull;
    if (current == kind) {
      await _client
          .from('comment_reactions')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', _uid);
    } else {
      await _client.from('comment_reactions').upsert({
        'comment_id': commentId,
        'user_id': _uid,
        'kind': kind.name,
      });
    }
    await _refresh();
  }

  @override
  Future<void> deleteComment(String commentId) async {
    await _client.from('comments').delete().eq('id', commentId);
    await _refresh();
  }
}
