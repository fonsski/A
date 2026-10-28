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

Приложение работает только с реальным Supabase: ключи берутся из
`dart_defines.json` (см. ниже). Запускать через скрипт:

```sh
./run.sh macos               # или chrome, id iPhone и т. д.
```

Без ключей (обычный `flutter run`) показывается экран «Нет ключей Supabase».

### Тестовые сборки для iOS и macOS (отладка на своих устройствах)

Версия приложения — `0.0.1` (см. `CHANGELOG.md`). Bundle ID — `com.fonsski.aMessenger`.
Нужны Xcode и CocoaPods; для CocoaPods в терминале должна стоять UTF-8-локаль
(`export LANG=en_US.UTF-8`).

**macOS** (подпись для запуска на своём Mac не нужна):

```sh
./run.sh macos
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
./run.sh <id устройства>             # debug: только пока подключено к Flutter
./run.sh <id устройства> --release   # автономная сборка для запуска с домашнего экрана
flutter build ios --debug --no-codesign   # только проверка, что сборка собирается
```

Debug-сборку iOS 14+ нельзя открыть с домашнего экрана («debug mode Flutter
apps can only be launched from Flutter tooling»), для этого нужен `--release`.
Если `flutter run` на телефоне виснет на «Xcode is taking longer…», проверьте,
что `xcode-select -p` указывает на Xcode, поддерживающий iOS телефона, и
включите `flutter config --enable-lldb-debugging`. После `--release` приложение
может не найтись по пути `build/ios/iphoneos` — ставьте
`xcrun devicectl device install app --device <id> build/ios/iphoneos/Runner.app`.

Ключи Supabase нужны всегда (раздел ниже). Запрошенные разрешения: камера, микрофон,
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
5. Скопировать `dart_defines.example.json` в `dart_defines.json` (файл в
   `.gitignore`), вписать URL проекта и anon/publishable ключ и запускать с ним:

```sh
./run.sh chrome
./run.sh macos
./run.sh <id iPhone>
```

(то же вручную: `flutter run -d macos --dart-define-from-file=dart_defines.json`
или по одному ключу: `--dart-define=SUPABASE_URL=…`
`--dart-define=SUPABASE_ANON_KEY=…`).

Мок-репозитории (`Mock*Repository`) остались только для тестов.

`flutter test test/screenshot_capture_test.dart` рендерит все экраны в PNG
для визуальной сверки с макетом. Файлы попадают в `build/screenshots`
(или в папку из переменной окружения `SCREENSHOT_DIR`).
