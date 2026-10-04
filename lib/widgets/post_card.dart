import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/wall_repository.dart';
import '../theme.dart';
import 'comment_tile.dart';
import 'common.dart';

/// Запись на стенке: автор, текст (или репост), «Ага!»/«∀», комментарии.
///
/// Сама ходит в [wallRepository] за реакциями, репостом и удалением;
/// переход в ветку комментариев делает экран через [onOpenThread].
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onOpenThread,
    this.onOpenOriginal,
    this.showComments = true,
  });

  final Post post;

  /// Открыть экран ветки (тап по «N комментов» и по значку комментария).
  final VoidCallback? onOpenThread;

  /// Открыть ветку оригинала репоста.
  final ValueChanged<String>? onOpenOriginal;

  /// false — без предпросмотра комментариев (на самом экране ветки).
  final bool showComments;

  static String commentsLabel(int n) {
    if (n == 0) return '0 комментов';
    if (n % 10 == 1 && n % 100 != 11) return '$n коммент';
    if ([2, 3, 4].contains(n % 10) && ![12, 13, 14].contains(n % 100)) {
      return '$n коммента';
    }
    return '$n комментов';
  }

  Future<void> _repost(BuildContext context) async {
    final colors = context.colors;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Репост на твою стену',
          style: TextStyle(color: colors.textPrimary, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          decoration: const InputDecoration(
            hintText: 'Подпись (необязательно)',
          ),
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
              'Поделиться',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await wallRepository.repost(post.id, comment: controller.text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запись добавлена на твою стену')),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Удалить запись?',
          style: TextStyle(color: colors.textPrimary, fontSize: 18),
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
              'Удалить',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await wallRepository.deletePost(post.id);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tree = buildCommentTree(post.comments);
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
                    _PostMenu(post: post, onDelete: () => _delete(context)),
                  ],
                ),
                if (post.isRepost)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.repeat, size: 14, color: colors.accent),
                        const SizedBox(width: 4),
                        Text(
                          'репост',
                          style: TextStyle(color: colors.accent, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (post.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    post.text,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      height: 18 / 16,
                    ),
                  ),
                ],
                if (post.isRepost) ...[
                  const SizedBox(height: 8),
                  _OriginalBlock(
                    original: post.original,
                    onTap: post.original == null || onOpenOriginal == null
                        ? null
                        : () => onOpenOriginal!(post.original!.id),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Подпись сжимается первой: на узкой колонке иконкам
                    // важнее остаться в пределах строки.
                    Expanded(
                      child: GestureDetector(
                        onTap: onOpenThread,
                        child: Text(
                          commentsLabel(post.comments.length),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    ReactionButton(
                      dislike: false,
                      count: post.agaCount,
                      active: post.myAga,
                      onTap: () => wallRepository.toggleAga(post.id),
                    ),
                    const SizedBox(width: 12),
                    ReactionButton(
                      dislike: true,
                      count: post.dislikeCount,
                      active: post.myDislike,
                      onTap: () => wallRepository.toggleDislike(post.id),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onOpenThread,
                      child: Image.asset(
                        'assets/images/nav_chats.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _repost(context),
                      child: Image.asset(
                        'assets/images/react_2.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                if (showComments && tree.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  CommentTile(comment: tree.first.comment),
                  if (post.comments.length > 1) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onOpenThread,
                      child: Text(
                        'Вся ветка (${post.comments.length})',
                        style: TextStyle(color: colors.accent, fontSize: 14),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PostMenu extends StatelessWidget {
  const _PostMenu({required this.post, required this.onDelete});

  final Post post;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final copyable = post.text.isNotEmpty
        ? post.text
        : (post.original?.text ?? '');
    return SizedBox(
      width: 24,
      height: 24,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        tooltip: 'Меню записи',
        icon: Icon(Icons.more_vert, size: 20, color: colors.textSecondary),
        onSelected: (value) async {
          if (value == 'copy') {
            await Clipboard.setData(ClipboardData(text: copyable));
          } else if (value == 'delete') {
            onDelete();
          }
        },
        itemBuilder: (_) => [
          if (copyable.isNotEmpty)
            const PopupMenuItem(value: 'copy', child: Text('Копировать текст')),
          if (post.canDelete)
            const PopupMenuItem(value: 'delete', child: Text('Удалить')),
        ],
      ),
    );
  }
}

/// Вложенный оригинал репоста; null — оригинал удалён или недоступен.
class _OriginalBlock extends StatelessWidget {
  const _OriginalBlock({required this.original, this.onTap});

  final Post? original;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final o = original;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.accent, width: 2)),
        ),
        child: o == null
            ? Text(
                'Запись недоступна',
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AAvatar(size: 24, url: o.authorAvatarUrl),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          o.authorName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        formatTime(o.createdAt),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    o.text,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      height: 18 / 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
