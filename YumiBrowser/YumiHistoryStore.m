#import "YumiHistoryStore.h"

static NSString *const kYumiHistoryKey = @"YumiHistory";
static const NSUInteger kYumiHistoryLimit = 400;

@implementation YumiHistoryEntry

- (NSString *)displayTitle {
    if (self.title.length) return self.title;
    NSURL *url = [NSURL URLWithString:self.urlString ?: @""];
    return url.host.length ? url.host : (self.urlString ?: @"—");
}

@end

@implementation YumiHistoryStore

+ (NSArray<NSDictionary *> *)rawEntries {
    NSArray *stored = [[NSUserDefaults standardUserDefaults] arrayForKey:kYumiHistoryKey];
    return [stored isKindOfClass:[NSArray class]] ? stored : @[];
}

+ (void)writeRawEntries:(NSArray<NSDictionary *> *)entries {
    [[NSUserDefaults standardUserDefaults] setObject:entries forKey:kYumiHistoryKey];
}

+ (NSArray<YumiHistoryEntry *> *)entries {
    NSMutableArray<YumiHistoryEntry *> *result = [NSMutableArray array];
    for (NSDictionary *dict in [self rawEntries]) {
        if (![dict isKindOfClass:[NSDictionary class]]) continue;
        NSString *urlString = [dict[@"url"] description];
        if (!urlString.length) continue;

        YumiHistoryEntry *entry = [[YumiHistoryEntry alloc] init];
        entry.urlString = urlString;
        entry.title = [dict[@"title"] description] ?: @"";
        entry.date = [NSDate dateWithTimeIntervalSince1970:[dict[@"date"] doubleValue]];
        [result addObject:entry];
    }
    return result;
}

+ (void)recordURL:(NSURL *)url title:(NSString *)title {
    if (![url isKindOfClass:[NSURL class]]) return;
    NSString *string = url.absoluteString;
    if (!string.length) return;
    if ([string hasPrefix:@"about:"] || [string hasPrefix:@"file:"]) return;
    if (![url.scheme.lowercaseString isEqualToString:@"http"] &&
        ![url.scheme.lowercaseString isEqualToString:@"https"]) return;

    NSMutableArray<NSDictionary *> *entries = [[self rawEntries] mutableCopy];

    // Подряд идущие повторы одного адреса не множим.
    NSDictionary *last = entries.firstObject;
    if ([[last[@"url"] description] isEqualToString:string]) {
        [entries removeObjectAtIndex:0];
    }

    [entries insertObject:@{
        @"url": string,
        @"title": title ?: @"",
        @"date": @([[NSDate date] timeIntervalSince1970])
    } atIndex:0];

    while (entries.count > kYumiHistoryLimit) [entries removeLastObject];
    [self writeRawEntries:entries];
}

+ (NSArray<YumiHistoryEntry *> *)entriesMatching:(NSString *)query {
    NSString *needle = [(query ?: @"") lowercaseString];
    if (!needle.length) return [self entries];

    NSMutableArray<YumiHistoryEntry *> *result = [NSMutableArray array];
    for (YumiHistoryEntry *entry in [self entries]) {
        NSString *haystack = [[NSString stringWithFormat:@"%@ %@", entry.title ?: @"", entry.urlString ?: @""]
                              lowercaseString];
        if ([haystack containsString:needle]) [result addObject:entry];
    }
    return result;
}

+ (void)removeEntry:(YumiHistoryEntry *)entry {
    if (!entry.urlString.length) return;
    NSString *urlString = entry.urlString;
    NSMutableArray<NSDictionary *> *entries = [[self rawEntries] mutableCopy];
    NSIndexSet *toRemove = [entries indexesOfObjectsPassingTest:^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
        return [[dict[@"url"] description] isEqualToString:urlString];
    }];
    [entries removeObjectsAtIndexes:toRemove];
    [self writeRawEntries:entries];
}

+ (void)clear {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kYumiHistoryKey];
}

@end
