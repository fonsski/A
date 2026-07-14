import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme.dart';
import 'common.dart';

/// Запись на стенке: автор, текст, «Ага!», комментарии.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onAga,
    this.onComment,
  });

  final Post post;
  final VoidCallback? onAga;
  final VoidCallback? onComment;

  String get _commentsLabel {
    final n = post.comments.length;
    if (n == 0) return '0 комментов';
    if (n % 10 == 1 && n % 100 != 11) return '$n коммент';
    if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) {
      return '$n коммента';
    }
    return '$n комментов';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AAvatar(size: 64, url: post.authorAvatarUrl),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        post.authorName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      formatTime(post.createdAt),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.more_vert, size: 20, color: colors.textSecondary),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  post.text,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    height: 18 / 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onComment,
                      child: Text(
                        _commentsLabel,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onAga,
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/flag.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                            color: post.myAga ? null : colors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${post.agaCount}',
                            style: TextStyle(
                              color: post.myAga
                                  ? colors.accent
                                  : colors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onComment,
                      child: Image.asset(
                        'assets/images/nav_chats.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Image.asset(
                      'assets/images/react_2.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
                for (final comment in post.comments) ...[
                  const SizedBox(height: 16),
                  _CommentTile(comment: comment),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AAvatar(size: 32, url: comment.authorAvatarUrl),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.authorName,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                comment.text,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  height: 18 / 16,
                ),
              ),
              if (comment.imageAsset != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    comment.imageAsset!,
                    width: 128,
                    height: 128,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
