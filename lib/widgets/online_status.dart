import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/presence_repository.dart';
import '../theme.dart';

/// «в сети» / «был(а) в сети 12:07» / «не в сети» — с учётом приватности.
class OnlineStatus extends StatelessWidget {
  const OnlineStatus({
    super.key,
    required this.userId,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w500,
  });

  final String userId;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return StreamBuilder<Set<String>>(
      stream: presenceRepository.watchOnline(),
      initialData: presenceRepository.online,
      builder: (context, snapshot) {
        final online = snapshot.data?.contains(userId) ?? false;
        if (online) {
          return Text(
            'в сети',
            style: TextStyle(
              color: colors.accent,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          );
        }
        return FutureBuilder<DateTime?>(
          future: presenceRepository.lastSeen(userId),
          builder: (context, seen) {
            final t = seen.data;
            return Text(
              t != null ? 'был(а) в сети ${formatTime(t)}' : 'не в сети',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: fontSize,
                fontWeight: fontWeight,
              ),
            );
          },
        );
      },
    );
  }
}
