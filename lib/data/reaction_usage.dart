import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Локальный счётчик использования реакций: чаще всего ставимые
/// эмодзи показываются в начале ряда, как в Telegram.
class ReactionUsage {
  ReactionUsage(this._prefs) {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      _counts.addAll(
        (jsonDecode(raw) as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      );
    }
  }

  static const _key = 'reaction_usage';

  final SharedPreferences _prefs;
  final _counts = <String, int>{};

  /// Отмечает, что пользователь поставил [emoji].
  Future<void> bump(String emoji) async {
    _counts[emoji] = (_counts[emoji] ?? 0) + 1;
    await _prefs.setString(_key, jsonEncode(_counts));
  }

  /// Набор реакций, отсортированный по частоте; редко используемые —
  /// в исходном порядке [kReactionEmojis].
  List<String> sorted() {
    final list = [...kReactionEmojis];
    final defaultIndex = {for (var i = 0; i < list.length; i++) list[i]: i};
    list.sort((a, b) {
      final byCount = (_counts[b] ?? 0).compareTo(_counts[a] ?? 0);
      return byCount != 0 ? byCount : defaultIndex[a]! - defaultIndex[b]!;
    });
    return list;
  }
}

/// Назначается в main() до runApp.
late final ReactionUsage reactionUsage;
