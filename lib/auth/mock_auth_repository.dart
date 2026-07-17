import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'auth_repository.dart';

class _MockUser {
  _MockUser({required this.email, required this.password});

  final String email;
  String password;
  bool confirmed = false;
  String? username;
  String? displayName;
  String? bio;
  String? link;
  String? phone;
  String? avatarUrl;
}

/// Локальный бэкенд для разработки без Supabase: всё в памяти,
/// «письмо» подтверждается автоматически через [confirmDelay].
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.confirmDelay = const Duration(seconds: 5)});

  final Duration confirmDelay;

  final _users = <String, _MockUser>{
    // Готовый аккаунт для быстрой проверки входа: demo@a.ru / password1
    'demo@a.ru': _MockUser(email: 'demo@a.ru', password: 'password1')
      ..confirmed = true
      ..username = 'de.panda'
      ..displayName = 'Denis Panda',
  };
  final _takenUsernames = <String>{'de.panda', 'admin', 'support', 'a'};

  final _controller = StreamController<AuthSnapshot?>.broadcast();
  AuthSnapshot? _current;

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
  Future<void> init() async {}

  static final _latency = Future<void>.delayed(Duration.zero);

  @override
  Future<void> signUp({required String email, required String password}) async {
    await _latency;
    final key = email.trim().toLowerCase();
    if (_users.containsKey(key)) {
      throw const AuthFailure('Эта почта уже зарегистрирована');
    }
    final user = _MockUser(email: key, password: password);
    _users[key] = user;
    // Имитируем клик по ссылке в письме.
    Timer(confirmDelay, () => user.confirmed = true);
  }

  @override
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    await _latency;
    var id = identifier.trim().toLowerCase();
    _MockUser? user;
    if (id.contains('@') && !id.startsWith('@')) {
      user = _users[id];
    } else {
      if (id.startsWith('@')) id = id.substring(1);
      for (final u in _users.values) {
        if (u.username == id) user = u;
      }
    }
    if (user == null || user.password != password) {
      throw const AuthFailure('Неверная почта/ник или пароль');
    }
    if (!user.confirmed) {
      throw const AuthFailure(
        'Почта ещё не подтверждена — проверь письмо\n'
        '(в демо-режиме подтверждение приходит через ~5 секунд)',
      );
    }
    _emit(_snapshotOf(user));
  }

  AuthSnapshot _snapshotOf(_MockUser user) => AuthSnapshot(
    userId: user.email,
    email: user.email,
    profile: Profile(
      username: user.username,
      displayName: user.displayName,
      bio: user.bio,
      link: user.link,
      phone: user.phone,
      avatarUrl: user.avatarUrl,
    ),
  );

  @override
  Future<void> signOut() async => _emit(null);

  @override
  Future<void> resendConfirmation(String email) async {}

  @override
  Future<void> requestPasswordReset(String email) async {}

  @override
  Future<bool> isUsernameAvailable(String username) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return !_takenUsernames.contains(username.trim().toLowerCase());
  }

  @override
  Future<void> claimUsername({
    required String username,
    required String displayName,
  }) async {
    final snapshot = _current;
    if (snapshot == null) {
      throw const AuthFailure('Сессия истекла — войди заново');
    }
    final value = username.trim().toLowerCase();
    if (_takenUsernames.contains(value)) {
      throw const AuthFailure('Ник только что заняли — попробуй другой');
    }
    _takenUsernames.add(value);
    final user = _users[snapshot.email]!;
    user.username = value;
    user.displayName = displayName.trim().isEmpty ? value : displayName.trim();
    _emit(_snapshotOf(user));
  }

  @override
  Future<void> updateProfile({
    required String displayName,
    required String bio,
    required String link,
    required String phone,
  }) async {
    final snapshot = _current;
    if (snapshot == null) {
      throw const AuthFailure('Сессия истекла — войди заново');
    }
    String? clean(String v) => v.trim().isEmpty ? null : v.trim();
    final user = _users[snapshot.email]!
      ..displayName = clean(displayName)
      ..bio = clean(bio)
      ..link = clean(link)
      ..phone = clean(phone);
    _emit(_snapshotOf(user));
  }

  @override
  Future<void> updateAvatar(Uint8List bytes, String mimeType) async {
    final snapshot = _current;
    if (snapshot == null) {
      throw const AuthFailure('Сессия истекла — войди заново');
    }
    final user = _users[snapshot.email]!
      ..avatarUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    _emit(_snapshotOf(user));
  }
}
