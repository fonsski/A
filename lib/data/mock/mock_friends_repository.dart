import 'dart:async';

import '../friends_repository.dart';
import '../models.dart';
import 'mock_directory.dart';

/// Друзья в памяти: один друг и одна входящая заявка из коробки.
class MockFriendsRepository implements FriendsRepository {
  final _statuses = <String, FriendStatus>{
    'u1': FriendStatus.friends, // Viktor Dudovich
    'u3': FriendStatus.incoming, // Trofim More прислал заявку
  };

  final _controller = StreamController<List<FriendEntry>>.broadcast();

  List<FriendEntry> get _snapshot => [
    for (final user in mockUsers)
      if (_statuses.containsKey(user.id))
        FriendEntry(user: user, status: _statuses[user.id]!),
  ];

  void _notify() => _controller.add(_snapshot);

  @override
  Set<String> get currentFriends => {
    for (final e in _statuses.entries)
      if (e.value == FriendStatus.friends) e.key,
  };

  @override
  Stream<List<FriendEntry>> watchFriends() async* {
    yield _snapshot;
    yield* _controller.stream;
  }

  @override
  Future<void> sendRequest(String userId) async {
    if (_statuses[userId] == FriendStatus.incoming) {
      // Взаимная заявка — сразу друзья.
      _statuses[userId] = FriendStatus.friends;
    } else {
      _statuses.putIfAbsent(userId, () => FriendStatus.outgoing);
    }
    _notify();
  }

  @override
  Future<void> accept(String userId) async {
    if (_statuses[userId] == FriendStatus.incoming) {
      _statuses[userId] = FriendStatus.friends;
      _notify();
    }
  }

  @override
  Future<void> remove(String userId) async {
    _statuses.remove(userId);
    _notify();
  }

  final _blocked = <String>{};
  final _blockedController = StreamController<List<UserSummary>>.broadcast();

  List<UserSummary> get _blockedSnapshot => [
    for (final u in mockUsers)
      if (_blocked.contains(u.id)) u,
  ];

  @override
  Set<String> get currentBlocked => Set.unmodifiable(_blocked);

  @override
  Stream<List<UserSummary>> watchBlocked() async* {
    yield _blockedSnapshot;
    yield* _blockedController.stream;
  }

  @override
  Future<void> block(UserSummary user) async {
    _statuses.remove(user.id); // дружба/заявки не переживают блокировку
    _blocked.add(user.id);
    _notify();
    _blockedController.add(_blockedSnapshot);
  }

  @override
  Future<void> unblock(String userId) async {
    _blocked.remove(userId);
    _blockedController.add(_blockedSnapshot);
  }
}
