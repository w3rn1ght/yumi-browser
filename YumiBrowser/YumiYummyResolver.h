#import <Foundation/Foundation.h>

/**
 * Нативный резолвер плеера YummyAnime (CDNVideoHub / VK Video CDN).
 *
 * Зачем: сам плеер сайта — Vite-приложение, которое тянет video-player.umd.js
 * с синтаксисом ES2020 (`??`). WebKit iOS 12 такой синтаксис не парсит, поэтому
 * iframe-плеер навсегда остаётся со спиннером в ЛЮБОМ браузере на iOS 12.
 *
 * Здесь мы обходим плеер: берём список серий у сайта, потом напрямую дергаем
 * API CDNVideoHub и получаем готовый HLS-URL для AVPlayer.
 */
@interface YumiYummyResolver : NSObject

+ (BOOL)isItemURL:(NSURL *)url;

/** Список серий/озвучек. Возвращает массив нормализованных словарей. */
+ (void)fetchEpisodesWithPageID:(NSString *)pageID
                     completion:(void (^)(NSArray<NSDictionary *> *episodes, NSError *error))completion;

/** animeID — id из iframe_url (Shikimori/MAL id), episode — номер серии. */
+ (void)resolveStreamWithAnimeID:(NSString *)animeID
                         episode:(NSString *)episode
                         dubbing:(NSString *)dubbing
                      completion:(void (^)(NSURL *url,
                                           NSDictionary<NSString *, NSString *> *headers,
                                           NSString *title,
                                           NSError *error))completion;

@end
