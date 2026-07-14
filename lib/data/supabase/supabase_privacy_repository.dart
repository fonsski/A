import 'package:supabase_flutter/supabase_flutter.dart';

import '../privacy_repository.dart';

/// privacy_settings: строка создаётся триггером при регистрации.
class SupabasePrivacyRepository implements PrivacyRepository {
  SupabasePrivacyRepository() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  static Audience _from(String value) => switch (value) {
        'all' => Audience.all,
        'friends' => Audience.friends,
        _ => Audience.me, // 'me' и 'nobody'
      };

  static String _to(Audience a, {bool nobody = false}) => switch (a) {
        Audience.all => 'all',
        Audience.friends => 'friends',
        Audience.me => nobody ? 'nobody' : 'me',
      };

  @override
  Future<PrivacySettings> load() async {
    final row = await _client
        .from('privacy_settings')
        .select()
        .eq('user_id', _uid)
        .maybeSingle();
    if (row == null) return const PrivacySettings();
    return PrivacySettings(
      wallVisibleTo: _from(row['wall_visible_to'] as String),
      wallPostBy: _from(row['wall_post_by'] as String),
      commentsBy: _from(row['comments_by'] as String),
      phoneVisibleTo: _from(row['phone_visible_to'] as String),
      onlineVisibleTo: _from(row['online_visible_to'] as String),
    );
  }

  @override
  Future<void> save(PrivacySettings s) async {
    await _client.from('privacy_settings').upsert({
      'user_id': _uid,
      'wall_visible_to': _to(s.wallVisibleTo),
      'wall_post_by': _to(s.wallPostBy),
      'comments_by': _to(s.commentsBy, nobody: true),
      'phone_visible_to': _to(s.phoneVisibleTo),
      'online_visible_to': _to(s.onlineVisibleTo),
    });
  }
}
