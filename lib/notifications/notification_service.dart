import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_repository.dart';
import '../data/chat_repository.dart';
import '../data/models.dart';
import 'web_notifier_stub.dart'
    if (dart.library.js_interop) 'web_notifier_web.dart'
    as notifier;

/// Чат, открытый на экране прямо сейчас, — по нему не уведомляем.
String? activeChatId;

const kNotifyDmPref = 'notif_dm';

/// Показывает системное уведомление о новом сообщении в закрытом чате.
/// На вебе — Notification API; на платформах без поддержки молчит.
class NotificationService {
  NotificationService(
    this._prefs, {
    Future<bool> Function()? ensurePermission,
    void Function(String title, String body)? show,
  }) : _ensurePermission = ensurePermission ?? notifier.ensurePermission,
       _show = show ?? notifier.showSystemNotification;

  final SharedPreferences _prefs;
  final Future<bool> Function() _ensurePermission;
  final void Function(String title, String body) _show;

  final _seen = <String, int>{};
  var _primed = false;
  StreamSubscription<List<ChatSummary>>? _chatsSub;

  bool get enabled => _prefs.getBool(kNotifyDmPref) ?? true;

  /// Подписывается после входа, отписывается при выходе.
  void init() {
    authRepository.snapshots.listen((auth) {
      if (auth != null && !auth.needsUsername) {
        _chatsSub ??= chatRepository.watchChats().listen(onChats);
      } else {
        _chatsSub?.cancel();
        _chatsSub = null;
        _seen.clear();
        _primed = false;
      }
    });
  }

  Future<void> onChats(List<ChatSummary> chats) async {
    if (!_primed) {
      // Первый снимок — базовая линия, по старым непрочитанным не шумим.
      for (final chat in chats) {
        _seen[chat.id] = chat.unread;
      }
      _primed = true;
      return;
    }
    for (final chat in chats) {
      final previous = _seen[chat.id] ?? 0;
      _seen[chat.id] = chat.unread;
      if (chat.unread > previous && chat.id != activeChatId && enabled) {
        if (await _ensurePermission()) {
          _show(chat.peerName, chat.lastText);
        }
      }
    }
  }
}

/// Назначается в main() до runApp.
late final NotificationService notificationService;
