import 'package:flutter/material.dart';

import '../data/chat_repository.dart';
import '../data/friends_repository.dart';
import '../data/models.dart';
import '../data/wall_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/online_status.dart';
import '../widgets/post_card.dart';
import 'chat_screen.dart';
import 'wall_screen.dart' show showCommentSheet;

/// «Страница» другого пользователя: профиль, статус, дружба и его стена.
class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key, required this.user});

  final UserSummary user;

  Future<void> _openChat(BuildContext context) async {
    final chatId = await chatRepository.startDm(user);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chatId, peer: user),
      ),
    );
  }

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
                title: 'Профиль',
                onTapCircle: () => Navigator.of(context).pop(),
                circleChild: Icon(Icons.arrow_back, color: colors.bg, size: 18),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 43),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '@${user.username}',
                          style: TextStyle(
                            color: colors.accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OnlineStatus(userId: user.id),
                      ],
                    ),
                  ),
                  AAvatar(size: 72, url: user.avatarUrl),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              child: Row(
                children: [
                  Expanded(
                    child: APill(
                      color: colors.accent,
                      onTap: () => _openChat(context),
                      padding: EdgeInsets.zero,
                      child: Center(
                        child: Text(
                          'Написать',
                          style: TextStyle(
                            color: colors.bg,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _FriendButton(user: user)),
                ],
              ),
            ),
            _BlockLink(user: user),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Post>>(
                stream: wallRepository.watchWallOf(user.id),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Не удалось загрузить стену:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }
                  final posts = snapshot.data ?? const <Post>[];
                  if (snapshot.hasData && posts.isEmpty) {
                    return Center(
                      child: Text(
                        'Стена пуста или скрыта настройками приватности',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: posts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => PostCard(
                      post: posts[i],
                      onAga: () => wallRepository.toggleAga(posts[i].id),
                      onComment: () => showCommentSheet(context, posts[i].id),
                    ),
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

/// «Заблокировать / Разблокировать» — маленькая ссылка под кнопками.
class _BlockLink extends StatelessWidget {
  const _BlockLink({required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<List<UserSummary>>(
      stream: friendsRepository.watchBlocked(),
      builder: (context, snapshot) {
        final blocked = (snapshot.data ?? const <UserSummary>[]).any(
          (u) => u.id == user.id,
        );
        return TextButton(
          onPressed: () async {
            if (blocked) {
              await friendsRepository.unblock(user.id);
            } else {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                  backgroundColor: colors.surface,
                  title: Text(
                    'Заблокировать @${user.username}?',
                    style: TextStyle(color: colors.textPrimary, fontSize: 18),
                  ),
                  content: Text(
                    'Дружба удалится, он(а) перестанет видеть твою стену '
                    'и писать тебе.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 14),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialog).pop(false),
                      child: Text(
                        'Отмена',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialog).pop(true),
                      child: Text(
                        'Заблокировать',
                        style: TextStyle(
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await friendsRepository.block(user);
            }
          },
          child: Text(
            blocked ? 'Разблокировать' : 'Заблокировать',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        );
      },
    );
  }
}

/// Кнопка дружбы: подстраивается под текущий статус.
class _FriendButton extends StatelessWidget {
  const _FriendButton({required this.user});

  final UserSummary user;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<List<FriendEntry>>(
      stream: friendsRepository.watchFriends(),
      builder: (context, snapshot) {
        final status =
            (snapshot.data ?? const <FriendEntry>[])
                .where((e) => e.user.id == user.id)
                .map((e) => e.status)
                .firstOrNull ??
            FriendStatus.none;
        final (label, onTap) = switch (status) {
          FriendStatus.none => (
            'В друзья',
            () => friendsRepository.sendRequest(user.id),
          ),
          FriendStatus.outgoing => (
            'Заявка ушла',
            () => friendsRepository.remove(user.id),
          ),
          FriendStatus.incoming => (
            'Принять',
            () => friendsRepository.accept(user.id),
          ),
          FriendStatus.friends => (
            'В друзьях',
            () => friendsRepository.remove(user.id),
          ),
        };
        return APill(
          borderColor: colors.accent,
          onTap: onTap,
          padding: EdgeInsets.zero,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: colors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}
