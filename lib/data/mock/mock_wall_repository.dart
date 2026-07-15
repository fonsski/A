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

class _MockPost {
  _MockPost({
    required this.id,
    required this.authorName,
    required this.authorUsername,
    required this.text,
    required this.createdAt,
    this.agaCount = 0,
  });

  final String id;
  final String authorName;
  final String authorUsername;
  final String text;
  final DateTime createdAt;
  int agaCount;
  bool myAga = false;
  final comments = <Comment>[];
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
      )..comments.add(const Comment(
          id: 'cm1',
          authorName: 'Viktor Vozduh',
          text: 'Помогите лечением аутисту!',
          imageAsset: 'assets/images/post_photo.png',
        )),
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
        text: 'Прокачал ниву: багажник на крышу, шноркель, силовые бамперы. '
            'Теперь можно в горы!',
        createdAt: now.subtract(const Duration(hours: 8)),
        agaCount: 2,
      ),
      _MockPost(
        id: 'p4',
        authorName: 'Sasha Kirpich',
        authorUsername: 'kirpich',
        text: 'Выбираю резину на ниву для грязи, посоветуйте что-нибудь '
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

  String get _myUsername =>
      authRepository.current?.profile?.username ?? 'me';
  String get _myName =>
      authRepository.current?.profile?.displayName ?? _myUsername;

  List<Post> get _snapshot => _posts
      .map((p) => Post(
            id: p.id,
            ownerId: p.authorUsername,
            authorName: p.authorName,
            authorUsername: p.authorUsername,
            text: p.text,
            createdAt: p.createdAt,
            agaCount: p.agaCount,
            myAga: p.myAga,
            mine: p.authorUsername == _myUsername,
            comments: List.unmodifiable(p.comments),
          ))
      .toList()
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
    yield* _controller.stream
        .map((posts) => posts.where((p) => p.mine).toList());
  }

  @override
  Stream<List<Post>> watchWallOf(String userId) {
    // В моке владелец стены — username автора; id из справочника.
    final username = mockUsers
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
    _posts.add(_MockPost(
      id: 'p${_nextId++}',
      authorName: _myName,
      authorUsername: _myUsername,
      text: text,
      createdAt: DateTime.now(),
    ));
    _notify();
  }

  @override
  Future<void> toggleAga(String postId) async {
    final post = _posts.firstWhere((p) => p.id == postId);
    post.myAga = !post.myAga;
    post.agaCount += post.myAga ? 1 : -1;
    _notify();
  }

  @override
  Future<void> addComment(String postId, String text) async {
    _posts.firstWhere((p) => p.id == postId).comments.add(Comment(
          id: 'cm${_nextId++}',
          authorName: _myName,
          text: text,
        ));
    _notify();
  }
}
