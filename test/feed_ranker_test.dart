import 'package:flutter_test/flutter_test.dart';

import 'package:a_messenger/auth/auth_repository.dart';
import 'package:a_messenger/auth/mock_auth_repository.dart';
import 'package:a_messenger/data/feed_ranker.dart';
import 'package:a_messenger/data/mock/mock_wall_repository.dart';

void main() {
  setUpAll(() {
    authRepository = MockAuthRepository();
  });
  group('textSimilarity', () {
    test('пересечение слов даёт похожесть > 0', () {
      final s = textSimilarity(
        'Выбираю резину на ниву для грязи',
        'Прокачал ниву: багажник на крышу',
      );
      expect(s, greaterThan(0));
    });

    test('разные тексты — около нуля, пустые — ноль', () {
      expect(textSimilarity('казино вечером', 'резина грязь нива'), 0);
      expect(textSimilarity('', 'что-то'), 0);
    });
  });

  group('feedScore', () {
    final now = DateTime(2026, 7, 15, 12);

    test('свежий пост выигрывает у старого при прочих равных', () {
      final fresh = feedScore(
        createdAt: now.subtract(const Duration(hours: 1)),
        likedAuthor: false,
        reactionCount: 0,
        similarity: 0,
        now: now,
      );
      final old = feedScore(
        createdAt: now.subtract(const Duration(days: 5)),
        likedAuthor: false,
        reactionCount: 0,
        similarity: 0,
        now: now,
      );
      expect(fresh, greaterThan(old));
    });

    test('лайкнутый автор и похожесть перевешивают свежесть', () {
      final freshStranger = feedScore(
        createdAt: now,
        likedAuthor: false,
        reactionCount: 0,
        similarity: 0,
        now: now,
      );
      final oldButRelevant = feedScore(
        createdAt: now.subtract(const Duration(days: 2)),
        likedAuthor: true,
        reactionCount: 3,
        similarity: 0.3,
        now: now,
      );
      expect(oldButRelevant, greaterThan(freshStranger));
    });
  });

  group('MockWallRepository: лента рекомендаций', () {
    test('лента не содержит моих постов', () async {
      final repo = MockWallRepository();
      await repo.createPost('мой собственный пост');
      final feed = await repo.watchFeed().first;
      expect(feed.any((p) => p.mine), isFalse);
      final mine = await repo.watchMine().first;
      expect(mine.any((p) => p.text == 'мой собственный пост'), isTrue);
    });

    test('«Ага!» посту про ниву поднимает второй пост того же автора',
        () async {
      final repo = MockWallRepository();
      // Лайкаем пост Кирпича про ниву (p3).
      await repo.toggleAga('p3');
      final feed = await repo.watchFeed().first;

      final ids = feed.map((p) => p.id).toList();
      // Второй пост Кирпича (p4, тоже про ниву) обгоняет пост-ровесник
      // про казино (p5) и более свежий lorem-пост (p2).
      expect(ids.indexOf('p4'), lessThan(ids.indexOf('p5')));
      expect(ids.indexOf('p4'), lessThan(ids.indexOf('p2')));
    });
  });
}
