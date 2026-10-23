# Yumi Browser — прогресс

Цель: браузер под jailbreak iOS 12, чтобы работал old.yummyani.me и грузились плееры
(перехват m3u8/mp4 + нативное воспроизведение в AVPlayer с нужным Referer/Cookie).
Кинопоиск: DRM — не поддерживается by design (см. README).

## Этапы

- [x] Каркас репозитория, git, структура проекта
- [x] JS: polyfills.js (WebKit 12), hook.js (перехват потоков), home.html
- [x] ObjC: YumiSettings, YumiAdBlocker, YumiIcons
- [x] ObjC: YumiTab, YumiBridge, YumiScripts
- [x] ObjC: BrowserViewController (вкладки, адресная строка, баннер потока)
- [x] ObjC: YumiPlayer (AVPlayer + headers), TabsViewController, SettingsViewController
- [x] Info.plist, иконки (сгенерированы tools/make-icons.ps1)
- [x] GitHub Actions (macOS, Theos) → .deb + .ipa
- [x] README с инструкцией установки и ограничениями
- [x] Первая сборка в CI (run 39638177188), артефакты скачаны и проверены
- [x] Релиз v1.0.0 на GitHub
- [x] Разбор плеера YummyAnime: CDNVideoHub (CVH) / VK Video CDN
- [x] v1.0.1: нативный список серий и HLS через API CVH (кнопка «▶ Серии»)
- [x] v1.0.1: CI зелёный, релиз с .deb и .ipa опубликован
- [ ] Тест v1.0.1 на устройстве: список серий и воспроизведение HLS

## Принятые решения

- Theos-проект, ObjC + ARC, `TARGET = iphone:clang:latest:12.0`, `ARCHS = arm64`
  (arm64-бинарник работает и на arm64e-устройствах, меньше проблем с подписью).
- Исходники в `YumiBrowser/`, ресурсы в `Resources/` (стандартные пути Theos).
- Сборка только в CI: локально на Windows нет clang/Theos.
- Один WKWebView на вкладку, persistent cookies (логин сохраняется).
- Перехват потоков из JS (fetch/XHR/video.src) → сообщение в native → AVPlayer
  с заголовками Referer/Origin/User-Agent/Cookie (AVURLAssetHTTPHeaderFieldsKey).
- Реклама: WKContentRuleList (сетевой блок) + косметический JS.
- LaunchScreen.storyboard компилируется в CI через ibtool (Theos не умеет storyboard).
- Настройки: UA (mobile/desktop/custom), desktop-режим по домену, авто-плеер,
  блок рекламы, очистка данных, сброс.
- YummyAnime: не пытаемся чинить JS-плеер сайта, а идём в API CVH напрямую и
  играем HLS в AVPlayer. Для страницы тайтла показываем кнопку «▶ Серии».

## Почему плеер YummyAnime «бесконечно грузится»

Штатный плеер — CDNVideoHub: `<video-player>` + `player.cdnvideohub.com/s2/stable/video-player.umd.js`.
В бандле 86 вхождений `??`, а также `?.`, `import.meta` и ES-модули. WebKit iOS 12
не умеет парсить этот синтаксис — скрипт падает целиком, плеер остаётся со спиннером.
Полифиллы тут не помогают: это ошибка парсинга, а не отсутствие API.

## Как обходим

1. На странице `/catalog/item/...` берём `page_id` из `meta#short_link` (или `.rating-info[data-id]`).
2. `GET https://old.yummyani.me/api/anime/{page_id}/videos`
   (заголовки `X-Application: wawegr8j13it4rdw`, `Lang: ru`, `Vary: json`).
3. Из `iframe_url` берём `anime_id`, `episode`, `dubbing_code`; показываем серии/озвучки.
4. `GET https://plapi.cdnvideohub.com/api/v1/player/sv/playlist?pub=745&aggr=mali&id={anime_id}&ep={episode}`
   (Origin/Referer `https://player.cdnvideohub.com`).
5. Выбираем озвучку по имени → `GET .../api/v1/player/sv/video/{vkId}`.
6. Берём `sources.hlsUrl` (VK CDN, `ok*.vkuser.net/video.m3u8`) → AVPlayer с
   Referer/Origin `https://player.cdnvideohub.com/` и Chrome UA.

Проверено с ПК: playlist и video отдают 200, `hlsUrl` присутствует. URL привязан
к IP запрашивающего и имеет `expires`, поэтому запрос должен идти с телефона
непосредственно перед воспроизведением (так и сделано).

## Что проверить на устройстве

1. Открыть тайтл на `old.yummyani.me` → появилась кнопка «▶ Серии».
2. Список серий/озвучек заполняется; выбор открывает AVPlayer и видео играет.
3. Если 403 — проверить, что Referer/Origin/UA доходят до CDN (лог `[Yumi]`).
4. Если кнопки нет — проверить, что страница именно `/catalog/item/...` и догрузилась.

## Заметки

- iOS 12 не поддерживает `?.`, `??`, `\p{...}` в JS — синтаксис не полифилится.
  Если сайт на них падает — только альтернативная (старая/мобильная) версия сайта.
- MSE на iPhone в iOS 12 нет вообще; спасает только нативный HLS/mp4.
- Запуск/тест только на живом устройстве; итерации по фидбеку.

## Журнал

- 21.10.2026: CI зелёный, артефакты собраны (.deb + .ipa).
  - исправлено: `constraintEqualToAnchor:` → `constraintEqualToConstant:`
  - исправлено: `[YumiSettings reset]` → `[[YumiSettings shared] reset]`
  - исправлено: тип `dictionaryRepresentation`
- Проверено: arm64, MinimumOSVersion 12.0, LaunchScreen.storyboardc на месте.
- 22.10.2026: разобран плеер YummyAnime (CVH/VK), реализован нативный резолвер
  серий и HLS, версия 1.0.1. CI зелёный, релиз v1.0.1 с .deb и .ipa опубликован.
  Проверено с ПК: master и variant m3u8 отдают 200, сегменты доступны.
- 22.10.2026: v1.0.2 — новый главный экран (логотип, только свои сайты, без поиска
  и подсказок), центральная кнопка потоков, исправленные иконки обновить/стоп,
  новый выбор серии/озвучки, память просмотра, выбор качества HLS, убрана своя
  кнопка закрытия плеера, нативная поддержка AniLibria/AKURO и блокировка
  несовместимых Next.js-скриптов AniLibria.
  - AniLibria: `/api/sources`, `/api/akuro/sources`, `/api/aniliberty/resolve`,
    `/api/akuro/stream` вызываются синхронным XHR из контекста страницы (обход
    проверки запроса); `/api/hls?u=...` и сегменты публичные, проверены с ПК.
  - VK остаётся недоступен: бандл VK использует `??`/`?.`, iOS 12 не парсит,
    `m.vk.com` редиректит на `badbrowser.php`. Это ограничение WebKit 12.
- 22.10.2026: v1.0.3 — поисковик (Яндекс/Bing/DuckDuckGo), режим инкогнито
  (non-persistent WKWebsiteDataStore, без сохранения сессии/памяти просмотра),
  выбор качества CVH из `mpeg*Url` (кнопка появляется, даже если HLS — media playlist),
  WebP-полифилл webp-hero для обложек AniLibria (лениво, видимые изображения,
  JPEG для крупных кадров). Версия 1.0.3 / build 4.
  - CI run `39769680676` — успешно; релиз v1.0.3 с `Yumi-1.0.3.deb` (282700 байт)
    и `Yumi-unsigned.ipa` (343301 байт) опубликован:
    https://github.com/w3rn1ght/yumi-browser/releases/tag/v1.0.3
- 23.10.2026: v1.0.4 — исправления по итогам проверки на iPad.
  - адресная строка: `UIKeyboardTypeWebSearch` вместо URL-клавиатуры, поэтому
    на iPad снова есть пробел; убран `textContentType = URL`.
  - GitHub: добавлен совместимый режим для Safari 12. Современный Primer CSS
    использует `:where()`, `:is()` и `@layer`, которые WebKit 12 игнорирует;
    из-за этого глобальная шапка раздувалась на несколько экранов и закрывала
    репозиторий. Скрипт определяет сломанную раскладку, скрывает глобальную
    шапку, убирает дубли колонок файловой таблицы и добавляет компактную
    панель «GitHub / Релизы / Вход». Страницы репозитория и релизов остаются
    читаемыми, ссылки на assets доступны.
  - загрузки: WKWebView на iOS 12 не умеет скачивать файлы. Добавлен нативный
    загрузчик: перехват `Content-Disposition: attachment` и файловых расширений
    (.deb, .ipa, .zip, .rar и т.д.), cookies и Referer берутся из вкладки,
    файл сохраняется в `Documents/Downloads`, затем открывается share sheet.
    В меню появились «Скачать файл по ссылке…» и «Релизы GitHub». В Info.plist
    включён `UIFileSharingEnabled`, поэтому папка видна в «Файлах».
  - AniLibria: добавлен совместимый слой цветов/прозрачности (чёрный экран из-за
    несовместимых CSS-переменных и `opacity-0`), WebP-полифилл теперь использует
    asm.js-фолбэк (WebAssembly отключён) и имеет переключатель
    «WebP-обложки AniLibria» в настройках. При повторном падении web-процесса
    показывается предупреждение с кнопкой «Без WebP-обложек» вместо
    бесконечной перезагрузки.
  - версия 1.0.4 / build 5.
  - CI run `39955917922` — первая сборка упала: приватный helper
    `downloadURL:suggestedFilename:` был объявлен, но не реализован;
    исправлено в коммите `72ff175`.
  - CI run `39956449034` — успешно. Проверено: IPA/deb содержат
    `github-compat.js`, `anilibria-compat.js`, `webp-hero.js`,
    `webp-images.js`; версия 1.0.4 / build 5; MinimumOSVersion 12.0;
    `UIFileSharingEnabled` включён.
  - Релиз v1.0.4 опубликован (tag `72ff175`):
    https://github.com/w3rn1ght/yumi-browser/releases/tag/v1.0.4
    `Yumi-1.0.4.deb` — 289828 байт, `Yumi-unsigned.ipa` — 353142 байта.
- 23.10.2026: v1.0.5 — best-effort восстановление капч на iOS 12.
  - `polyfills.js` теперь внедряется всегда, а не только при включённом
    перехвате потоков: капчи и современные сайты зависят от этих API.
  - Добавлены недостающие API, которые используют reCAPTCHA/hCaptcha/
    Turnstile/SmartCaptcha: `AggregateError`, `PointerEvent`, `Touch`,
    `visualViewport`, `screen.orientation`, `document.fonts`,
    `PerformanceObserver`, `ReportingObserver`, `createImageBitmap`,
    `OffscreenCanvas`, `AbortSignal.timeout`, `WebAssembly.*Streaming`,
    `CSS.escape`, `Element.animate`/`getAnimations`/`append`/`before`/
    `replaceChildren`, `HTMLFormElement.requestSubmit`, `navigator.permissions`/
    `mediaDevices`/`connection`/`deviceMemory`, итераторы для
    `NodeList`/`HTMLCollection`/`DOMTokenList`, `structuredClone` с Map/Set/
    ArrayBuffer.
  - `WKPreferences` включает WebGL приватными селекторами, если они есть
    (капчи и fingerprint-скрипты ожидают WebGL).
  - Правила блокировки: `yumi-ads-v3` с `ignore-previous-rules` для
    recaptcha/gstatic/challenges.cloudflare.com/hcaptcha/yandexcloud и
    yandex/checkcaptcha, чтобы косметика и хосты не ломали капчу.
  - Проверено в Chromium с удалёнными API: полифиллы не падают, виджеты
    reCAPTCHA (v2), hCaptcha и Turnstile создают iframe и API.
  - Ограничение: Cloudflare Turnstile и Google-вход всё равно могут требовать
    функций, которых нет в WebKit 12; это не гарантируется.
  - Версия 1.0.5 / build 6.
  - CI run `39973331528` — успешно. Проверено: IPA/deb содержат
    обновлённый `polyfills.js` (32548 байт), `github-compat.js`,
    `anilibria-compat.js`, `webp-hero.js`, `webp-images.js`; версия
    1.0.5 / build 6; MinimumOSVersion 12.0.
  - Релиз v1.0.5 опубликован (tag `5d19f04`):
    https://github.com/w3rn1ght/yumi-browser/releases/tag/v1.0.5
    `Yumi-1.0.5.deb` — 293956 байт, `Yumi-unsigned.ipa` — 358828 байт.
