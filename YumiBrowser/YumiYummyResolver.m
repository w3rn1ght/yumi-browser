#import "YumiYummyResolver.h"

static NSString *const kYumiCVHUserAgent =
    @"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    @"(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36";

static NSError *YumiYummyError(NSString *message, NSInteger code) {
    return [NSError errorWithDomain:@"YumiYummy"
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Ошибка"}];
}

static void YumiHTTPGET(NSURL *url,
                        NSDictionary<NSString *, NSString *> *headers,
                        void (^completion)(id json, NSError *error)) {
    if (!url) {
        completion(nil, YumiYummyError(@"Некорректный URL", -1));
        return;
    }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:30.0];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    for (NSString *key in headers) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }

    NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
            return;
        }
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        if ([http isKindOfClass:[NSHTTPURLResponse class]] &&
            (http.statusCode < 200 || http.statusCode >= 300)) {
            NSError *e = YumiYummyError([NSString stringWithFormat:@"HTTP %ld", (long)http.statusCode],
                                        http.statusCode);
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, e); });
            return;
        }
        NSError *jsonError = nil;
        id json = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(json, jsonError); });
    }];
    [task resume];
}

static NSString *YumiNormalize(NSString *string) {
    NSString *lower = [(string ?: @"") lowercaseString];
    NSMutableString *out = [NSMutableString string];
    for (NSUInteger i = 0; i < lower.length; i++) {
        unichar c = [lower characterAtIndex:i];
        if (c == 0x0451) c = 0x0435; // ё -> е
        if (c == ' ' || c == '-' || c == '_' || c == '(' || c == ')' ||
            c == '.' || c == ',' || c == '"' || c == '\'' || c == '/') continue;
        [out appendFormat:@"%C", c];
    }
    return out;
}

@implementation YumiYummyResolver

+ (BOOL)isItemURL:(NSURL *)url {
    NSString *host = url.host.lowercaseString;
    if (![host hasSuffix:@"yummyani.me"]) return NO;
    NSString *path = url.path.lowercaseString;
    return [path containsString:@"/catalog/item/"];
}

+ (void)fetchEpisodesWithPageID:(NSString *)pageID
                     completion:(void (^)(NSArray<NSDictionary *> *, NSError *))completion {
    if (!completion) return;
    if (!pageID.length) {
        completion(@[], YumiYummyError(@"Не удалось определить id аниме", -2));
        return;
    }

    NSString *string = [NSString stringWithFormat:@"https://old.yummyani.me/api/anime/%@/videos", pageID];
    NSDictionary *headers = @{
        @"X-Application": @"wawegr8j13it4rdw",
        @"Vary": @"json",
        @"Lang": @"ru",
        @"Referer": @"https://old.yummyani.me/"
    };

    YumiHTTPGET([NSURL URLWithString:string], headers, ^(id json, NSError *error) {
        if (error) { completion(nil, error); return; }
        NSArray *items = [json isKindOfClass:[NSDictionary class]] ? ((NSDictionary *)json)[@"response"] : nil;
        if (![items isKindOfClass:[NSArray class]]) {
            completion(@[], YumiYummyError(@"Сайт вернул пустой список серий", -3));
            return;
        }

        NSMutableArray *result = [NSMutableArray array];
        for (NSDictionary *raw in items) {
            if (![raw isKindOfClass:[NSDictionary class]]) continue;

            NSString *iframe = raw[@"iframe_url"];
            if (![iframe isKindOfClass:[NSString class]] || !iframe.length) continue;
            if ([iframe hasPrefix:@"//"]) iframe = [@"https:" stringByAppendingString:iframe];

            NSURLComponents *components = [NSURLComponents componentsWithString:iframe];
            NSMutableDictionary *query = [NSMutableDictionary dictionary];
            for (NSURLQueryItem *item in components.queryItems) {
                if (item.name.length && item.value.length) query[item.name] = item.value;
            }

            NSString *animeID = query[@"anime_id"];
            NSString *episode = query[@"episode"] ?: [raw[@"number"] description];
            if (!animeID.length || !episode.length) continue;

            NSDictionary *data = [raw[@"data"] isKindOfClass:[NSDictionary class]] ? raw[@"data"] : @{};
            NSString *dubbing = [data[@"dubbing"] isKindOfClass:[NSString class]] ? data[@"dubbing"] : @"";
            NSString *player = [data[@"player"] isKindOfClass:[NSString class]] ? data[@"player"] : @"";
            NSString *number = [raw[@"number"] isKindOfClass:[NSString class]]
                ? raw[@"number"] : [raw[@"number"] description];

            [result addObject:@{
                @"animeID": animeID,
                @"episode": episode,
                @"number": number ?: episode,
                @"dubbing": dubbing,
                @"player": player,
                @"dubbingCode": query[@"dubbing_code"] ?: @"",
                @"duration": [raw[@"duration"] isKindOfClass:[NSNumber class]] ? raw[@"duration"] : @0
            }];
        }

        completion(result, nil);
    });
}

+ (NSDictionary *)chooseItem:(NSArray<NSDictionary *> *)items dubbing:(NSString *)dubbing {
    if (!items.count) return nil;
    NSString *want = YumiNormalize(dubbing);
    NSDictionary *fallback = items.firstObject;

    if (!want.length) return fallback;

    // точное/частичное совпадение по студии
    for (NSDictionary *item in items) {
        NSString *studio = YumiNormalize(item[@"voiceStudio"]);
        if (!studio.length) continue;
        if ([studio isEqualToString:want] ||
            [want containsString:studio] ||
            [studio containsString:want]) {
            return item;
        }
    }

    // субтитры
    if ([want containsString:@"субтитр"]) {
        for (NSDictionary *item in items) {
            NSString *type = YumiNormalize(item[@"voiceType"]);
            NSString *studio = YumiNormalize(item[@"voiceStudio"]);
            if ([type containsString:@"субтитр"] || [studio containsString:@"netflix"]) return item;
        }
    }

    // озвучка
    if ([want containsString:@"дубл"] || [want containsString:@"озвуч"]) {
        for (NSDictionary *item in items) {
            NSString *type = YumiNormalize(item[@"voiceType"]);
            if ([type containsString:@"дубл"] || [type containsString:@"озвуч"]) return item;
        }
    }

    return fallback;
}

+ (void)resolveStreamWithAnimeID:(NSString *)animeID
                         episode:(NSString *)episode
                         dubbing:(NSString *)dubbing
                      completion:(void (^)(NSURL *, NSDictionary<NSString *, NSString *> *, NSString *, NSError *))completion {
    if (!completion) return;
    if (!animeID.length || !episode.length) {
        completion(nil, nil, nil, YumiYummyError(@"Нет id аниме или номера серии", -4));
        return;
    }

    NSString *playlist = [NSString stringWithFormat:
        @"https://plapi.cdnvideohub.com/api/v1/player/sv/playlist?pub=745&aggr=mali&id=%@&ep=%@",
        animeID, episode];
    NSDictionary *apiHeaders = @{
        @"Origin": @"https://player.cdnvideohub.com",
        @"Referer": @"https://player.cdnvideohub.com/",
        @"User-Agent": kYumiCVHUserAgent
    };

    YumiHTTPGET([NSURL URLWithString:playlist], apiHeaders, ^(id json, NSError *error) {
        if (error) { completion(nil, nil, nil, error); return; }

        NSArray *items = [json isKindOfClass:[NSDictionary class]] ? ((NSDictionary *)json)[@"items"] : nil;
        if (![items isKindOfClass:[NSArray class]] || !items.count) {
            completion(nil, nil, nil, YumiYummyError(@"CVH не вернул список озвучек", -5));
            return;
        }

        NSDictionary *chosen = [self chooseItem:items dubbing:dubbing];
        NSString *vkID = [chosen[@"vkId"] description];
        if (!vkID.length) {
            completion(nil, nil, nil, YumiYummyError(@"CVH не вернул id видео", -6));
            return;
        }

        NSString *videoURL = [NSString stringWithFormat:
            @"https://plapi.cdnvideohub.com/api/v1/player/sv/video/%@", vkID];

        YumiHTTPGET([NSURL URLWithString:videoURL], apiHeaders, ^(id videoJSON, NSError *videoError) {
            if (videoError) { completion(nil, nil, nil, videoError); return; }

            NSDictionary *sources = [videoJSON isKindOfClass:[NSDictionary class]]
                ? ((NSDictionary *)videoJSON)[@"sources"] : nil;
            NSString *hls = [sources isKindOfClass:[NSDictionary class]] ? sources[@"hlsUrl"] : nil;
            if (![hls isKindOfClass:[NSString class]] || !hls.length) {
                completion(nil, nil, nil, YumiYummyError(@"Для этой озвучки нет HLS-потока (возможно, контент недоступен)", -7));
                return;
            }

            NSURL *url = [NSURL URLWithString:hls];
            if (!url) {
                completion(nil, nil, nil, YumiYummyError(@"Некорректный HLS-URL", -8));
                return;
            }

            NSDictionary *headers = @{
                @"Referer": @"https://player.cdnvideohub.com/",
                @"Origin": @"https://player.cdnvideohub.com",
                @"User-Agent": kYumiCVHUserAgent
            };

            NSString *voice = chosen[@"voiceStudio"] ?: dubbing ?: @"";
            NSString *title = [NSString stringWithFormat:@"Серия %@%@", episode,
                               voice.length ? [NSString stringWithFormat:@" · %@", voice] : @""];
            completion(url, headers, title, nil);
        });
    });
}

@end
