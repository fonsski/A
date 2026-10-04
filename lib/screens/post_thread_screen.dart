import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/wall_repository.dart';
import '../theme.dart';
import '../widgets/comment_tile.dart';
import '../widgets/common.dart';
import '../widgets/post_card.dart';

/// Открывает экран ветки комментариев поста.
void openPostThread(BuildContext context, String postId) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => PostThreadScreen(postId: postId)));
}

/// Пост целиком и дерево его комментариев с ответами («ветка»).
class PostThreadScreen extends StatefulWidget {
  const PostThreadScreen({super.key, required this.postId});

  final String postId;

  @override
  State<PostThreadScreen> createState() => _PostThreadScreenState();
}

class _PostThreadScreenState extends State<PostThreadScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Comment? _replyTo;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    wallRepository.addComment(widget.postId, text, parentId: _replyTo?.id);
    _controller.clear();
    setState(() => _replyTo = null);
    _focus.requestFocus();
  }

  void _reply(Comment comment) {
    setState(() => _replyTo = comment);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
              child: AHeader(
                title: 'Запись',
                onTapCircle: () => Navigator.of(context).pop(),
                circleChild: Icon(Icons.arrow_back, color: colors.bg, size: 18),
              ),
            ),
            Expanded(
              child: StreamBuilder<Post?>(
                stream: wallRepository.watchPost(widget.postId),
                builder: (context, snapshot) {
                  final post = snapshot.data;
                  if (post == null) {
                    return Center(
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const CircularProgressIndicator()
                          : Text(
                              'Запись недоступна',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                    );
                  }
                  final tree = buildCommentTree(post.comments);
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      PostCard(
                        post: post,
                        showComments: false,
                        onOpenThread: _focus.requestFocus,
                        onOpenOriginal: (id) => openPostThread(context, id),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        color: colors.surface,
                        padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
                        child: tree.isEmpty
                            ? Text(
                                'Комментариев пока нет — будь первым',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 14,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final node in tree) ...[
                                    CommentBranch(node: node, onReply: _reply),
                                    if (node != tree.last)
                                      const SizedBox(height: 16),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_replyTo != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(21, 0, 21, 4),
                child: Row(
                  children: [
                    Icon(Icons.reply, size: 16, color: colors.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ответ: ${_replyTo!.authorName}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.accent, fontSize: 13),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _replyTo = null),
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.only(left: 28, right: 8),
                      decoration: pillDecoration(colors.surface),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        onSubmitted: (_) => _send(),
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isCollapsed: true,
                          hintText: _replyTo == null
                              ? 'Комментарий'
                              : 'Ответить...',
                          hintStyle: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: pillDecoration(colors.accent),
                      child: Text(
                        'А?',
                        style: TextStyle(
                          color: colors.bg,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
