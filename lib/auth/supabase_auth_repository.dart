import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'auth_repository.dart';
import 'qr_login.dart';

/// Реализация поверх Supabase Auth + таблицы profiles.
/// Требует применённой схемы из supabase/schema.sql.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository() : _client = sb.Supabase.instance.client;

  final sb.SupabaseClient _client;

  final _controller = StreamController<AuthSnapshot?>.broadcast();
  AuthSnapshot? _current;
  StreamSubscription<sb.AuthState>? _sub;

  void _emit(AuthSnapshot? value) {
    _current = value;
    _controller.add(value);
  }

  @override
  AuthSnapshot? get current => _current;

  @override
  Stream<AuthSnapshot?> get snapshots async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<void> init() async {
    _sub ??= _client.auth.onAuthStateChange.listen((state) async {
      final session = state.session;
      if (session == null) {
        _emit(null);
      } else if (state.event == sb.AuthChangeEvent.signedIn ||
          state.event == sb.AuthChangeEvent.initialSession) {
        _emit(await _load(session.user));
      }
    });
    final session = _client.auth.currentSession;
    if (session != null) _emit(await _load(session.user));
  }

  Future<AuthSnapshot> _load(sb.User user) async {
    final row = await _client
        .from('profiles')
        .select('username, display_name, bio, links, phone, avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    final links = (row?['links'] as List?) ?? const [];
    return AuthSnapshot(
      userId: user.id,
      email: user.email ?? '',
      profile: Profile(
        username: row?['username'] as String?,
        displayName: row?['display_name'] as String?,
        bio: row?['bio'] as String?,
        link: links.isEmpty ? null : links.first as String?,
        phone: row?['phone'] as String?,
        avatarUrl: row?['avatar_url'] as String?,
      ),
    );
  }

  @override
  Future<void> signUp({required String email, required String password}) async {
    try {
      await _client.auth.signUp(email: email.trim(), password: password);
    } on sb.AuthException catch (e) {
      throw AuthFailure(_ru(e));
    }
  }

  @override
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    var email = identifier.trim();
    try {
      if (!email.contains('@') || email.startsWith('@')) {
        // Вход по нику: ищем почту через security definer-функцию.
        final username = email.startsWith('@') ? email.substring(1) : email;
        final result = await _client.rpc<String?>(
          'email_for_username',
          params: {'login': username},
        );
        if (result == null) {
          throw const AuthFailure('Неверная почта/ник или пароль');
        }
        email = result;
      }
      await _client.auth.signInWithPassword(email: email, password: password);
    } on sb.AuthException catch (e) {
      throw AuthFailure(_ru(e));
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> resendConfirmation(String email) async {
    await _client.auth.resend(type: sb.OtpType.signup, email: email.trim());
  }

  @override
  Future<void> requestPasswordReset(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());

  @override
  Future<bool> isUsernameAvailable(String username) async {
    return await _client.rpc<bool>(
      'username_available',
      params: {'candidate': username.trim().toLowerCase()},
    );
  }

  @override
  Future<void> claimUsername({
    required String username,
    required String displayName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('Сессия истекла — войди заново');
    final value = username.trim().toLowerCase();
    try {
      await _client
          .from('profiles')
          .update({
            'username': value,
            'display_name': displayName.trim().isEmpty
                ? value
                : displayName.trim(),
          })
          .eq('id', user.id);
    } on sb.PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const AuthFailure('Ник только что заняли — попробуй другой');
      }
      rethrow;
    }
    _emit(await _load(user));
  }

  @override
  Future<void> updateProfile({
    required String displayName,
    required String bio,
    required String link,
    required String phone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('Сессия истекла — войди заново');
    String? clean(String v) => v.trim().isEmpty ? null : v.trim();
    await _client
        .from('profiles')
        .update({
          'display_name': clean(displayName),
          'bio': clean(bio),
          'links': clean(link) == null ? [] : [clean(link)],
          'phone': clean(phone),
        })
        .eq('id', user.id);
    _emit(await _load(user));
  }

  @override
  Future<void> updateAvatar(Uint8List bytes, String mimeType) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthFailure('Сессия истекла — войди заново');
    final ext = mimeType.split('/').last;
    final path = '${user.id}/avatar.$ext';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: sb.FileOptions(contentType: mimeType, upsert: true),
        );
    // Метка версии, чтобы кэш браузера не показывал старую картинку.
    final url =
        '${_client.storage.from('avatars').getPublicUrl(path)}'
        '?v=${DateTime.now().millisecondsSinceEpoch}';
    await _client
        .from('profiles')
        .update({'avatar_url': url})
        .eq('id', user.id);
    _emit(await _load(user));
  }

  @override
  Future<void> changeEmail(String newEmail) async {
    try {
      await _client.auth.updateUser(sb.UserAttributes(email: newEmail.trim()));
    } on sb.AuthException catch (e) {
      throw AuthFailure(_ru(e));
    }
  }

  @override
  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw const AuthFailure('Сессия истекла — войди заново');
    try {
      // Повторная проверка старого пароля: украденная открытая сессия
      // не должна позволять сменить пароль без его знания.
      await _client.auth.signInWithPassword(email: email, password: current);
    } on sb.AuthException {
      throw const AuthFailure('Текущий пароль неверный');
    }
    try {
      await _client.auth.updateUser(sb.UserAttributes(password: next));
    } on sb.AuthException catch (e) {
      throw AuthFailure(_ru(e));
    }
  }

  // ── вход по QR ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _qr(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('qr-login', body: body);
      return Map<String, dynamic>.from(res.data as Map);
    } on sb.FunctionException catch (e) {
      if (e.status == 404) {
        throw const AuthFailure('QR-вход ещё не настроен на сервере');
      }
      if (e.status == 403) throw const AuthFailure('Код не подошёл');
      throw AuthFailure('QR-вход не сработал (${e.status})');
    } catch (e) {
      debugPrint('QR-вход: $e');
      throw const AuthFailure('Нет связи с сервером');
    }
  }

  String get _deviceLabel =>
      '${kIsWeb ? 'Браузер' : 'Приложение'} · ${defaultTargetPlatform.name}';

  @override
  Future<QrLoginSession> startQrLogin() async {
    final res = await _qr({'action': 'create', 'device': _deviceLabel});
    final id = res['id'] as String?;
    final code = res['code'] as String?;
    final claim = res['claim'] as String?;
    if (id == null || code == null || claim == null) {
      throw const AuthFailure('QR-вход не сработал');
    }
    return QrLoginSession(
      id: id,
      payload: buildQrPayload(id, code),
      claim: claim,
      expiresAt: DateTime.now().add(
        Duration(seconds: (res['expires_in'] as num?)?.toInt() ?? 120),
      ),
    );
  }

  @override
  Future<QrPoll> pollQrLogin(QrLoginSession session) async {
    final res = await _qr({
      'action': 'claim',
      'id': session.id,
      'claim': session.claim,
    });
    switch (res['status']) {
      case 'approved':
        final tokenHash = res['token_hash'] as String?;
        if (tokenHash == null) throw const AuthFailure('QR-вход не сработал');
        try {
          await _client.auth.verifyOTP(
            tokenHash: tokenHash,
            type: sb.OtpType.magiclink,
          );
        } on sb.AuthException catch (e) {
          throw AuthFailure(_ru(e));
        }
        return QrPoll.signedIn;
      case 'pending':
        return QrPoll.pending;
      default:
        return QrPoll.expired;
    }
  }

  @override
  Future<String> describeQrLogin(String payload) async {
    final parsed = parseQrPayload(payload);
    if (parsed == null) throw const AuthFailure('Это не QR-код входа в «А?»');
    final res = await _qr({
      'action': 'info',
      'id': parsed.id,
      'code': parsed.code,
    });
    if (res['status'] != 'pending') {
      throw const AuthFailure('Код устарел — обнови QR на экране входа');
    }
    return (res['device'] ?? 'Новое устройство') as String;
  }

  @override
  Future<void> approveQrLogin(String payload) async {
    final parsed = parseQrPayload(payload);
    if (parsed == null) throw const AuthFailure('Это не QR-код входа в «А?»');
    final res = await _qr({
      'action': 'approve',
      'id': parsed.id,
      'code': parsed.code,
    });
    if (res['status'] != 'approved') {
      throw const AuthFailure('Код устарел — обнови QR на экране входа');
    }
  }

  String _ru(sb.AuthException e) {
    return switch (e.code) {
      'invalid_credentials' => 'Неверная почта/ник или пароль',
      'email_not_confirmed' => 'Почта ещё не подтверждена — проверь письмо',
      'user_already_exists' ||
      'email_exists' => 'Эта почта уже зарегистрирована',
      'weak_password' => 'Слишком простой пароль',
      'same_password' => 'Новый пароль совпадает со старым',
      'email_address_invalid' => 'Эта почта не подходит',
      'over_email_send_rate_limit' =>
        'Слишком часто — подожди минуту и попробуй снова',
      _ => 'Не получилось: ${e.message}',
    };
  }
}
