import 'package:flutter/material.dart';

import '../auth/auth_repository.dart';
import '../data/models.dart';
import '../data/wall_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/post_card.dart';
import 'profile_editor_screen.dart';
import 'wall_screen.dart' show showCommentSheet;

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onOpenWall});

  final VoidCallback onOpenWall;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final profile = authRepository.current?.profile;
    final username = profile?.username ?? '';
    final displayName =
        (profile?.displayName?.isNotEmpty ?? false) ? profile!.displayName! : username;
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
                          Text(
                            '143 подписчика',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 26),
                    child: AAvatar(size: 72),
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
                    style:
                        TextStyle(color: colors.textSecondary, fontSize: 16),
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
