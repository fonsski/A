import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/wall_repository.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/post_card.dart';
import 'new_post_screen.dart';

class WallScreen extends StatefulWidget {
  const WallScreen({super.key});

  @override
  State<WallScreen> createState() => _WallScreenState();
}

class _WallScreenState extends State<WallScreen> {
  bool _mine = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 16, 13, 0),
          child: Column(
            children: [
              const AHeader(title: 'Стенка'),
              const SizedBox(height: 8),
              Container(
                height: 36,
                padding: const EdgeInsets.all(2),
                decoration: pillDecoration(colors.surface),
                child: Row(
                  children: [
                    _WallTab(
                      label: 'Моё!',
                      selected: _mine,
                      onTap: () => setState(() => _mine = true),
                    ),
                    _WallTab(
                      label: 'А?',
                      selected: !_mine,
                      onTap: () => setState(() => _mine = false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              APill(
                color: colors.accent,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewPostScreen()),
                ),
                child: Text(
                  'Новый пост?',
                  style: TextStyle(
                    color: colors.bg,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<Post>>(
            stream:
                _mine ? wallRepository.watchMine() : wallRepository.watchFeed(),
            builder: (context, snapshot) {
              final posts = snapshot.data ?? const <Post>[];
              if (snapshot.hasData && posts.isEmpty) {
                return Center(
                  child: Text(
                    _mine ? 'На твоей стенке пусто.\nНовый пост?' : 'Лента пуста',
                    textAlign: TextAlign.center,
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

/// Нижняя шторка «добавить комментарий».
Future<void> showCommentSheet(BuildContext context, String postId) {
  final controller = TextEditingController();
  final colors = context.colors;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        16, 16, 16, 16 + MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Комментарий...',
                hintStyle:
                    TextStyle(color: colors.textSecondary, fontSize: 16),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: colors.accent),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                wallRepository.addComment(postId, text);
              }
              Navigator.of(sheetContext).pop();
            },
          ),
        ],
      ),
    ),
  );
}

class _WallTab extends StatelessWidget {
  const _WallTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(32),
                )
              : null,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? colors.textPrimary : colors.textSecondary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
