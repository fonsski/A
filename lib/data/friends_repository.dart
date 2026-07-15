import 'models.dart';

enum FriendStatus {
  none,
  incoming, // мне прислали заявку
  outgoing, // я отправил заявку
  friends,
}

class FriendEntry {
  const FriendEntry({required this.user, required this.status});

  final UserSummary user;
  final FriendStatus status;
}

/// Друзья и заявки. Функция are_friends в базе уже управляет
/// приватностью стенки — здесь только управление связями.
abstract class FriendsRepository {
  /// Друзья и входящие/исходящие заявки одним списком.
  Stream<List<FriendEntry>> watchFriends();

  /// Кэш id принятых друзей (для быстрых проверок, например presence).
  Set<String> get currentFriends;

  Future<void> sendRequest(String userId);

  Future<void> accept(String userId);

  /// Отклонить входящую, отменить исходящую или удалить из друзей.
  Future<void> remove(String userId);
}

/// Назначается в main() до runApp (мок или Supabase).
late final FriendsRepository friendsRepository;
