import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/chat_repository.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/online_status.dart';
import 'photo_view_screen.dart';
import 'user_profile_screen.dart';

enum _MediaTab { photo, video, files, links }

/// Развёрнутая информация о чате (второй фрейм "Chat" в макете):
/// большой аватар, статус, кнопки Чат/Звук/Звонок и медиа переписки.
/// «Звонок» разворачивает плашку Аудио/Видео (group 10), кнопка
/// с аватаром посередине сворачивает её обратно.
/// Тап по имени открывает полный профиль собеседника.
class ChatInfoScreen extends StatefulWidget {
  const ChatInfoScreen({
    super.key,
    required this.peer,
    this.chatId,
    this.startCalling = false,
  });

  final UserSummary peer;
  final String? chatId;

  /// Открыть сразу с развёрнутой плашкой звонка (пункт меню «Звонок»).
  final bool startCalling;

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  late bool _calling = widget.startCalling;
  _MediaTab _tab = _MediaTab.photo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 21),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Аватар в белом кольце + кнопка закрытия справа.
              SizedBox(
                height: 128,
                child: Stack(
                  children: [
                    Center(
                      child: Container(
                        width: 128,
                        height: 128,
                        padding: const EdgeInsets.all(8),
                        decoration: pillDecoration(colors.surface, radius: 64),
                        child: AAvatar(size: 112, url: widget.peer.avatarUrl),
                      ),
                    ),
                    // По макету: «назад» слева, меню справа.
                    Align(
                      alignment: Alignment.topLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: pillDecoration(colors.surface),
                          child: Icon(Icons.arrow_back, color: colors.accent),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: pillDecoration(colors.surface),
                        child: Icon(Icons.more_vert, color: colors.accent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Тап по имени — полный профиль собеседника.
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(user: widget.peer),
                  ),
                ),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: pillDecoration(
                    colors.surface,
                    radius: 36,
                    inset: const Offset(0, -2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.peer.displayName,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: colors.accent, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OnlineStatus(
                userId: widget.peer.id,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              const SizedBox(height: 16),
              // Чат / Звук / Звонок <-> плашка звонка (group 10).
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _calling ? _buildCallBar(colors) : _buildActions(colors),
              ),
              const SizedBox(height: 16),
              _buildMediaTabs(colors),
              const SizedBox(height: 12),
              Expanded(child: _buildMedia(colors)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(AColors colors) {
    Widget action(String label, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: pillDecoration(
            colors.surface,
            radius: 24,
            inset: const Offset(0, -2),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );

    return Row(
      key: const ValueKey('actions'),
      children: [
        action('Чат', () => Navigator.of(context).pop()),
        const SizedBox(width: 12),
        action('Звук', () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Уведомления чата выключены')),
          );
        }),
        const SizedBox(width: 12),
        action('Звонок', () => setState(() => _calling = true)),
      ],
    );
  }

  /// Плашка звонка: Аудио | (аватар — свернуть) | Видео.
  Widget _buildCallBar(AColors colors) {
    Widget callButton(String label) => Expanded(
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label-звонки скоро появятся'))),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: pillDecoration(
            colors.card,
            radius: 24,
            inset: const Offset(0, -2),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: colors.accent,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );

    return Container(
      key: const ValueKey('call-bar'),
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: pillDecoration(
        colors.surface,
        radius: 24,
        inset: const Offset(0, -2),
      ),
      child: Row(
        children: [
          callButton('Аудио'),
          const SizedBox(width: 4),
          // В макете v2 по центру — стрелка-свернуть.
          GestureDetector(
            onTap: () => setState(() => _calling = false),
            child: Container(
              width: 40,
              height: 40,
              decoration: pillDecoration(colors.card, radius: 24),
              child: Icon(Icons.reply, color: colors.accent, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          callButton('Видео'),
        ],
      ),
    );
  }

  Widget _buildMediaTabs(AColors colors) {
    Widget tab(String label, _MediaTab value) => Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: _tab == value
              ? pillDecoration(
                  colors.accent,
                  radius: 20,
                  inset: const Offset(0, -2),
                )
              : null,
          child: Text(
            label,
            style: TextStyle(
              color: _tab == value ? colors.bg : colors.textSecondary,
              fontSize: 16,
              fontWeight: _tab == value ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: pillDecoration(
        colors.surface,
        radius: 24,
        inset: const Offset(0, -2),
      ),
      child: Row(
        children: [
          tab('Фото', _MediaTab.photo),
          tab('Видео', _MediaTab.video),
          tab('Файлы', _MediaTab.files),
          tab('Ссылки', _MediaTab.links),
        ],
      ),
    );
  }

  static const _empty = {
    _MediaTab.photo: 'Фото пока нет',
    _MediaTab.video: 'Видео пока нет',
    _MediaTab.files: 'Файлов пока нет',
    _MediaTab.links: 'Ссылок пока нет',
  };

  Future<void> _open(String url) async {
    if (!url.startsWith('http')) return; // мок-данные не открываем
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Не удалось открыть')));
      }
    }
  }

  Widget _buildMedia(AColors colors) {
    final chatId = widget.chatId;
    Widget empty() => Center(
      child: Text(
        _empty[_tab]!,
        style: TextStyle(color: colors.textSecondary, fontSize: 16),
      ),
    );
    if (chatId == null) return empty();

    return StreamBuilder<List<Message>>(
      stream: chatRepository.watchMessages(chatId),
      builder: (context, snapshot) {
        final messages = (snapshot.data ?? const <Message>[]).reversed.toList();

        switch (_tab) {
          case _MediaTab.photo:
            final photos = messages
                .where((m) => m.attachmentKind == AttachmentKind.image)
                .toList();
            if (photos.isEmpty) return empty();
            return GridView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              // Плитка не крупнее, чем в макете (176px), — на широком
              // экране колонок становится больше, а не плитка огромнее.
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: photos.length,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => PhotoViewScreen.open(
                  context,
                  photos[i].attachmentUrl!,
                  caption: photos[i].text.isEmpty ? null : photos[i].text,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image(
                    image: imageProviderFor(photos[i].attachmentUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: colors.card,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );

          case _MediaTab.video:
          case _MediaTab.files:
            final kind = _tab == _MediaTab.video
                ? AttachmentKind.video
                : AttachmentKind.file;
            final items = messages
                .where((m) => m.attachmentKind == kind)
                .toList();
            if (items.isEmpty) return empty();
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final m = items[i];
                return GestureDetector(
                  onTap: () => _open(m.attachmentUrl!),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: pillDecoration(colors.surface, radius: 16),
                    child: Row(
                      children: [
                        Icon(
                          kind == AttachmentKind.video
                              ? Icons.play_circle_outline
                              : Icons.insert_drive_file,
                          color: colors.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            m.attachmentName ??
                                (kind == AttachmentKind.video
                                    ? 'Видео'
                                    : 'Файл'),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          formatTime(m.sentAt),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );

          case _MediaTab.links:
            final links = [for (final m in messages) ...extractLinks(m.text)];
            if (links.isEmpty) return empty();
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: links.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => _open(links[i]),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: pillDecoration(colors.surface, radius: 16),
                  child: Row(
                    children: [
                      Icon(Icons.link, color: colors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          links[i],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}
