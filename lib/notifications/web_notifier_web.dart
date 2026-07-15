/// Системные уведомления браузера (Notification API).
library;

import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool get supported => true;

Future<bool> ensurePermission() async {
  switch (web.Notification.permission) {
    case 'granted':
      return true;
    case 'denied':
      return false;
    default:
      final result = await web.Notification.requestPermission().toDart;
      return result.toDart == 'granted';
  }
}

void showSystemNotification(String title, String body) {
  web.Notification(title, web.NotificationOptions(body: body));
}
