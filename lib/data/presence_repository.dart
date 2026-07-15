import 'dart:async';

/// Кто сейчас в сети + «был(а) в сети» — с приватностью как в Telegram:
/// скрыл свой онлайн (настройка «Я») — не транслируешь себя и не видишь других.
abstract class PresenceRepository {
  Stream<Set<String>> watchOnline();

  Set<String> get online;

  /// Последний визит с учётом приватности; null — скрыт или неизвестен.
  Future<DateTime?> lastSeen(String userId);

  /// Перечитать свою настройку видимости (после изменения в приватности).
  Future<void> refreshVisibility();
}

/// Назначается в main() до runApp (мок или Supabase).
late final PresenceRepository presenceRepository;

class MockPresenceRepository implements PresenceRepository {
  MockPresenceRepository({Set<String>? online})
      : _online = online ?? {'u1', 'u4'};

  final Set<String> _online;

  @override
  Set<String> get online => _online;

  @override
  Stream<Set<String>> watchOnline() =>
      Stream<Set<String>>.value(_online).asBroadcastStream();

  @override
  Future<DateTime?> lastSeen(String userId) async {
    if (_online.contains(userId)) return DateTime.now();
    // Демо: Trofim заходил пару часов назад, остальные скрыты.
    if (userId == 'u3') {
      return DateTime.now().subtract(const Duration(hours: 2));
    }
    return null;
  }

  @override
  Future<void> refreshVisibility() async {}
}
