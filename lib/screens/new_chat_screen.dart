import 'dart:async';

import 'package:flutter/material.dart';

import '../data/chat_repository.dart';
import '../data/friends_repository.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';

/// Поиск людей по @нику или имени и старт диалога.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<UserSummary> _results = const [];
  bool _searching = false;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = const [];
        _searched = false;
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      final results = await chatRepository.searchUsers(query);
      if (!mounted || _controller.text != query) return;
      setState(() {
        _results = results;
        _searching = false;
        _searched = true;
      });
    });
  }

  Future<void> _openDm(UserSummary user) async {
    final chatId = await chatRepository.startDm(user);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatScreen(chatId: chatId, peer: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: pillDecoration(colors.surface),
                          child: Icon(
                            Icons.arrow_back,
                            color: colors.accent,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          alignment: Alignment.centerLeft,
                          decoration: pillDecoration(colors.accent),
                          child: Text(
                            'Новый чат',
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
                  const SizedBox(height: 8),
                  APill(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: _onQueryChanged,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isCollapsed: true,
                        hintText: '@ник или имя...',
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
              child: _searching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? Center(
                      child: Text(
                        _searched
                            ? 'Никого не нашлось'
                            : 'Найди собеседника по @нику\nили имени',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      itemBuilder: (context, i) =>
                          _resultTile(context, _results[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _NewChatScreenState {
  Widget _resultTile(BuildContext context, UserSummary user) {
    final colors = context.colors;
    return AUserTile(
      name: user.displayName,
      username: user.username,
      avatarUrl: user.avatarUrl,
      onTap: () => _openDm(user),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'В друзья',
            icon: Icon(Icons.person_add_alt_1, color: colors.accent),
            onPressed: () {
              friendsRepository.sendRequest(user.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Заявка @${user.username} отправлена')),
              );
            },
          ),
          Icon(Icons.chevron_right, color: colors.accent),
        ],
      ),
    );
  }
}
