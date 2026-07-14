import 'dart:async';

import '../../auth/auth_repository.dart';
import '../models.dart';
import '../wall_repository.dart';

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

  @override
  Stream<List<Post>> watchFeed() async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Stream<List<Post>> watchMine() async* {
    yield _snapshot.where((p) => p.mine).toList();
    yield* _controller.stream
        .map((posts) => posts.where((p) => p.mine).toList());
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
