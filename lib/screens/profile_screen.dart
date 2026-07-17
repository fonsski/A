import 'package:flutter/material.dart';

import '../auth/auth_repository.dart';
import '../data/friends_repository.dart';
import '../data/models.dart';
import '../data/wall_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/post_card.dart';
import 'friends_screen.dart';
import 'profile_editor_screen.dart';
import 'wall_screen.dart' show showCommentSheet;

String _friendsLabel(int n) {
  if (n % 10 == 1 && n % 100 != 11) return '$n друг';
  if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) {
    return '$n друга';
  }
  return '$n друзей';
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onOpenWall});

  final VoidCallback onOpenWall;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSnapshot?>(
      stream: authRepository.snapshots,
      initialData: authRepository.current,
      builder: (context, snapshot) => _build(context, snapshot.data?.profile),
    );
  }

  Widget _build(BuildContext context, Profile? profile) {
    final colors = context.colors;
    final username = profile?.username ?? '';
    final displayName = (profile?.displayName?.isNotEmpty ?? false)
        ? profile!.displayName!
        : username;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 16, 13, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AHeader(title: 'Профиль'),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '@$username',
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FriendsScreen(),
                              ),
                            ),
                            child: StreamBuilder<List<FriendEntry>>(
                              stream: friendsRepository.watchFriends(),
                              builder: (context, snapshot) {
                                final entries =
                                    snapshot.data ?? const <FriendEntry>[];
                                final friends = entries
                                    .where(
                                      (e) => e.status == FriendStatus.friends,
                                    )
                                    .length;
                                final requests = entries
                                    .where(
                                      (e) => e.status == FriendStatus.incoming,
                                    )
                                    .length;
                                var label = _friendsLabel(friends);
                                if (requests > 0) {
                                  label +=
                                      ' · $requests заявк${requests == 1 ? 'а' : 'и'}';
                                }
                                return Text(
                                  label,
                                  style: TextStyle(
                                    color: requests > 0
                                        ? colors.accent
                                        : colors.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 26),
                    child: AAvatar(size: 72, url: profile?.avatarUrl),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              APill(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileEditorScreen(),
                  ),
                ),
                child: Text(
                  'Редактировать',
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 24),
              APill(
                borderColor: colors.accent,
                onTap: onOpenWall,
                child: Text(
                  'Стена',
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<List<Post>>(
            stream: wallRepository.watchMine(),
            builder: (context, snapshot) {
              final posts = snapshot.data ?? const <Post>[];
              if (snapshot.hasData && posts.isEmpty) {
                return Center(
                  child: Text(
                    'Постов пока нет',
                    style: TextStyle(color: colors.textSecondary, fontSize: 16),
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
    );
  }
}
