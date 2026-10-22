# Yumi Browser (iOS 12)

Браузер под джейлбрейкнутый iOS 12. Сделан под аниме-сайты и онлайн-кинотеатры
с HLS/mp4-плеерами: находит поток, который использует плеер на странице, и играет
его **нативно** в AVPlayer — с нужными `Referer`, `Origin`, `User-Agent` и cookies.

## Что умеет

- Вкладки, адресная строка, поиск (Яндекс), кнопки назад/вперёд/домой, прогресс загрузки.
- Сохранение сессии: после перезапуска вкладки открываются заново.
- Persistent cookies — логин на сайтах не слетает.
- User-Agent: мобильный Safari 12 / полный macOS Safari / своя строка.
  Режим «полная версия» переключается отдельно для каждого сайта (меню → Полная версия).
- Перехват `m3u8` / `mp4` / `mpd`: из `fetch`, XHR, `video.src`, `setAttribute`, DOM.
  При находке сверху появляется плашка «Поток найден» → кнопка ▶ открывает системный плеер.
- Нативный плеер получает Referer/Origin/UA/Cookie и умеет открыть поток в VLC/nPlayer,
  если не справился сам.
- Блокировка рекламы: `WKContentRuleList` (сеть) + косметические правила (JS).
- Полифиллы для WebKit iOS 12 (Promise.finally, Object.fromEntries, flat, matchAll,
  IntersectionObserver, ResizeObserver и т.д.), чтобы современные сайты не падали.
- Попапы плеера (`window.open`/`target=_blank`) открываются в новой вкладке.
- **YummyAnime:** на странице тайтла появляется кнопка **▶ Серии**. Она открывает
  нативный список серий и озвучек и запускает HLS напрямую через AVPlayer — без
  сломанного плеера CDNVideoHub (он не работает на WebKit iOS 12).

## Что не умеет (и не сможет)

- **Кинопоиск, Netflix, IVI, Wink — платный контент.** Он закрыт DRM (Widevine/FairPlay).
  На iOS 12 это не играет ни в одном браузере, включая свежий Safari. Страницы и трейлеры
  открываются, фильмы — нет. Обхода нет.
- Сайты, которым нужен MSE (MediaSource Extensions) на iPhone. В iOS 12 MSE на iPhone
  отсутствует физически. Если плеер отдаёт готовый `m3u8` — сработает нативный HLS,
  если крутит сегменты через MSE — нет.
- Синтаксис JS новее ES2017 (`?.`, `??`, `\p{...}`) полифиллами не лечится: это ошибка
  парсинга. Если сайт на них — поможет только его старая/мобильная версия.

## Сборка (Windows → GitHub Actions)

Локально на Windows iOS-приложение не собрать (нужен clang + SDK). Поэтому сборка в облаке:

1. Создай репозиторий на GitHub и запушь эту папку:
   ```bash
   git remote add origin https://github.com/USER/yumi-browser.git
   git push -u origin main
   ```
2. Открой **Actions → Build → Run workflow** (или просто сделай push).
3. Через 5–10 минут скачай артефакт **Yumi-packages**:
   - `Yumi-1.0.1.deb` — для установки через Cydia/Filza/dpkg;
   - `Yumi-unsigned.ipa` — для AppSync Unified / sideload.

## Установка

**Вариант 1 — .deb (рекомендуется, iOS 12 rootful: unc0ver / checkra1n):**
- открыть `.deb` в Filza → Install, или по SSH: `dpkg -i Yumi-1.0.1.deb`, затем `uicache -a`;
- приложение появится на рабочем столе как **Yumi**.

**Вариант 2 — .ipa:**
- нужен **AppSync Unified** (repo: cydia.akemi.ai) или AltStore/Sideloadly с подписью;
- открыть `.ipa` в Filza → Install, либо установить через AppSync.

## Как пользоваться

1. Запусти Yumi, открой `old.yummyani.me`, залогинься (cookies сохраняются).
2. На странице тайтла нажми красную кнопку **▶ Серии** справа внизу → выбери серию и
   озвучку. Видео откроется в системном плеере: приложение берёт HLS напрямую из API
   CDNVideoHub, потому что штатный плеер сайта не запускается на WebKit iOS 12.
3. Для остальных сайтов: запусти плеер на странице серии.
3. Через пару секунд сверху появится плашка **«Поток найден»** — нажми ▶.
   Откроется системный плеер с правильными заголовками (Referer страницы, cookies домена).
4. Если потоков несколько (реклама/разные качества) — меню **⋯ → Потоки (N)** и выбери нужный.
5. Не играет?
   - меню → **Полная версия сайта**, перезагрузи страницу;
   - выключи блокировку рекламы в настройках (иногда режет плеер);
   - в плеере нажми **VLC** / **nPlayer**, если установлены;
   - проверь, что поток вообще HLS: сайты с MSE/DRM на iPhone не заиграют.

## Настройки

- **Версия сайта** — мобильная/полная по умолчанию.
- **User-Agent** — iOS Safari 12, macOS Safari 16 или своя строка.
- **Перехватывать потоки** — включён по умолчанию.
- **Автоматически играть HLS** — сразу открывать первый найденный HLS (по умолчанию выключено,
  чтобы не запускать рекламные вставки).
- **Блокировать рекламу** — сетевые правила WebKit + косметика.
- **Очистить кэш и cookies**, **Сбросить настройки**.

## Структура

```
Makefile                     Theos
control                      метаданные .deb
LaunchScreen.storyboard      компилируется в CI через ibtool
YumiBrowser/
  main.m                     AppDelegate
  BrowserViewController.*    вкладки, бары, меню, плашка потока
  YumiTab.*                  WKWebView на вкладку, навигация, cookies, перехват ссылок
  YumiBridge.*               JS → native
  YumiScripts.*              загрузка JS/HTML из бандла
  YumiSettings.*             NSUserDefaults
  YumiAdBlocker.*            WKContentRuleList
  YumiPlayer.*               AVPlayer + Referer/Cookie + VLC/nPlayer
  TabsViewController.*       список вкладок
  SettingsViewController.*   настройки
  YumiIcons.*                иконки, нарисованные кодом
  Resources/
    Info.plist
    polyfills.js             шимы WebKit iOS 12
    hook.js                  перехват потоков + косметика
    home.html                стартовая страница
    Icon-*.png               иконки (генерируются tools/make-icons.ps1)
```

## Отладка

Логи приложения: `idevicesyslog | grep Yumi` (libimobiledevice) или в Xcode Devices.
Если сборка упала — смотри лог шага **Build** в Actions: чаще всего это несовместимость
Theos/SDK, лечится сменой `runs-on` (macos-14 → macos-13) и версии SDK.
