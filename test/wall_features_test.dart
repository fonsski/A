import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/auth/auth_repository.dart';
import 'package:a_messenger/auth/mock_auth_repository.dart';
import 'package:a_messenger/data/mock/mock_wall_repository.dart';
import 'package:a_messenger/data/models.dart';

Comment _c(String id, {String? parent}) =>
    Comment(id: id, authorName: 'A', text: id, parentId: parent);

void main() {
  setUpAll(() async {
    authRepository = MockAuthRepository();
    await authRepository.signIn(identifier: 'demo@a.ru', password: 'password1');
  });

  group('buildCommentTree', () {
    test('ответы вкладываются в родителя, порядок сохраняется', () {
      final tree = buildCommentTree([
        _c('a'),
        _c('b', parent: 'a'),
        _c('c', parent: 'b'),
        _c('d'),
        _c('e', parent: 'a'),
      ]);
      expect(tree.map((n) => n.comment.id), ['a', 'd']);
      expect(tree.first.replies.map((n) => n.comment.id), ['b', 'e']);
      expect(tree.first.replies.first.replies.single.comment.id, 'c');
      expect(tree.first.size, 4);
    });

    test('ответ на пропавшего родителя поднимается наверх', () {
      final tree = buildCommentTree([_c('x', parent: 'gone'), _c('y')]);
      expect(tree.map((n) => n.comment.id), ['x', 'y']);
    });
  });

  group('MockWallRepository', () {
    late MockWallRepository repo;

    setUp(() => repo = MockWallRepository());

    Future<Post> post(String id) async =>
        (await repo.watchPost(id).first) as Post;

    test('«Ага!» и дизлайк взаимоисключающи, повтор снимает', () async {
      final before = await post('p2'); // у p2 одна «Ага!» в демо-данных
      await repo.toggleAga('p2');
      var p = await post('p2');
      expect(p.myAga, isTrue);
      expect(p.agaCount, before.agaCount + 1);

      await repo.toggleDislike('p2'); // заменяет «Ага!»
      p = await post('p2');
      expect(p.myDislike, isTrue);
      expect(p.myAga, isFalse);
      expect(p.agaCount, before.agaCount);
      expect(p.dislikeCount, 1);

      await repo.toggleDislike('p2'); // снимает
      p = await post('p2');
      expect(p.myReaction, isNull);
      expect(p.dislikeCount, 0);
    });

    test('репост появляется в «Моё!» с оригиналом и подписью', () async {
      await repo.repost('p3', comment: 'жиза');
      final mine = await repo.watchMine().first;
      final repost = mine.firstWhere((p) => p.isRepost);
      expect(repost.text, 'жиза');
      expect(repost.repostOfId, 'p3');
      expect(repost.original?.authorUsername, 'kirpich');
      expect(repost.canDelete, isTrue);
    });

    test('репост репоста ведёт к исходной записи', () async {
      await repo.repost('p3');
      final first = (await repo.watchMine().first).firstWhere(
        (p) => p.isRepost,
      );
      await repo.repost(first.id);
      final reposts = (await repo.watchMine().first).where((p) => p.isRepost);
      expect(reposts.every((p) => p.repostOfId == 'p3'), isTrue);
      expect(reposts.length, 2);
    });

    test('удаление исходника оставляет репост «недоступным»', () async {
      await repo.repost('p2');
      await repo.deletePost('p2');
      final repost = (await repo.watchMine().first).firstWhere(
        (p) => p.isRepost,
      );
      expect(repost.original, isNull);
      expect(repost.repostOfId, 'p2');
    });

    test(
      'ответ на комментарий образует ветку, реакции на комментарий',
      () async {
        await repo.addComment('p2', 'корень');
        var p = await post('p2');
        final root = p.comments.single;
        await repo.addComment('p2', 'ответ', parentId: root.id);
        p = await post('p2');
        final tree = buildCommentTree(p.comments);
        expect(tree.single.replies.single.comment.text, 'ответ');

        await repo.toggleCommentReaction(root.id, PostReaction.aga);
        await repo.toggleCommentReaction(root.id, PostReaction.dislike);
        p = await post('p2');
        final updated = p.comments.firstWhere((c) => c.id == root.id);
        expect(updated.myReaction, PostReaction.dislike);
        expect(updated.agaCount, 0);
        expect(updated.dislikeCount, 1);
      },
    );

    test('удаление комментария каскадом убирает ответы', () async {
      await repo.addComment('p2', 'корень');
      final root = (await post('p2')).comments.single;
      await repo.addComment('p2', 'ответ', parentId: root.id);
      await repo.deleteComment(root.id);
      expect((await post('p2')).comments, isEmpty);
    });
  });
}
