/// Вход по QR-коду: экран входа показывает код, залогиненный телефон
/// подтверждает вход (см. supabase/functions/qr-login).
library;

/// Сессия QR-входа, открытая на экране входа.
class QrLoginSession {
  const QrLoginSession({
    required this.id,
    required this.payload,
    required this.claim,
    required this.expiresAt,
  });

  final String id;

  /// Текст внутри QR: его читает телефон ([parseQrPayload]).
  final String payload;

  /// Секрет, который знает только экран входа, — им он забирает вход.
  final String claim;
  final DateTime expiresAt;

  bool get expired => DateTime.now().isAfter(expiresAt);
}

enum QrPoll { pending, signedIn, expired }

const _prefix = 'a-qr';

/// Содержимое QR: `a-qr:<id>:<code>`.
String buildQrPayload(String id, String code) => '$_prefix:$id:$code';

/// Разбирает содержимое QR; null — это не наш код.
({String id, String code})? parseQrPayload(String raw) {
  final parts = raw.trim().split(':');
  if (parts.length != 3 || parts[0] != _prefix) return null;
  if (parts[1].isEmpty || parts[2].isEmpty) return null;
  return (id: parts[1], code: parts[2]);
}
