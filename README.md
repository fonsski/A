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

### Тестовые сборки для iOS и macOS (отладка на своих устройствах)

Версия приложения — `0.0.1` (см. `CHANGELOG.md`). Bundle ID — `com.fonsski.aMessenger`.
Нужны Xcode и CocoaPods; для CocoaPods в терминале должна стоять UTF-8-локаль
(`export LANG=en_US.UTF-8`).

**macOS** (подпись для запуска на своём Mac не нужна):

```sh
flutter run -d macos
flutter build macos --debug      # build/macos/Build/Products/Debug/a_messenger.app
```

**iPhone / iPad:**

1. Включить на устройстве режим разработчика (Настройки → Конфиденциальность и
   безопасность → Режим разработчика) и подключить его к Mac.
2. Открыть `ios/Runner.xcworkspace` в Xcode, в Runner → Signing & Capabilities
   выбрать свою Team (бесплатного Apple ID достаточно, сборка живёт 7 дней).
   Если Bundle ID занят, поменять его на свой уникальный.
3. `flutter devices` — найти устройство, затем:

```sh
flutter run -d <id устройства>
flutter build ios --debug --no-codesign   # только проверка, что сборка собирается
```

Ключи Supabase передаются так же, как в разделе ниже (`--dart-define`). Без них
приложение работает на мок-данных. Запрошенные разрешения: камера, микрофон,
фото (iOS) и камера, микрофон, сеть, выбор файлов (macOS). Android-идентификатор
остался `com.example.a_messenger` — он не совпадает с iOS/macOS.

### Подключение реального бэкенда (Supabase)

1. Создать проект на supabase.com, включить Auth → Email → Confirm email.
2. Выполнить `supabase/schema.sql` в SQL Editor (для существующей базы —
   недостающие `supabase/fix_*.sql` по порядку).
3. Authentication → URL Configuration → Redirect URLs: добавить
   `com.fonsski.amessenger://reset-password` (возврат по ссылке из письма
   восстановления пароля). Для веба адрес сайта должен быть в этом же списке
   или совпадать с Site URL.
4. Authentication → Emails → SMTP Settings: включить свой SMTP. Встроенная
   почта Supabase доставляет письма только членам команды проекта.
5. Запустить с ключами:

```sh
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon или publishable ключ>
```

Без ключей приложение работает на мок-репозитории: «письмо» подтверждается
само через ~5 секунд, ник `de.panda` занят — удобно проверять валидацию.

`flutter test test/screenshot_capture_test.dart` рендерит все экраны в PNG
для визуальной сверки с макетом. Файлы попадают в `build/screenshots`
(или в папку из переменной окружения `SCREENSHOT_DIR`).
