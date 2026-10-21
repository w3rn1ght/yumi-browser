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
- [ ] Первая сборка в CI (локально на Windows нет clang/SDK — не проверялась компиляцией)
- [ ] Тест на устройстве: логин yummyani, перехват потока, нативный плеер

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

## Что проверить на первом запуске

1. Приложение вообще ставится и запускается (иконка, безletterbox-режима).
2. Логин на old.yummyani.me сохраняется после перезапуска.
3. При запуске плеера появляется плашка «Поток найден».
4. Нативный плеер играет; если 403 — проверить Referer/cookies, попробовать VLC.
5. Если сайт пустой/белый — переключить «Полная версия сайта» и перезагрузить.

## Заметки

- iOS 12 не поддерживает `?.`, `??`, `\p{...}` в JS — синтаксис не полифилится.
  Если сайт на них падает — только альтернативная (старая/мобильная) версия сайта.
- MSE на iPhone в iOS 12 нет вообще; спасает только нативный HLS/mp4.
- Запуск/тест только на живом устройстве; итерации по фидбеку.
