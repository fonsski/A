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
                circleChild: Icon(Icons.arrow_back, color: colors.bg, size: 18),
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
                          color: colors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    itemCount: blocked.length,
                    itemBuilder: (context, i) {
                      final user = blocked[i];
                      return AUserTile(
                        name: user.displayName,
                        username: user.username,
                        avatarUrl: user.avatarUrl,
                        trailing: TextButton(
                          onPressed: () => friendsRepository.unblock(user.id),
                          child: Text(
                            'Разблокировать',
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 14,
                            ),
                          ),
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
