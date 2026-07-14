import 'package:flutter/material.dart';

import '../data/chat_repository.dart';
import '../data/friends_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';

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
                circleChild:
                    Icon(Icons.arrow_back, color: colors.bg, size: 18),
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
                                color: colors.textSecondary, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          APill(
                            color: colors.accent,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const NewChatScreen()),
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
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                    children: [
                      if (incoming.isNotEmpty) ...[
                        const _SectionTitle('Заявки'),
                        for (final e in incoming) _IncomingTile(entry: e),
                      ],
                      if (outgoing.isNotEmpty) ...[
                        const _SectionTitle('Отправленные'),
                        for (final e in outgoing) _OutgoingTile(entry: e),
                      ],
                      if (friends.isNotEmpty) ...[
                        const _SectionTitle('Друзья'),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 12),
      child: Text(
        text,
        style: TextStyle(
          color: context.colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.entry, required this.trailing});

  final FriendEntry entry;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 64,
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Row(
        children: [
          AAvatar(size: 48, url: entry.user.avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.user.displayName,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${entry.user.username}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
          trailing,
        ],
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
    return _PersonRow(
      entry: entry,
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
              decoration: pillDecoration(colors.surface,
                  borderColor: colors.accent),
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
    return _PersonRow(
      entry: entry,
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
    return GestureDetector(
      onTap: () async {
        final chatId = await chatRepository.startDm(entry.user);
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatId: chatId,
              name: entry.user.displayName,
              avatarUrl: entry.user.avatarUrl,
            ),
          ),
        );
      },
      child: _PersonRow(
        entry: entry,
        trailing: Icon(Icons.chevron_right, color: colors.accent),
      ),
    );
  }
}
