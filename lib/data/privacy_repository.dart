/// Аудитория настройки: индекс совпадает с сегментом «Все / Друзья / Я»
/// (для комментариев третий вариант — «Никто»).
enum Audience { all, friends, me }

class PrivacySettings {
  const PrivacySettings({
    this.wallVisibleTo = Audience.all,
    this.wallPostBy = Audience.friends,
    this.commentsBy = Audience.all,
    this.phoneVisibleTo = Audience.friends,
    this.onlineVisibleTo = Audience.all,
  });

  final Audience wallVisibleTo;
  final Audience wallPostBy;
  final Audience commentsBy;
  final Audience phoneVisibleTo;
  final Audience onlineVisibleTo;

  PrivacySettings copyWith({
    Audience? wallVisibleTo,
    Audience? wallPostBy,
    Audience? commentsBy,
    Audience? phoneVisibleTo,
    Audience? onlineVisibleTo,
  }) {
    return PrivacySettings(
      wallVisibleTo: wallVisibleTo ?? this.wallVisibleTo,
      wallPostBy: wallPostBy ?? this.wallPostBy,
      commentsBy: commentsBy ?? this.commentsBy,
      phoneVisibleTo: phoneVisibleTo ?? this.phoneVisibleTo,
      onlineVisibleTo: onlineVisibleTo ?? this.onlineVisibleTo,
    );
  }
}

abstract class PrivacyRepository {
  Future<PrivacySettings> load();

  /// Сохраняет настройки; RLS-политики стенки начинают действовать сразу.
  Future<void> save(PrivacySettings settings);
}

/// Назначается в main() до runApp (мок или Supabase).
late final PrivacyRepository privacyRepository;

class MockPrivacyRepository implements PrivacyRepository {
  PrivacySettings _settings = const PrivacySettings();

  @override
  Future<PrivacySettings> load() async => _settings;

  @override
  Future<void> save(PrivacySettings settings) async => _settings = settings;
}
