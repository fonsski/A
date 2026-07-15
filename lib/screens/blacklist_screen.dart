import 'package:flutter/material.dart';

import '../data/friends_repository.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Чёрный список: кого я заблокировал, с разблокировкой.
class BlacklistScreen extends StatelessWidget {
  const BlacklistScreen({super.key});

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
                title: 'Чёрный список',
                onTapCircle: () => Navigator.of(context).pop(),
                circleChild:
                    Icon(Icons.arrow_back, color: colors.bg, size: 18),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<UserSummary>>(
                stream: friendsRepository.watchBlocked(),
                builder: (context, snapshot) {
                  final blocked = snapshot.data ?? const <UserSummary>[];
                  if (snapshot.hasData && blocked.isEmpty) {
                    return Center(
                      child: Text(
                        'Список пуст — и это прекрасно',
                        style: TextStyle(
                            color: colors.textSecondary, fontSize: 16),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    itemCount: blocked.length,
                    itemBuilder: (context, i) {
                      final user = blocked[i];
                      return Container(
                        height: 64,
                        color: colors.surface,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 13),
                        child: Row(
                          children: [
                            AAvatar(size: 48, url: user.avatarUrl),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.displayName,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    '@${user.username}',
                                    style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  friendsRepository.unblock(user.id),
                              child: Text(
                                'Разблокировать',
                                style: TextStyle(
                                    color: colors.accent, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
