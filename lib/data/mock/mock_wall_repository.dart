import 'dart:async';

import '../../auth/auth_repository.dart';
import '../feed_ranker.dart';
import '../models.dart';
import '../wall_repository.dart';
import 'mock_directory.dart';

const _lorem =
    'Lorem Ipsum - это текст-"рыба", часто используемый в печати и '
    'вэб-дизайне. Lorem Ipsum является стандартной "рыбой" для текстов '
    'на латинице с начала XVI века.';

/// Счётчики «Ага!»/дизлайков и моя реакция — общие для постов и комментариев.
class _Reactable {
  _Reactable({this.agaCount = 0});

  int agaCount;
  int dislikeCount = 0;
  PostReaction? mine;

  /// Повтор той же реакции снимает её, другая — заменяет прежнюю.
  void toggle(PostReaction kind) {
    if (mine == kind) {
      _bump(kind, -1);
      mine = null;
      return;
    }
    if (mine != null) _bump(mine!, -1);
    _bump(kind, 1);
    mine = kind;
  }

  void _bump(PostReaction kind, int delta) {
    if (kind == PostReaction.aga) {
      agaCount += delta;
    } else {
      dislikeCount += delta;
    }
  }
}

class _MockComment extends _Reactable {
  _MockComment({
    required this.id,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.parentId,
    this.imageAsset,
  });

  final String id;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final String? parentId;
  final String? imageAsset;
}

class _MockPost extends _Reactable {
  _MockPost({
    required this.id,
    required this.authorName,
    required this.authorUsername,
    required this.text,
    required this.createdAt,
    super.agaCount,
    this.repostOf,
  });

  final String id;
  final String authorName;
  final String authorUsername;
  final String text;
  final DateTime createdAt;
  final String? repostOf;
  final comments = <_MockComment>[];
}

/// Стенка в памяти: мои посты + демо-лента.
class MockWallRepository implements WallRepository {
  MockWallRepository() {
    final now = DateTime.now();
    _posts.addAll([
      _MockPost(
          id: 'p1',
          authorName: 'Trofim More',
          authorUsername: 'trofim',
          text: _lorem,
          createdAt: now.subtract(const Duration(hours: 2)),
          agaCount: 3,
        )
        ..comments.addAll([
          _MockComment(
            id: 'cm1',
            authorName: 'Viktor Vozduh',
            text: 'Помогите лечением аутисту!',
            createdAt: now.subtract(const Duration(hours: 1, minutes: 40)),
            imageAsset: 'assets/images/post_photo.png',
          )..agaCount = 2,
          _MockComment(
            id: 'cm2',
            authorName: 'Sasha Kirpich',
            text: 'Скинемся всем миром',
            createdAt: now.subtract(const Duration(hours: 1, minutes: 20)),
            parentId: 'cm1',
          ),
        ]),
      _MockPost(
        id: 'p2',
        authorName: 'Viktor Vozdux',
        authorUsername: 'viktor',
        text: _lorem,
        createdAt: now.subtract(const Duration(hours: 5)),
        agaCount: 1,
      ),
      _MockPost(
        id: 'p3',
        authorName: 'Sasha Kirpich',
        authorUsername: 'kirpich',
        text:
            'Прокачал ниву: багажник на крышу, шноркель, силовые бамперы. '
            'Теперь можно в горы!',
        createdAt: now.subtract(const Duration(hours: 8)),
        agaCount: 2,
      ),
      _MockPost(
        id: 'p4',
        authorName: 'Sasha Kirpich',
        authorUsername: 'kirpich',
        text:
            'Выбираю резину на ниву для грязи, посоветуйте что-нибудь '
            'злое и вечное.',
        createdAt: now.subtract(const Duration(hours: 20)),
      ),
      _MockPost(
        id: 'p5',
        authorName: 'Viktor Dudovich',
        authorUsername: 'viktor.dud',
        text: 'Кто со мной в казино вечером? Красиво проиграем пару тысяч.',
        createdAt: now.subtract(const Duration(hours: 20)),
      ),
    ]);
  }

  final _posts = <_MockPost>[];
  final _controller = StreamController<List<Post>>.broadcast();
  var _nextId = 100;

  String get _myUsername => authRepository.current?.profile?.username ?? 'me';
  String get _myName =>
      authRepository.current?.profile?.displayName ?? _myUsername;

  bool _canDelete(String authorUsername, String ownerUsername) =>
      authorUsername == _myUsername || ownerUsername == _myUsername;

  Post _toPost(_MockPost p, {bool withOriginal = true}) {
    final original = p.repostOf == null || !withOriginal
        ? null
        : _posts
              .where((o) => o.id == p.repostOf)
              .map((o) => _toPost(o, withOriginal: false))
              .firstOrNull;
    return Post(
      id: p.id,
      ownerId: p.authorUsername,
      authorName: p.authorName,
      authorUsername: p.authorUsername,
      text: p.text,
      createdAt: p.createdAt,
      agaCount: p.agaCount,
      dislikeCount: p.dislikeCount,
      myReaction: p.mine,
      mine: p.authorUsername == _myUsername,
      canDelete: _canDelete(p.authorUsername, p.authorUsername),
      repostOfId: p.repostOf,
      original: original,
      comments: [
        for (final c in p.comments)
          Comment(
            id: c.id,
            authorName: c.authorName,
            text: c.text,
            imageAsset: c.imageAsset,
            parentId: c.parentId,
            createdAt: c.createdAt,
            agaCount: c.agaCount,
            dislikeCount: c.dislikeCount,
            myReaction: c.mine,
            canDelete:
                c.authorName == _myName || p.authorUsername == _myUsername,
          ),
      ],
    );
  }

  List<Post> get _snapshot =>
      _posts.map(_toPost).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  void _notify() => _controller.add(_snapshot);

  /// Лента «А?»: чужие посты, ранжированные по интересам
  /// (см. feed_ranker.dart — зеркало серверного feed_for_me).
  List<Post> _rankFeed(List<Post> posts) {
    final liked = posts.where((p) => p.myAga).toList();
    final corpus = liked.map((p) => p.text).join(' ');
    final likedAuthors = liked.map((p) => p.authorUsername).toSet();
    final scores = <String, double>{
      for (final p in posts)
        p.id: feedScore(
          createdAt: p.createdAt,
          likedAuthor: likedAuthors.contains(p.authorUsername),
          reactionCount: p.agaCount,
          similarity: textSimilarity(p.text, corpus),
        ),
    };
    return posts.where((p) => !p.mine).toList()
      ..sort((a, b) => scores[b.id]!.compareTo(scores[a.id]!));
  }

  @override
  Stream<List<Post>> watchFeed() async* {
    yield _rankFeed(_snapshot);
    yield* _controller.stream.map(_rankFeed);
  }

  @override
  Stream<List<Post>> watchMine() async* {
    yield _snapshot.where((p) => p.mine).toList();
    yield* _controller.stream.map(
      (posts) => posts.where((p) => p.mine).toList(),
    );
  }

  @override
  Stream<List<Post>> watchWallOf(String userId) {
    // В моке владелец стены — username автора; id из справочника.
    final username =
        mockUsers
            .where((u) => u.id == userId)
            .map((u) => u.username)
            .firstOrNull ??
        userId;
    List<Post> wall(List<Post> posts) =>
        posts.where((p) => p.ownerId == username).toList();
    Stream<List<Post>> source() async* {
      yield wall(_snapshot);
      yield* _controller.stream.map(wall);
    }

    return source();
  }

  @override
  Future<void> createPost(String text) async {
    _posts.add(
      _MockPost(
        id: 'p${_nextId++}',
        authorName: _myName,
        authorUsername: _myUsername,
        text: text,
        createdAt: DateTime.now(),
      ),
    );
    _notify();
  }

  _MockPost _post(String id) => _posts.firstWhere((p) => p.id == id);

  @override
  Stream<Post?> watchPost(String postId) {
    Post? find(List<Post> posts) =>
        posts.where((p) => p.id == postId).firstOrNull;
    Stream<Post?> source() async* {
      yield find(_snapshot);
      yield* _controller.stream.map(find);
    }

    return source();
  }

  @override
  Future<void> toggleAga(String postId) async {
    _post(postId).toggle(PostReaction.aga);
    _notify();
  }

  @override
  Future<void> toggleDislike(String postId) async {
    _post(postId).toggle(PostReaction.dislike);
    _notify();
  }

  @override
  Future<void> repost(String postId, {String comment = ''}) async {
    // Репост репоста ведёт к исходной записи, а не к цепочке.
    final target = _post(postId);
    _posts.add(
      _MockPost(
        id: 'p${_nextId++}',
        authorName: _myName,
        authorUsername: _myUsername,
        text: comment.trim(),
        createdAt: DateTime.now(),
        repostOf: target.repostOf ?? target.id,
      ),
    );
    _notify();
  }

  @override
  Future<void> deletePost(String postId) async {
    _posts.removeWhere((p) => p.id == postId);
    _notify();
  }

  @override
  Future<void> addComment(
    String postId,
    String text, {
    String? parentId,
  }) async {
    _post(postId).comments.add(
      _MockComment(
        id: 'cm${_nextId++}',
        authorName: _myName,
        text: text,
        createdAt: DateTime.now(),
        parentId: parentId,
      ),
    );
    _notify();
  }

  @override
  Future<void> toggleCommentReaction(
    String commentId,
    PostReaction kind,
  ) async {
    for (final p in _posts) {
      for (final c in p.comments) {
        if (c.id == commentId) c.toggle(kind);
      }
    }
    _notify();
  }

  @override
  Future<void> deleteComment(String commentId) async {
    for (final p in _posts) {
      // Ответы удаляются каскадом вместе с родителем.
      final doomed = {commentId};
      var grew = true;
      while (grew) {
        grew = false;
        for (final c in p.comments) {
          if (c.parentId != null &&
              doomed.contains(c.parentId) &&
              doomed.add(c.id)) {
            grew = true;
          }
        }
      }
      p.comments.removeWhere((c) => doomed.contains(c.id));
    }
    _notify();
  }
}
