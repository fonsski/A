/// Заглушка для платформ без системных уведомлений (desktop/тесты).
library;

bool get supported => false;

Future<bool> ensurePermission() async => false;

void showSystemNotification(String title, String body) {}
