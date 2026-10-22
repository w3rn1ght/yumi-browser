#import "YumiAnilibriaResolver.h"

static NSError *YumiALError(NSString *message) {
    return [NSError errorWithDomain:@"YumiAnilibria"
                               code:-1
                           userInfo:@{NSLocalizedDescriptionKey: message ?: @"Ошибка AniLibria"}];
}

static NSString *YumiJSStringLiteral(NSString *string) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[string ?: @""] options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (json.length < 2) return @"\"\"";
    return [json substringWithRange:NSMakeRange(1, json.length - 2)];
}

static NSString *YumiJSQuotedString(NSString *string) {
    NSString *escaped = [string ?: @"" stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    return [NSString stringWithFormat:@"'%@'", escaped];
}

@implementation YumiAnilibriaResolver

+ (BOOL)isItemURL:(NSURL *)url {
    NSString *host = url.host.lowercaseString;
    if (![host hasSuffix:@"anilibria.fun"] &&
        ![host hasSuffix:@"anilibria.top"] &&
        ![host hasSuffix:@"anilibria.tv"]) return NO;
    NSString *path = url.path.lowercaseString;
    return [path hasPrefix:@"/anime/"] || [path hasPrefix:@"/release/"];
}

+ (NSString *)pageIDScript {
    return @"(function(){"
            "var h=document.documentElement.innerHTML;"
            "var m=/shikimoriId[^0-9]{0,24}(\\d{2,9})/.exec(h);"
            "return m?m[1]:'';"
            "})()";
}

+ (void)fetchEpisodesFromWebView:(WKWebView *)webView
                          pageID:(NSString *)pageID
                      completion:(void (^)(NSArray<NSDictionary *> *, NSError *))completion {
    if (!completion) return;
    if (!pageID.length) {
        completion(@[], YumiALError(@"Не удалось определить id тайтла"));
        return;
    }

    NSString *script = [NSString stringWithFormat:
        @"(function(){"
         "function get(u){try{var x=new XMLHttpRequest();x.open('GET',u,false);x.send(null);"
         "return {status:x.status,text:x.responseText||''};}catch(e){return {status:0,text:String(e)};}}"
         "var id=%@;"
         "var a=get('/api/sources?shikimoriId='+id);"
         "var k=get('/api/akuro/sources?shikimoriId='+id);"
         "return JSON.stringify({id:id,a:a,k:k});"
         "})()", YumiJSStringLiteral(pageID)];

    [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error || ![result isKindOfClass:[NSString class]]) {
            completion(@[], error ?: YumiALError(@"Не удалось получить список серий"));
            return;
        }
        NSData *data = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
        id root = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![root isKindOfClass:[NSDictionary class]]) {
            completion(@[], YumiALError(@"Некорректный ответ AniLibria"));
            return;
        }

        NSMutableArray *episodes = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];

        NSDictionary *a = root[@"a"];
        if ([a isKindOfClass:[NSDictionary class]]) {
            id aText = a[@"text"];
            id aData = [aText isKindOfClass:[NSString class]]
                ? [aText dataUsingEncoding:NSUTF8StringEncoding] : nil;
            id aJSON = aData ? [NSJSONSerialization JSONObjectWithData:aData options:0 error:nil] : nil;
            if ([aJSON isKindOfClass:[NSDictionary class]]) {
                NSArray *list = aJSON[@"episodes"];
                if ([list isKindOfClass:[NSArray class]]) {
                    for (NSDictionary *ep in list) {
                        if (![ep isKindOfClass:[NSDictionary class]]) continue;
                        NSString *number = [ep[@"number"] description];
                        if (!number.length) continue;
                        NSArray *sources = ep[@"sources"];
                        if (![sources isKindOfClass:[NSArray class]]) continue;
                        for (NSDictionary *src in sources) {
                            if (![src isKindOfClass:[NSDictionary class]]) continue;
                            NSString *dubbing = [src[@"dubbing"] description] ?: @"AniLibria";
                            NSString *key = [NSString stringWithFormat:@"%@|%@", number, dubbing.lowercaseString];
                            if ([seen containsObject:key]) continue;
                            [seen addObject:key];
                            NSNumber *duration = [src[@"durationSec"] isKindOfClass:[NSNumber class]]
                                ? src[@"durationSec"] : @0;
                            [episodes addObject:@{
                                @"episode": number,
                                @"animeID": pageID,
                                @"dubbing": dubbing,
                                @"player": [src[@"player"] description] ?: @"AniLibria",
                                @"duration": duration,
                                @"iframeUrl": [src[@"iframeUrl"] description] ?: @"",
                                @"provider": @"anilibria",
                                @"key": [src[@"key"] description] ?: @""
                            }];
                        }
                    }
                }
            }
        }

        NSDictionary *k = root[@"k"];
        if ([k isKindOfClass:[NSDictionary class]]) {
            id kText = k[@"text"];
            id kData = [kText isKindOfClass:[NSString class]]
                ? [kText dataUsingEncoding:NSUTF8StringEncoding] : nil;
            id kJSON = kData ? [NSJSONSerialization JSONObjectWithData:kData options:0 error:nil] : nil;
            if ([kJSON isKindOfClass:[NSDictionary class]]) {
                NSArray *variants = kJSON[@"variants"];
                NSArray *list = kJSON[@"episodes"];
                if ([variants isKindOfClass:[NSArray class]] && [list isKindOfClass:[NSArray class]]) {
                    for (NSDictionary *ep in list) {
                        if (![ep isKindOfClass:[NSDictionary class]]) continue;
                        NSString *number = [ep[@"n"] description];
                        if (!number.length) continue;
                        NSArray *indices = ep[@"v"];
                        if (![indices isKindOfClass:[NSArray class]]) continue;
                        for (NSNumber *index in indices) {
                            if (![index isKindOfClass:[NSNumber class]]) continue;
                            NSInteger i = index.integerValue;
                            if (i < 0 || i >= (NSInteger)variants.count) continue;
                            NSDictionary *variant = variants[(NSUInteger)i];
                            if (![variant isKindOfClass:[NSDictionary class]]) continue;
                            NSString *dubbing = [variant[@"dubbing"] description] ?: @"AKURO";
                            NSString *key = [NSString stringWithFormat:@"%@|%@", number, dubbing.lowercaseString];
                            if ([seen containsObject:key]) continue;
                            [seen addObject:key];
                            [episodes addObject:@{
                                @"episode": number,
                                @"animeID": pageID,
                                @"dubbing": dubbing,
                                @"player": @"AKURO",
                                @"duration": @0,
                                @"iframeUrl": @"",
                                @"provider": @"akuro",
                                @"key": [variant[@"key"] description] ?: @""
                            }];
                        }
                    }
                }
            }
        }

        if (!episodes.count) {
            completion(@[], YumiALError(@"AniLibria не вернула серии"));
            return;
        }
        completion(episodes, nil);
    }];
}

+ (void)resolveSource:(NSDictionary *)source
              episode:(NSString *)episode
               pageID:(NSString *)pageID
              webView:(WKWebView *)webView
           completion:(void (^)(NSURL *, NSDictionary<NSString *,NSString *> *, NSArray<NSDictionary<NSString *,NSString *> *> *, NSString *, NSError *))completion {
    if (!completion) return;
    if (!webView) {
        completion(nil, nil, nil, nil, YumiALError(@"Страница недоступна"));
        return;
    }

    NSString *provider = [source[@"provider"] description] ?: @"anilibria";
    BOOL akuro = [provider isEqualToString:@"akuro"];
    NSString *endpoint = akuro ? @"/api/akuro/stream" : @"/api/aniliberty/resolve";
    NSString *dubbing = [source[@"dubbing"] description] ?: @"";

    NSDictionary *payload = @{
        @"url": [source[@"iframeUrl"] description] ?: @"",
        @"episode": @(episode.integerValue),
        @"shikimoriId": @(pageID.integerValue),
        @"translation": dubbing
    };
    NSData *payloadData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    NSString *payloadJSON = payloadData
        ? [[NSString alloc] initWithData:payloadData encoding:NSUTF8StringEncoding] : @"{}";

    NSString *script = [NSString stringWithFormat:
        @"(function(){"
         "try{"
         "var payload=JSON.parse(%@);"
         "var x=new XMLHttpRequest();"
         "x.open('POST',%@,false);"
         "x.setRequestHeader('Content-Type','application/json');"
         "x.setRequestHeader('Accept','*/*');"
         "x.send(JSON.stringify(payload));"
         "return JSON.stringify({status:x.status,text:x.responseText||''});"
         "}catch(e){return JSON.stringify({status:0,text:String(e)});}"
         "})()",
         YumiJSQuotedString(payloadJSON),
         YumiJSQuotedString(endpoint)];

    [webView evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
        if (error || ![result isKindOfClass:[NSString class]]) {
            completion(nil, nil, nil, nil, error ?: YumiALError(@"Не удалось получить поток"));
            return;
        }
        NSData *data = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *response = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        if (![response isKindOfClass:[NSDictionary class]]) {
            completion(nil, nil, nil, nil, YumiALError(@"Некорректный ответ AniLibria"));
            return;
        }

        NSInteger status = [response[@"status"] integerValue];
        NSString *text = [response[@"text"] description] ?: @"";
        NSData *textData = [text dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = textData ? [NSJSONSerialization JSONObjectWithData:textData options:0 error:nil] : nil;

        if (status < 200 || status >= 300 || ![json isKindOfClass:[NSDictionary class]]) {
            NSString *message = [json isKindOfClass:[NSDictionary class]]
                ? ([json[@"error"] description] ?: @"Сервер отклонил запрос")
                : ([text length] ? text : @"Сервер отклонил запрос");
            completion(nil, nil, nil, nil, YumiALError(message));
            return;
        }

        NSDictionary *links = json[@"links"];
        if (![links isKindOfClass:[NSDictionary class]] || !links.count) {
            completion(nil, nil, nil, nil, YumiALError(@"Нет доступных качеств"));
            return;
        }

        NSMutableArray *options = [NSMutableArray array];
        NSArray *keys = [links.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            NSInteger ia = a.integerValue;
            NSInteger ib = b.integerValue;
            if (ia > ib) return NSOrderedAscending;
            if (ia < ib) return NSOrderedDescending;
            return [a compare:b];
        }];

        for (NSString *key in keys) {
            NSDictionary *entry = links[key];
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            NSString *src = [entry[@"Src"] description];
            if (!src.length) continue;

            if ([src hasPrefix:@"//"]) src = [@"https:" stringByAppendingString:src];
            else if ([src hasPrefix:@"/"]) src = [@"https://anilibria.fun" stringByAppendingString:src];

            NSURL *url = [NSURL URLWithString:src];
            if (!url) continue;

            NSString *title = [key rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound
                ? [key stringByAppendingString:@"p"] : key;
            [options addObject:@{ @"title": title, @"url": url.absoluteString }];
        }

        if (!options.count) {
            completion(nil, nil, nil, nil, YumiALError(@"Нет доступных потоков"));
            return;
        }

        NSURL *url = [NSURL URLWithString:options.firstObject[@"url"]];
        NSDictionary *headers = @{ @"Referer": @"https://anilibria.fun/" };
        NSString *title = dubbing.length
            ? [NSString stringWithFormat:@"%@ · серия %@", dubbing, episode]
            : [NSString stringWithFormat:@"Серия %@", episode];
        completion(url, headers, options, title, nil);
    }];
}

@end
