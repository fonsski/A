import 'package:flutter/material.dart';

import '../data/chat_repository.dart';
import '../data/friends_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'user_profile_screen.dart';

/// Друзья и заявки. Входящие можно принять/отклонить,
/// исходящие — отменить, друзьям — написать.
class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
              child: AHeader(
                title: 'Друзья',
                onTapCircle: () => Navigator.of(context).pop(),
                circleChild: Icon(Icons.arrow_back, color: colors.bg, size: 18),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<FriendEntry>>(
                stream: friendsRepository.watchFriends(),
                builder: (context, snapshot) {
                  final entries = snapshot.data ?? const <FriendEntry>[];
                  final incoming = entries
                      .where((e) => e.status == FriendStatus.incoming)
                      .toList();
                  final outgoing = entries
                      .where((e) => e.status == FriendStatus.outgoing)
                      .toList();
                  final friends = entries
                      .where((e) => e.status == FriendStatus.friends)
                      .toList();
                  if (snapshot.hasData && entries.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Пока никого нет',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          APill(
                            color: colors.accent,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NewChatScreen(),
                              ),
                            ),
                            child: Text(
                              'Найти людей',
                              style: TextStyle(
                                color: colors.bg,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  const sectionPadding = EdgeInsets.fromLTRB(28, 8, 28, 12);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                    children: [
                      if (incoming.isNotEmpty) ...[
                        const ASectionTitle('Заявки', padding: sectionPadding),
                        for (final e in incoming) _IncomingTile(entry: e),
                      ],
                      if (outgoing.isNotEmpty) ...[
                        const ASectionTitle(
                          'Отправленные',
                          padding: sectionPadding,
                        ),
                        for (final e in outgoing) _OutgoingTile(entry: e),
                      ],
                      if (friends.isNotEmpty) ...[
                        const ASectionTitle('Друзья', padding: sectionPadding),
                        for (final e in friends) _FriendTile(entry: e),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingTile extends StatelessWidget {
  const _IncomingTile({required this.entry});

  final FriendEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AUserTile(
      name: entry.user.displayName,
      username: entry.user.username,
      avatarUrl: entry.user.avatarUrl,
      trailing: Row(
        children: [
          GestureDetector(
            onTap: () => friendsRepository.accept(entry.user.id),
            child: Container(
              width: 36,
              height: 36,
              decoration: pillDecoration(colors.accent),
              child: Icon(Icons.check, color: colors.bg, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => friendsRepository.remove(entry.user.id),
            child: Container(
              width: 36,
              height: 36,
              decoration: pillDecoration(
                colors.surface,
                borderColor: colors.accent,
              ),
              child: Icon(Icons.close, color: colors.accent, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutgoingTile extends StatelessWidget {
  const _OutgoingTile({required this.entry});

  final FriendEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AUserTile(
      name: entry.user.displayName,
      username: entry.user.username,
      avatarUrl: entry.user.avatarUrl,
      trailing: TextButton(
        onPressed: () => friendsRepository.remove(entry.user.id),
        child: Text(
          'Отменить',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.entry});

  final FriendEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Тап по другу — его страница; иконка чата — сразу диалог.
    return AUserTile(
      name: entry.user.displayName,
      username: entry.user.username,
      avatarUrl: entry.user.avatarUrl,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserProfileScreen(user: entry.user)),
      ),
      trailing: IconButton(
        tooltip: 'Написать',
        icon: Icon(Icons.chat_bubble_outline, color: colors.accent),
        onPressed: () async {
          final chatId = await chatRepository.startDm(entry.user);
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(chatId: chatId, peer: entry.user),
            ),
          );
        },
      ),
    );
  }
}
