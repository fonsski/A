import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../wall_repository.dart';

/// Стенка поверх Supabase: посты с вложенными комментариями и реакциями,
/// realtime-подписка обновляет ленту при любых изменениях.
class SupabaseWallRepository implements WallRepository {
  SupabaseWallRepository() : _client = Supabase.instance.client {
    final channel = _client.channel('wall-feed');
    for (final table in ['posts', 'comments', 'reactions']) {
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

  String get _uid => _client.auth.currentUser!.id;

  Future<void> _refresh() async {
    final rows = await _client.from('posts').select('''
          id, wall_owner_id, author_id, body, created_at,
          author:profiles!posts_author_id_fkey(username, display_name, avatar_url),
          comments(id, body, image_url, created_at,
                   author:profiles!comments_author_id_fkey(username, display_name, avatar_url)),
          reactions(user_id)
        ''').order('created_at', ascending: false);

    _last = [for (final r in rows) _toPost(r)];
    _controller.add(_last!);
  }

  Post _toPost(Map<String, dynamic> r) {
    final author = (r['author'] ?? const {}) as Map<String, dynamic>;
    final reactions = (r['reactions'] as List?) ?? const [];
    final comments = ((r['comments'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
      ..sort((a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String));
    return Post(
      id: r['id'] as String,
      authorName: (author['display_name'] ??
          author['username'] ??
          'Кто-то') as String,
      authorUsername: (author['username'] ?? '') as String,
      text: r['body'] as String,
      createdAt: DateTime.parse(r['created_at'] as String),
      agaCount: reactions.length,
      myAga: reactions.any((x) => x['user_id'] == _uid),
      mine: r['wall_owner_id'] == _uid,
      authorAvatarUrl: author['avatar_url'] as String?,
      comments: [
        for (final c in comments)
          Comment(
            id: c['id'] as String,
            authorName: ((c['author'] ?? const {})
                    as Map<String, dynamic>)['display_name'] as String? ??
                'Кто-то',
            text: c['body'] as String,
            authorAvatarUrl: ((c['author'] ?? const {})
                as Map<String, dynamic>)['avatar_url'] as String?,
          ),
      ],
    );
  }

  @override
  Stream<List<Post>> watchFeed() async* {
    if (_last != null) yield _last!;
    unawaited(_refresh());
    yield* _controller.stream;
  }

  @override
  Stream<List<Post>> watchMine() {
    Stream<List<Post>> source() async* {
      if (_last != null) yield _last!;
      unawaited(_refresh());
      yield* _controller.stream;
    }

    return source().map((posts) => posts.where((p) => p.mine).toList());
  }

  @override
  Future<void> createPost(String text) async {
    await _client.from('posts').insert({
      'wall_owner_id': _uid,
      'author_id': _uid,
      'body': text,
    });
    await _refresh();
  }

  @override
  Future<void> toggleAga(String postId) async {
    final mine = _last
        ?.where((p) => p.id == postId)
        .map((p) => p.myAga)
        .firstOrNull;
    if (mine == true) {
      await _client
          .from('reactions')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', _uid);
    } else {
      await _client
          .from('reactions')
          .upsert({'post_id': postId, 'user_id': _uid, 'kind': 'aga'});
    }
    await _refresh();
  }

  @override
  Future<void> addComment(String postId, String text) async {
    await _client.from('comments').insert({
      'post_id': postId,
      'author_id': _uid,
      'body': text,
    });
    await _refresh();
  }
}
