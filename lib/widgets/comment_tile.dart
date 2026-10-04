import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/wall_repository.dart';
import '../theme.dart';
import 'common.dart';

/// Контурная буква «А» (Ага!) или «∀» (дизлайк) из макета — «∀» это та же
/// «А», перевёрнутая вверх ногами.
class AgaGlyph extends StatelessWidget {
  const AgaGlyph({
    super.key,
    required this.color,
    this.size = 24,
    this.upsideDown = false,
  });

  final Color color;
  final double size;
  final bool upsideDown;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: upsideDown ? math.pi : 0,
      child: CustomPaint(
        size: Size.square(size),
        painter: _GlyphPainter(color),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, w / 12)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Ноги «А» от вершины к основанию и перекладина на 62% высоты.
    final apex = Offset(w * 0.5, h * 0.1);
    final left = Offset(w * 0.14, h * 0.9);
    final right = Offset(w * 0.86, h * 0.9);
    Offset along(Offset foot, double t) =>
        Offset.lerp(apex, foot, t)!; // точка на ноге
    canvas
      ..drawPath(
        Path()
          ..moveTo(left.dx, left.dy)
          ..lineTo(apex.dx, apex.dy)
          ..lineTo(right.dx, right.dy),
        paint,
      )
      ..drawLine(along(left, 0.62), along(right, 0.62), paint);
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.color != color;
}

/// «А» или «∀» со счётчиком; активная подсвечена акцентом.
class ReactionButton extends StatelessWidget {
  const ReactionButton({
    super.key,
    required this.dislike,
    required this.count,
    required this.active,
    required this.onTap,
    this.size = 24,
  });

  final bool dislike;
  final int count;
  final bool active;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = active ? colors.accent : colors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AgaGlyph(color: color, size: size, upsideDown: dislike),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Комментарий: автор, текст, «Ага!», «∀» и «Ответить».
class CommentTile extends StatelessWidget {
  const CommentTile({super.key, required this.comment, this.onReply});

  final Comment comment;

  /// null — кнопки «Ответить» нет (компактный предпросмотр в карточке).
  final VoidCallback? onReply;

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
              Row(
                children: [
                  Flexible(
                    child: Text(
                      comment.authorName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (comment.createdAt != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      formatTime(comment.createdAt),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const Spacer(),
                  _CommentMenu(comment: comment),
                ],
              ),
              const SizedBox(height: 2),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  ReactionButton(
                    dislike: false,
                    size: 20,
                    count: comment.agaCount,
                    active: comment.myReaction == PostReaction.aga,
                    onTap: () => wallRepository.toggleCommentReaction(
                      comment.id,
                      PostReaction.aga,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ReactionButton(
                    dislike: true,
                    size: 20,
                    count: comment.dislikeCount,
                    active: comment.myReaction == PostReaction.dislike,
                    onTap: () => wallRepository.toggleCommentReaction(
                      comment.id,
                      PostReaction.dislike,
                    ),
                  ),
                  if (onReply != null) ...[
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onReply,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'Ответить',
                        style: TextStyle(color: colors.accent, fontSize: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentMenu extends StatelessWidget {
  const _CommentMenu({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: 24,
      height: 24,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        tooltip: 'Меню комментария',
        icon: Icon(Icons.more_vert, size: 18, color: colors.textSecondary),
        onSelected: (value) async {
          if (value == 'copy') {
            await Clipboard.setData(ClipboardData(text: comment.text));
          } else if (value == 'delete') {
            await wallRepository.deleteComment(comment.id);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'copy', child: Text('Копировать текст')),
          if (comment.canDelete)
            const PopupMenuItem(value: 'delete', child: Text('Удалить')),
        ],
      ),
    );
  }
}

/// Ветка комментариев: комментарий и вложенные ответы с вертикальной
/// линией слева. Глубже [maxDepth] отступ не растёт, чтобы текст не сжимался.
class CommentBranch extends StatelessWidget {
  const CommentBranch({
    super.key,
    required this.node,
    required this.onReply,
    this.depth = 0,
    this.maxDepth = 4,
  });

  final CommentNode node;
  final ValueChanged<Comment> onReply;
  final int depth;
  final int maxDepth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final nested = depth < maxDepth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CommentTile(
          comment: node.comment,
          onReply: () => onReply(node.comment),
        ),
        if (node.replies.isNotEmpty)
          Container(
            margin: EdgeInsets.only(left: nested ? 16 : 0, top: 12),
            padding: EdgeInsets.only(left: nested ? 12 : 0),
            decoration: nested
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: colors.accent.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final reply in node.replies) ...[
                  CommentBranch(
                    node: reply,
                    onReply: onReply,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                  ),
                  if (reply != node.replies.last) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
