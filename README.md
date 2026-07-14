# А? — мессенджер

Flutter-приложение по макету Figma
([Project «А?»](https://www.figma.com/design/lmShV4j83Xnp2kakE9Vj4R/Project-%22%D0%90-%22)).

## Экраны

- Вход / Регистрация по почте → подтверждение письма → выбор @ника и имени
- Сплэш с логотипом «А?»
- Чаты (список + диалог с пузырями сообщений)
- Стенка (лента постов, вкладки «Моё!» / «А?», комментарии, новый пост)
- Настройки (+ «Приватность и конфиденциальность» с сегментами Все/Друзья/Я)
- Профиль и редактор профиля
- Светлая и тёмная тема (кнопка DARK на экране чатов), палитра из макета

## Структура

- `lib/theme.dart` — палитра (`AColors`) и тема, шрифт Roboto Flex из `assets/fonts`
- `lib/auth/` — контракт `AuthRepository` + реализации: мок (по умолчанию) и Supabase;
  `AuthGate` выбирает экран по состоянию сессии
- `lib/data/` — `ChatRepository` и `WallRepository` (модели, мок и Supabase-реализации);
  мок отвечает на сообщения через секунду — удобно смотреть realtime-поведение UI
- `lib/widgets/` — общие элементы: пилюли, шапка, нижняя навигация, карточка поста
- `lib/screens/` — экраны (`screens/auth/` — вход, регистрация, подтверждение, выбор ника)
- `assets/images/` — логотип и иконки, выгруженные из Figma
- `supabase/schema.sql` — схема БД: profiles с уникальным @ником, RLS, RPC

## Запуск

```sh
flutter run -d chrome        # веб, мок-бэкенд (демо-аккаунт: demo@a.ru / password1)
flutter run                  # устройство/эмулятор
```

### Подключение реального бэкенда (Supabase)

1. Создать проект на supabase.com, включить Auth → Email → Confirm email.
2. Выполнить `supabase/schema.sql` в SQL Editor.
3. Запустить с ключами:

```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon или publishable ключ>
```

Без ключей приложение работает на мок-репозитории: «письмо» подтверждается
само через ~5 секунд, ник `de.panda` занят — удобно проверять валидацию.

`flutter test test/screenshot_capture_test.dart` рендерит все экраны в PNG
для визуальной сверки с макетом.
