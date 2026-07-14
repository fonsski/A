import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

enum _MediaTab { photo, video, files }

/// Развёрнутая информация о чате (второй фрейм "Chat" в макете):
/// большой аватар, статус, кнопки Чат/Звук/Звонок и медиа собеседника.
/// «Звонок» разворачивает плашку Аудио/Видео (group 10), кнопка
/// с аватаром посередине сворачивает её обратно.
class ChatInfoScreen extends StatefulWidget {
  const ChatInfoScreen({super.key, required this.name, this.avatarUrl});

  final String name;
  final String? avatarUrl;

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  bool _calling = false;
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
                        child: AAvatar(size: 112, url: widget.avatarUrl),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: pillDecoration(colors.surface),
                          child: Icon(Icons.close, color: colors.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 48,
                alignment: Alignment.center,
                decoration: pillDecoration(colors.surface,
                    radius: 36, inset: const Offset(0, -2)),
                child: Text(
                  widget.name,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'в сети',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
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
              decoration: pillDecoration(colors.surface,
                  radius: 24, inset: const Offset(0, -2)),
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
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label-звонки скоро появятся')),
            ),
            child: Container(
              height: 40,
              alignment: Alignment.center,
              decoration: pillDecoration(colors.card,
                  radius: 24, inset: const Offset(0, -2)),
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
      decoration: pillDecoration(colors.surface,
          radius: 24, inset: const Offset(0, -2)),
      child: Row(
        children: [
          callButton('Аудио'),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => setState(() => _calling = false),
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(6),
              decoration: pillDecoration(colors.card, radius: 24),
              child: AAvatar(size: 28, url: widget.avatarUrl),
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
                  ? pillDecoration(colors.accent,
                      radius: 20, inset: const Offset(0, -2))
                  : null,
              child: Text(
                label,
                style: TextStyle(
                  color:
                      _tab == value ? colors.bg : colors.textSecondary,
                  fontSize: 16,
                  fontWeight:
                      _tab == value ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: pillDecoration(colors.surface,
          radius: 24, inset: const Offset(0, -2)),
      child: Row(
        children: [
          tab('Фото', _MediaTab.photo),
          tab('Видео', _MediaTab.video),
          tab('Файлы', _MediaTab.files),
        ],
      ),
    );
  }

  Widget _buildMedia(AColors colors) {
    if (_tab != _MediaTab.photo) {
      return Center(
        child: Text(
          _tab == _MediaTab.video ? 'Видео пока нет' : 'Файлов пока нет',
          style: TextStyle(color: colors.textSecondary, fontSize: 16),
        ),
      );
    }
    return GridView.count(
      padding: const EdgeInsets.only(bottom: 16),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (var i = 0; i < 6; i++)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/media.png', fit: BoxFit.cover),
          ),
      ],
    );
  }
}
