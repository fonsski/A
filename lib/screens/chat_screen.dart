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
                title: Text(label,
                    style: TextStyle(color: colors.textPrimary)),
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
          final picked =
              await ImagePicker().pickVideo(source: ImageSource.gallery);
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
          widget.chatId, bytes, mime, name, kind,
          caption: caption);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Вложение не отправилось: $e')),
        );
      }
    }
    _inputFocus.requestFocus();
  }

  Future<String?> _askCaption(
      AttachmentKind kind, String filename, Uint8List bytes) {
    final colors = context.colors;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: colors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                      style:
                          TextStyle(color: colors.textPrimary, fontSize: 14),
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
                hintStyle:
                    TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
              onSubmitted: (_) =>
                  Navigator.of(dialog).pop(controller.text.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text('Отмена',
                style: TextStyle(color: colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(controller.text.trim()),
            child: Text(
              'Отправить',
              style: TextStyle(
                  color: colors.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
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
                              tooltip: 'Прикрепить',
                              icon: Icon(Icons.attach_file,
                                  color: colors.textSecondary),
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
    controller.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {
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
            if (message.attachmentUrl != null)
              _Attachment(message: message),
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
