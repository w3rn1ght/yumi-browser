#import "YumiResumeStore.h"

static NSString *const kYumiResumePrefix = @"YumiResume_";

@implementation YumiResumeStore

+ (NSString *)keyForPageID:(NSString *)pageID {
    if (!pageID.length) return nil;
    return [kYumiResumePrefix stringByAppendingString:pageID];
}

+ (NSDictionary *)resumeForPageID:(NSString *)pageID {
    NSString *key = [self keyForPageID:pageID];
    if (!key) return nil;
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:key];
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    if (!dict[@"episode"] || !dict[@"animeID"]) return nil;
    return dict;
}

+ (void)saveForPageID:(NSString *)pageID
              animeID:(NSString *)animeID
              episode:(NSString *)episode
         episodeParam:(NSString *)episodeParam
              dubbing:(NSString *)dubbing
                 time:(NSTimeInterval)time
             duration:(NSTimeInterval)duration
                title:(NSString *)title {
    NSString *key = [self keyForPageID:pageID];
    if (!key || !animeID.length || !episode.length) return;

    // Совсем начало или почти конец — не предлагаем продолжать.
    if (time < 15.0) return;
    if (duration > 30.0 && time > duration - 20.0) {
        [self clearForPageID:pageID];
        return;
    }

    NSDictionary *dict = @{
        @"animeID": animeID,
        @"episode": episode,
        @"episodeParam": episodeParam ?: @"",
        @"dubbing": dubbing ?: @"",
        @"time": @(time),
        @"duration": @(duration),
        @"title": title ?: @"",
        @"updated": @([[NSDate date] timeIntervalSince1970])
    };
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:key];
}

+ (void)clearForPageID:(NSString *)pageID {
    NSString *key = [self keyForPageID:pageID];
    if (key) [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
}

+ (NSString *)timeStringForSeconds:(NSTimeInterval)seconds {
    NSInteger total = (NSInteger)MAX(0, seconds);
    NSInteger h = total / 3600;
    NSInteger m = (total % 3600) / 60;
    NSInteger s = total % 60;
    if (h > 0) return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)h, (long)m, (long)s];
    return [NSString stringWithFormat:@"%ld:%02ld", (long)m, (long)s];
}

@end
