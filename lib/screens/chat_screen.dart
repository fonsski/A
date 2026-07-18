import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../data/chat_repository.dart';
import '../data/models.dart';
import '../notifications/notification_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/online_status.dart';
import 'chat_info_screen.dart';
import 'photo_view_screen.dart';

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
  final _searchController = TextEditingController();
  var _searchMode = false;
  var _searchQuery = '';
  var _lastMessages = const <Message>[];
  Message? _replyTo;

  @override
  void initState() {
    super.initState();
    activeChatId = widget.chatId; // по открытому чату не уведомляем
  }

  @override
  void dispose() {
    if (activeChatId == widget.chatId) activeChatId = null;
    _controller.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    chatRepository.sendMessage(widget.chatId, text, replyToId: _replyTo?.id);
    _controller.clear();
    setState(() => _replyTo = null);
    // Не теряем фокус — чаттинг без лишних тапов.
    _inputFocus.requestFocus();
  }

  void _openInfo() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatInfoScreen(chatId: widget.chatId, peer: widget.peer),
      ),
    );
  }

  Future<void> _attach() async {
    final colors = context.colors;
    final kind = await showModalBottomSheet<AttachmentKind>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (kind, icon, label) in [
              (AttachmentKind.image, Icons.image_outlined, 'Фото'),
              (AttachmentKind.video, Icons.videocam_outlined, 'Видео'),
              (AttachmentKind.file, Icons.attach_file, 'Файл'),
            ])
              ListTile(
                leading: Icon(icon, color: colors.accent),
                title: Text(label, style: TextStyle(color: colors.textPrimary)),
                onTap: () => Navigator.of(sheet).pop(kind),
              ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;

    try {
      Uint8List? bytes;
      String? mime;
      String? name;
      switch (kind) {
        case AttachmentKind.image:
          final picked = await ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: 1280,
            maxHeight: 1280,
            imageQuality: 85,
          );
          if (picked == null) return;
          bytes = await picked.readAsBytes();
          mime = picked.mimeType ?? 'image/jpeg';
          name = picked.name;
        case AttachmentKind.video:
          final picked = await ImagePicker().pickVideo(
            source: ImageSource.gallery,
          );
          if (picked == null) return;
          bytes = await picked.readAsBytes();
          mime = picked.mimeType ?? 'video/mp4';
          name = picked.name;
        case AttachmentKind.file:
          final picked = await fs.openFile();
          if (picked == null) return;
          bytes = await picked.readAsBytes();
          mime = picked.mimeType ?? 'application/octet-stream';
          name = picked.name;
      }
      if (!mounted) return;
      // Подпись к медиа, как в Telegram; null — передумал отправлять.
      final caption = await _askCaption(kind, name, bytes);
      if (caption == null) return;
      await chatRepository.sendAttachment(
        widget.chatId,
        bytes,
        mime,
        name,
        kind,
        caption: caption,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Вложение не отправилось: $e')));
      }
    }
    _inputFocus.requestFocus();
  }

  Future<String?> _askCaption(
    AttachmentKind kind,
    String filename,
    Uint8List bytes,
  ) {
    final colors = context.colors;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kind == AttachmentKind.image)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(bytes, height: 200, fit: BoxFit.contain),
              )
            else
              Row(
                children: [
                  Icon(
                    kind == AttachmentKind.video
                        ? Icons.play_circle_outline
                        : Icons.insert_drive_file,
                    color: colors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      filename,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Подпись (необязательно)',
                hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
              onSubmitted: (_) =>
                  Navigator.of(dialog).pop(controller.text.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(
              'Отмена',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(controller.text.trim()),
            child: Text(
              'Отправить',
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Меню чата из макета: Поиск / Звонок / Очистить чат / Удалить чат.
  Widget _buildMenu(AColors colors) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: colors.accent, size: 20),
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        for (final (value, label) in [
          ('search', 'Поиск'),
          ('call', 'Звонок'),
          ('clear', 'Очистить чат'),
          ('delete', 'Удалить чат'),
        ])
          PopupMenuItem(
            value: value,
            child: Text(
              label,
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
            ),
          ),
      ],
      onSelected: (value) => switch (value) {
        'search' => setState(() => _searchMode = true),
        'call' => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatInfoScreen(
              chatId: widget.chatId,
              peer: widget.peer,
              startCalling: true,
            ),
          ),
        ),
        'clear' => _confirmDestructive(
          title: 'Очистить чат?',
          body: 'Переписка удалится у обеих сторон.',
          action: 'Очистить',
          onConfirm: () => chatRepository.clearChat(widget.chatId),
        ),
        'delete' => _confirmDestructive(
          title: 'Удалить чат?',
          body: 'Чат и переписка удалятся у обеих сторон.',
          action: 'Удалить',
          onConfirm: () async {
            await chatRepository.deleteChat(widget.chatId);
            if (mounted) Navigator.of(context).pop();
          },
        ),
        _ => null,
      },
    );
  }

  /// Плашка закреплённого сообщения под шапкой (по макету):
  /// автор красным, превью, время; тап — скролл к сообщению, крестик — снять.
  Widget _buildPinnedBar(AColors colors) {
    return StreamBuilder<String?>(
      stream: chatRepository.watchPinned(widget.chatId),
      builder: (context, snapshot) {
        final pinnedId = snapshot.data;
        final message = _lastMessages
            .where((m) => m.id == pinnedId)
            .firstOrNull;
        if (message == null) return const SizedBox.shrink();
        final preview = message.attachmentKind != null
            ? attachmentPreview(message.attachmentKind!, message.text)
            : message.text;
        return Padding(
          padding: const EdgeInsets.fromLTRB(13, 8, 13, 0),
          child: GestureDetector(
            onTap: () => _scrollToMessage(message.id),
            child: Container(
              height: 36,
              padding: const EdgeInsets.only(left: 16, right: 4),
              decoration: pillDecoration(colors.surface, radius: 24),
              child: Row(
                children: [
                  Icon(Icons.push_pin, color: colors.accent, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    message.mine ? 'Вы' : widget.peer.displayName,
                    style: TextStyle(
                      color: colors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      preview,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textPrimary, fontSize: 12),
                    ),
                  ),
                  Text(
                    formatTime(message.sentAt),
                    style: TextStyle(color: colors.textSecondary, fontSize: 11),
                  ),
                  IconButton(
                    tooltip: 'Открепить',
                    icon: Icon(
                      Icons.close,
                      color: colors.textSecondary,
                      size: 16,
                    ),
                    onPressed: () => chatRepository.unpin(widget.chatId),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Меню по долгому нажатию на сообщение.
  Future<void> _showMessageSheet(Message message) async {
    final colors = context.colors;

    Widget item(IconData icon, String label, VoidCallback onTap) => Builder(
      builder: (sheet) => ListTile(
        leading: Icon(icon, color: colors.accent),
        title: Text(label, style: TextStyle(color: colors.textPrimary)),
        onTap: () {
          Navigator.of(sheet).pop();
          onTap();
        },
      ),
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            item(Icons.reply, 'Ответить', () {
              setState(() => _replyTo = message);
              _inputFocus.requestFocus();
            }),
            item(Icons.push_pin, 'Закрепить', () {
              chatRepository.pinMessage(widget.chatId, message.id);
            }),
            item(Icons.visibility_off_outlined, 'Удалить у себя', () {
              chatRepository.hideMessageForMe(widget.chatId, message.id);
            }),
            if (message.mine)
              item(Icons.delete_outline, 'Удалить у всех', () {
                _confirmDestructive(
                  title: 'Удалить у всех?',
                  body: 'Сообщение исчезнет у обеих сторон.',
                  action: 'Удалить',
                  onConfirm: () => chatRepository.deleteMessageForAll(
                    widget.chatId,
                    message.id,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  /// Плашка «Ответ на …» над полем ввода.
  Widget _buildReplyBar(AColors colors) {
    final reply = _replyTo;
    if (reply == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 0, 13, 4),
      child: Container(
        height: 36,
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: pillDecoration(colors.surface, radius: 18),
        child: Row(
          children: [
            Icon(Icons.reply, color: colors.accent, size: 16),
            const SizedBox(width: 8),
            Text(
              reply.mine ? 'Вы' : widget.peer.displayName,
              style: TextStyle(
                color: colors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                reply.preview,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textPrimary, fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: 'Отменить ответ',
              icon: Icon(Icons.close, color: colors.textSecondary, size: 16),
              onPressed: () => setState(() => _replyTo = null),
            ),
          ],
        ),
      ),
    );
  }

  /// Примерная прокрутка к сообщению по его позиции в списке.
  void _scrollToMessage(String messageId) {
    final index = _lastMessages.indexWhere((m) => m.id == messageId);
    if (index < 0 || !_scroll.hasClients || _lastMessages.length < 2) return;
    final target =
        _scroll.position.maxScrollExtent * index / (_lastMessages.length - 1);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildSearchBar(AColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 8, 13, 0),
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 20, right: 4),
        decoration: pillDecoration(colors.surface, radius: 24),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: 'Поиск по сообщениям...',
                  hintStyle: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Закрыть поиск',
              icon: Icon(Icons.close, color: colors.textSecondary, size: 18),
              onPressed: () => setState(() {
                _searchMode = false;
                _searchQuery = '';
                _searchController.clear();
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDestructive({
    required String title,
    required String body,
    required String action,
    required Future<void> Function() onConfirm,
  }) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          title,
          style: TextStyle(color: colors.textPrimary, fontSize: 18),
        ),
        content: Text(
          body,
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
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
              action,
              style: TextStyle(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await onConfirm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Не получилось: $e')));
      }
    }
  }

  var _didInitialScroll = false;

  /// Прыгаем в конец при открытии и при новых сообщениях, но только если
  /// пользователь и так у низа — читающего историю вниз не утаскиваем.
  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      final nearBottom = position.maxScrollExtent - position.pixels < 120;
      if (!_didInitialScroll || nearBottom) {
        _didInitialScroll = true;
        position.jumpTo(position.maxScrollExtent);
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
                            _buildMenu(colors),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildPinnedBar(colors),
            if (_searchMode) _buildSearchBar(colors),
            Expanded(
              child: StreamBuilder<List<Message>>(
                stream: chatRepository.watchMessages(widget.chatId),
                builder: (context, snapshot) {
                  var messages = snapshot.data ?? const <Message>[];
                  _lastMessages = messages;
                  final query = _searchQuery.trim().toLowerCase();
                  if (_searchMode && query.isNotEmpty) {
                    messages = messages
                        .where((m) => m.text.toLowerCase().contains(query))
                        .toList();
                  }
                  _scrollDown();
                  if (_searchMode && messages.isEmpty) {
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
                  return ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(13, 16, 13, 16),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final message = messages[i];
                      if (message.kind != MessageKind.user) {
                        return _SystemNote(message: message);
                      }
                      return GestureDetector(
                        onLongPress: () => _showMessageSheet(message),
                        child: _Bubble(
                          message: message,
                          replySource: message.replyToId == null
                              ? null
                              : _lastMessages
                                    .where((m) => m.id == message.replyToId)
                                    .firstOrNull,
                          onReplyTap: message.replyToId == null
                              ? null
                              : () => _scrollToMessage(message.replyToId!),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            _buildReplyBar(colors),
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
                              tooltip: 'Прикрепить',
                              icon: Icon(
                                Icons.attach_file,
                                color: colors.textSecondary,
                              ),
                              onPressed: _attach,
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

/// Системная отметка в ленте («Вы очистили чат» и т.п.) — серым по центру.
class _SystemNote extends StatelessWidget {
  const _SystemNote({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          message.systemText,
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Вложение в пузыре: фото — инлайном, видео — инлайн-плеером,
/// файл — плашкой с открытием.
class _Attachment extends StatelessWidget {
  const _Attachment({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    switch (message.attachmentKind) {
      case AttachmentKind.image || null:
        return GestureDetector(
          onTap: () => PhotoViewScreen.open(
            context,
            message.attachmentUrl!,
            caption: message.text.isEmpty ? null : message.text,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image(
              image: imageProviderFor(message.attachmentUrl!),
              width: 220,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 220,
                height: 120,
                color: colors.bg,
                alignment: Alignment.center,
                child: Icon(Icons.broken_image, color: colors.textSecondary),
              ),
            ),
          ),
        );
      case AttachmentKind.video:
        return _VideoBubble(message: message);
      case AttachmentKind.file:
        return _AttachmentTile(message: message, isVideo: false);
    }
  }
}

/// Плашка вложения (файл, либо видео там, где плеер недоступен).
class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.message, required this.isVideo});

  final Message message;
  final bool isVideo;

  Future<void> _open(BuildContext context) async {
    final url = message.attachmentUrl!;
    if (!url.startsWith('http')) return; // мок-данные не открываем
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть вложение')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () => _open(context),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              isVideo ? Icons.play_circle_outline : Icons.insert_drive_file,
              color: colors.accent,
              size: 32,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.attachmentName ?? (isVideo ? 'Видео' : 'Файл'),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
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
    );
  }
}

/// Инлайн-просмотр видео: тап — play/pause. Если плеер на платформе
/// недоступен или видео не грузится — обычная плашка с открытием наружу.
class _VideoBubble extends StatefulWidget {
  const _VideoBubble({required this.message});

  final Message message;

  @override
  State<_VideoBubble> createState() => _VideoBubbleState();
}

class _VideoBubbleState extends State<_VideoBubble> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final url = widget.message.attachmentUrl!;
    if (!url.startsWith('http')) {
      _failed = true; // мок-данные — сразу плашка
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    controller
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final controller = _controller;
    if (_failed || controller == null) {
      return _AttachmentTile(message: widget.message, isVideo: true);
    }
    if (!controller.value.isInitialized) {
      return Container(
        width: 220,
        height: 124,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 220,
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: GestureDetector(
            onTap: () => setState(() {
              controller.value.isPlaying
                  ? controller.pause()
                  : controller.play();
            }),
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(controller),
                if (!controller.value.isPlaying)
                  Container(
                    decoration: BoxDecoration(
                      color: colors.textPrimary.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.play_arrow, color: colors.bg, size: 32),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.replySource, this.onReplyTap});

  final Message message;

  /// Исходное сообщение, если это ответ (null — удалено или не найдено).
  final Message? replySource;
  final VoidCallback? onReplyTap;

  /// Цитата исходника над текстом ответа: полоска, автор, превью.
  Widget _replyBlock(BuildContext context, AColors colors) {
    return GestureDetector(
      onTap: onReplyTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.accent, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              replySource == null
                  ? 'Сообщение удалено'
                  : (replySource!.mine ? 'Вы' : 'Собеседник'),
              style: TextStyle(
                color: colors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (replySource != null)
              Text(
                replySource!.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.textSecondary, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

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
            if (message.replyToId != null) _replyBlock(context, colors),
            if (message.attachmentUrl != null) _Attachment(message: message),
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
