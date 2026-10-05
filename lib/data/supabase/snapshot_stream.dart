import 'dart:async';

/// Поток «текущее значение, затем обновления» без потерь.
///
/// Наивная запись `async*` с `yield текущее; yield* live` теряет событие,
/// пришедшее между этими двумя шагами: подписка на [live] оформляется только
/// после того, как слушатель забрал первое значение. Здесь порядок обратный —
/// сначала подписываемся на [live], потом отдаём [snapshot].
///
/// [afterSubscribe] вызывается уже после подписки (например, чтобы запросить
/// свежие данные: ответ придёт в [live], когда мы уже слушаем).
Stream<T> snapshotThenUpdates<T>(
  Stream<T> live, {
  T? Function()? snapshot,
  void Function()? afterSubscribe,
}) {
  late final StreamController<T> out;
  StreamSubscription<T>? sub;
  out = StreamController<T>(
    onListen: () {
      sub = live.listen(out.add, onError: out.addError);
      final current = snapshot?.call();
      if (current != null) out.add(current);
      afterSubscribe?.call();
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () => sub?.cancel(),
  );
  return out.stream;
}
