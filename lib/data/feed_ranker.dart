/// Ранжирование ленты «А?»: чем выше скор — тем выше пост.
///
/// Зеркалирует серверную функцию feed_for_me (supabase/fix_005):
/// свежесть + «я лайкал этого автора» + популярность + похожесть текста
/// на посты, которым пользователь ставил «Ага!».
library;

import 'dart:math';

double feedScore({
  required DateTime createdAt,
  required bool likedAuthor,
  required int reactionCount,
  required double similarity,
  bool friendAuthor = false,
  DateTime? now,
}) {
  final ageSeconds =
      (now ?? DateTime.now()).difference(createdAt).inSeconds.toDouble();
  return exp(-ageSeconds / 172800) // полураспад ~2 суток
      + (friendAuthor ? 2.0 : 0)
      + (likedAuthor ? 1.5 : 0)
      + 0.5 * log(1 + reactionCount)
      + 2.0 * similarity;
}

final _wordRe = RegExp(r'[a-zа-яё0-9]+');

Set<String> _tokens(String text) => _wordRe
    .allMatches(text.toLowerCase())
    .map((m) => m.group(0)!)
    .where((w) => w.length > 3)
    .toSet();

/// Похожесть текста на корпус лайкнутого: Жаккар по словам (0..1).
double textSimilarity(String text, String corpus) {
  final a = _tokens(text);
  final b = _tokens(corpus);
  if (a.isEmpty || b.isEmpty) return 0;
  final inter = a.intersection(b).length;
  return inter / (a.length + b.length - inter);
}
