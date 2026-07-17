import 'package:flutter/material.dart';

import '../data/chat_repository.dart';
import '../data/models.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Image.asset('assets/images/flag.png', height: 16),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      themeMode.value = themeMode.value == ThemeMode.light
                          ? ThemeMode.dark
                          : ThemeMode.light;
                    },
                    child: Text(
                      themeMode.value == ThemeMode.light ? 'DARK' : 'LIGHT',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AHeader(
                title: 'Чаты',
                circleChild: Icon(
                  Icons.person_add_alt_1,
                  color: colors.bg,
                  size: 18,
                ),
                onTapCircle: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewChatScreen()),
                ),
              ),
              const SizedBox(height: 8),
              APill(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v.trim()),
                  style: TextStyle(color: colors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: 'Поиск по чатам...',
                    hintStyle: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: StreamBuilder<List<ChatSummary>>(
            stream: chatRepository.watchChats(),
            builder: (context, snapshot) {
              final chats = (snapshot.data ?? const <ChatSummary>[])
                  .where(
                    (c) =>
                        _query.isEmpty ||
                        c.peerName.toLowerCase().contains(_query.toLowerCase()),
                  )
                  .toList();
              if (snapshot.hasData && chats.isEmpty) {
                if (_query.isNotEmpty) {
                  return Center(
                    child: Text(
                      'Ничего не нашлось',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Пока нет чатов',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      APill(
                        color: colors.accent,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NewChatScreen(),
                          ),
                        ),
                        child: Text(
                          'Найти собеседника',
                          style: TextStyle(
                            color: colors.bg,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: chats.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _ChatTile(chat: chats[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat});

  final ChatSummary chat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () {
        chatRepository.markRead(chat.id);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(chatId: chat.id, peer: chat.peer),
          ),
        );
      },
      child: Container(
        height: 72,
        color: colors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Row(
          children: [
            AAvatar(size: 56, url: chat.peerAvatarUrl),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.peerName,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastText,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (chat.unread > 0)
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${chat.unread}',
                            style: TextStyle(
                              color: colors.surface,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  formatTime(chat.lastAt),
                  style: TextStyle(color: colors.textSecondary, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
