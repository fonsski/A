import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/chat_repository.dart';
import '../data/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/online_status.dart';
import 'chat_info_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chatId, required this.peer});

  final String chatId;
  final UserSummary peer;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    chatRepository.sendMessage(widget.chatId, text);
    _controller.clear();
    // Не теряем фокус — чаттинг без лишних тапов.
    _inputFocus.requestFocus();
  }

  void _openInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatInfoScreen(
          chatId: widget.chatId,
          peer: widget.peer,
        ),
      ),
    );
  }

  Future<void> _attachImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    try {
      final bytes = await picked.readAsBytes();
      await chatRepository.sendImage(
        widget.chatId,
        bytes,
        picked.mimeType ?? 'image/jpeg',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Фото не отправилось: $e')),
        );
      }
    }
    _inputFocus.requestFocus();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
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
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      chatRepository.markRead(widget.chatId);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: pillDecoration(colors.surface),
                      child: Icon(Icons.arrow_back, color: colors.accent),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: _openInfo,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: pillDecoration(colors.surface),
                        child: Row(
                          children: [
                            AAvatar(size: 40, url: widget.peer.avatarUrl),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.peer.displayName,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  OnlineStatus(
                                    userId: widget.peer.id,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.more_vert,
                                color: colors.accent, size: 20),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: chatRepository.watchMessages(widget.chatId),
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? const <Message>[];
                  _scrollDown();
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(13, 16, 13, 16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) =>
                        _Bubble(message: messages[i]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.only(left: 28, right: 4),
                      decoration: pillDecoration(colors.surface),
                      child: Center(
                        child: TextField(
                          controller: _controller,
                          focusNode: _inputFocus,
                          onSubmitted: (_) => _send(),
                          textAlignVertical: TextAlignVertical.center,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: 'Сообщение',
                            hintStyle: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 16,
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Прикрепить фото',
                              icon: Icon(Icons.image_outlined,
                                  color: colors.textSecondary),
                              onPressed: _attachImage,
                            ),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.65,
        ),
        // В макете у пузырей inset-тень со стороны «хвоста».
        decoration: pillDecoration(
          message.mine ? colors.bubbleOut : colors.bubbleIn,
          radius: 12,
          inset: Offset(message.mine ? -2 : 2, -2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: imageProviderFor(message.imageUrl!),
                  width: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 220,
                    height: 120,
                    color: colors.bg,
                    alignment: Alignment.center,
                    child: Icon(Icons.broken_image,
                        color: colors.textSecondary),
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  height: 1.2,
                ),
              ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatTime(message.sentAt),
                  style: TextStyle(
                    color: message.mine ? colors.accent : colors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                if (message.mine) ...[
                  const SizedBox(width: 4),
                  Text(
                    'АА',
                    style: TextStyle(color: colors.accent, fontSize: 10),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
