# Yumi Browser — прогресс

Цель: браузер под jailbreak iOS 12, чтобы работал old.yummyani.me и грузились плееры
(перехват m3u8/mp4 + нативное воспроизведение в AVPlayer с нужным Referer/Cookie).
Кинопоиск: DRM — не поддерживается by design (см. README).

## Этапы

- [x] Каркас репозитория, git, структура проекта
- [ ] JS: polyfills.js (WebKit 12), hook.js (перехват потоков), home.html
- [ ] ObjC: YumiSettings, YumiAdBlocker, YumiIcons
- [ ] ObjC: YumiTab, YumiBridge, YumiScripts
- [ ] ObjC: BrowserViewController (вкладки, адресная строка, баннер потока)
- [ ] ObjC: YumiPlayer (AVPlayer + headers), TabsViewController, SettingsViewController
- [ ] Info.plist, иконки, launch images
- [ ] GitHub Actions (macOS, Theos) → .deb + .ipa
- [ ] README с инструкцией установки и ограничениями

## Принятые решения

- Theos-проект, ObjC + ARC, `TARGET = iphone:clang:latest:12.0`, `ARCHS = arm64`
  (arm64-бинарник работает и на arm64e-устройствах, меньше проблем с подписью).
- Сборка только в CI: локально на Windows нет clang/Theos.
- Один WKWebView на вкладку, persistent cookies (логин сохраняется).
- Перехват потоков из JS (fetch/XHR/video.src) → сообщение в native → AVPlayer
  с заголовками Referer/Origin/User-Agent/Cookie (AVURLAssetHTTPHeaderFieldsKey).
- Реклама: WKContentRuleList (сетевой блок) + косметический JS.
- Настройки: UA (mobile/desktop/custom), desktop-режим по домену, авто-плеер,
  блок рекламы, домашняя страница.

## Заметки

- iOS 12 не поддерживает `?.`, `??`, `\p{...}` в JS — синтаксис не полифилится.
  Если сайт на них падает — только альтернативная (старая/мобильная) версия сайта.
- MSE на iPhone в iOS 12 нет вообще; спасает только нативный HLS/mp4.
- Запуск/тест только на живом устройстве; итерации по фидбеку.
