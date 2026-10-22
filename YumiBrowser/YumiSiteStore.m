#import "YumiSiteStore.h"

static NSString *const kYumiSitesKey = @"YumiSites";

@implementation YumiSiteStore

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)sites {
    NSArray *raw = [[NSUserDefaults standardUserDefaults] arrayForKey:kYumiSitesKey];
    if (![raw isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray *result = [NSMutableArray array];
    for (id item in raw) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSString *name = item[@"name"];
        NSString *url = item[@"url"];
        if (![name isKindOfClass:[NSString class]] || !name.length) continue;
        if (![url isKindOfClass:[NSString class]] || !url.length) continue;
        [result addObject:@{ @"name": name, @"url": url }];
    }
    return result;
}

+ (NSString *)sitesJSON {
    NSArray *sites = [self sites];
    NSData *data = [NSJSONSerialization dataWithJSONObject:sites options:0 error:nil];
    if (!data) return @"[]";
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!json.length) return @"[]";
    // Не даём имени сайта закрыть <script> в home.html.
    return [json stringByReplacingOccurrencesOfString:@"</" withString:@"<\\/"];
}

+ (NSString *)normalizedURLString:(NSString *)input {
    NSString *s = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!s.length) return nil;
    if ([s rangeOfString:@"://"].location == NSNotFound) {
        s = [@"https://" stringByAppendingString:s];
    }
    NSURL *url = [NSURL URLWithString:s];
    if (!url || !url.host.length) return nil;
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return nil;
    return url.absoluteString;
}

+ (BOOL)addSiteWithName:(NSString *)name urlString:(NSString *)urlString {
    NSString *url = [self normalizedURLString:urlString];
    if (!url.length) return NO;

    NSString *cleanName = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!cleanName.length) {
        NSString *host = [NSURL URLWithString:url].host ?: url;
        if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
        cleanName = host;
    }

    NSMutableArray *list = [[self sites] mutableCopy];
    for (NSDictionary *existing in list) {
        if ([existing[@"url"] isEqualToString:url]) return YES;
    }
    [list addObject:@{ @"name": cleanName, @"url": url }];
    [[NSUserDefaults standardUserDefaults] setObject:list forKey:kYumiSitesKey];
    return YES;
}

+ (void)removeSiteAtIndex:(NSInteger)index {
    NSMutableArray *list = [[self sites] mutableCopy];
    if (index < 0 || index >= (NSInteger)list.count) return;
    [list removeObjectAtIndex:(NSUInteger)index];
    [[NSUserDefaults standardUserDefaults] setObject:list forKey:kYumiSitesKey];
}

+ (void)reset {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kYumiSitesKey];
}

@end
