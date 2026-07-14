import 'dart:async';

import '../friends_repository.dart';
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
}
