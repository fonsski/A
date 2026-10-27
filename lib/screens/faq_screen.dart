import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Вопрос-ответ для экрана «Помощь / FAQ».
class FaqItem {
  const FaqItem(this.question, this.answer);

  final String question;
  final String answer;
}

const kFaqItems = [
  FaqItem(
    'Что означают «А» и «АА» у сообщения?',
    '«А» — сообщение отправлено, «АА» — собеседник его прочитал. '
        'В списке чатов отметка стоит рядом со временем, если последнее '
        'сообщение в диалоге — ваше.',
  ),
  FaqItem(
    'Как ответить на сообщение, закрепить или удалить его?',
    'Нажмите на сообщение и удерживайте — откроется меню: реакции, '
        'ответить, закрепить, удалить у себя или у всех '
        '(у всех — только свои сообщения).',
  ),
  FaqItem(
    'Как отправить голосовое сообщение или видеокружок?',
    'Пока поле ввода пустое, справа от него две кнопки: микрофон — запись '
        'голосового, камера — видеокружок. Для записи приложению нужен '
        'доступ к микрофону и камере.',
  ),
  FaqItem(
    'Как позвонить собеседнику?',
    'Откройте меню чата и выберите «Звонок». Звонить можно только тем, '
        'с кем уже есть переписка.',
  ),
  FaqItem(
    'Как войти по QR-коду?',
    'На экране входа покажите QR-код и отсканируйте его в приложении на '
        'телефоне, где вы уже вошли: «Настройки» → «Безопасность и вход».',
  ),
  FaqItem(
    'Как поставить код на вход в приложение?',
    '«Настройки» → «Приватность и конфиденциальность» → «Общая '
        'безопасность» → код для входа. Пустой код убирает защиту.',
  ),
  FaqItem(
    'Как скрыть стену или запретить комментарии?',
    '«Настройки» → «Приватность и конфиденциальность» → «Настройки стены». '
        'Там выбирается, кто видит стену, оставляет записи и комментирует.',
  ),
  FaqItem(
    'Как заблокировать пользователя?',
    '«Настройки» → «Приватность и конфиденциальность» → «Общая '
        'безопасность» → «Черный список». Между вами и заблокированным '
        'пользователем сообщения не отправляются.',
  ),
  FaqItem(
    'Фото в чатах не загружаются сами. Почему?',
    'Возможно, выключена «Автозагрузка медиа» в разделе «Память и данные». '
        'Нажмите на плашку с фото, чтобы загрузить его.',
  ),
];

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key, this.items = kFaqItems});

  final List<FaqItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 0),
              child: AHeader(
                title: 'Помощь / FAQ',
                onTapCircle: () => Navigator.of(context).pop(),
                circleChild: Icon(Icons.arrow_back, color: colors.bg, size: 18),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        decoration: pillDecoration(colors.surface, radius: 20),
                        child: Theme(
                          // Убираем линии-разделители у ExpansionTile.
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              12,
                            ),
                            expandedAlignment: Alignment.centerLeft,
                            iconColor: colors.accent,
                            collapsedIconColor: colors.accent,
                            title: Text(
                              item.question,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            children: [
                              Text(
                                item.answer,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ],
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
