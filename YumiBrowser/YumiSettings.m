#import "YumiSettings.h"
#import <UIKit/UIKit.h>

static NSString *const kYumiUAMode = @"YumiUAMode";
static NSString *const kYumiCustomUA = @"YumiCustomUA";
static NSString *const kYumiAdblock = @"YumiAdblock";
static NSString *const kYumiAutoPlayer = @"YumiAutoPlayer";
static NSString *const kYumiMediaHook = @"YumiMediaHook";
static NSString *const kYumiWebPCovers = @"YumiWebPCovers";
static NSString *const kYumiAlwaysShowQuality = @"YumiAlwaysShowQuality";
static NSString *const kYumiDesktopHosts = @"YumiDesktopHosts";
static NSString *const kYumiCompatHosts = @"YumiCompatHosts";
static NSString *const kYumiSearchEngine = @"YumiSearchEngine";

@implementation YumiSettings

+ (instancetype)shared {
    static YumiSettings *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[YumiSettings alloc] init]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        if ([d objectForKey:kYumiUAMode] == nil) {
            [d setInteger:YumiUAModeMobile forKey:kYumiUAMode];
            [d setBool:YES forKey:kYumiAdblock];
            [d setBool:NO forKey:kYumiAutoPlayer];
            [d setBool:YES forKey:kYumiMediaHook];
            [d setBool:YES forKey:kYumiWebPCovers];
            [d setInteger:YumiSearchEngineYandex forKey:kYumiSearchEngine];
            [d synchronize];
        }
        // Added in 1.0.4: existing installs must keep working WebP covers.
        if ([d objectForKey:kYumiWebPCovers] == nil) {
            [d setBool:YES forKey:kYumiWebPCovers];
            [d synchronize];
        }
    }
    return self;
}

- (NSUserDefaults *)defaults { return [NSUserDefaults standardUserDefaults]; }

- (YumiUAMode)uaMode { return (YumiUAMode)[[self defaults] integerForKey:kYumiUAMode]; }
- (void)setUaMode:(YumiUAMode)mode { [[self defaults] setInteger:mode forKey:kYumiUAMode]; }

- (NSString *)customUA {
    NSString *s = [[self defaults] stringForKey:kYumiCustomUA];
    return s.length ? s : [self mobileUA];
}

- (void)setCustomUA:(NSString *)ua { [[self defaults] setObject:(ua ?: @"") forKey:kYumiCustomUA]; }

- (BOOL)adblockEnabled { return [[self defaults] boolForKey:kYumiAdblock]; }
- (void)setAdblockEnabled:(BOOL)v { [[self defaults] setBool:v forKey:kYumiAdblock]; }

- (BOOL)autoNativePlayer { return [[self defaults] boolForKey:kYumiAutoPlayer]; }
- (void)setAutoNativePlayer:(BOOL)v { [[self defaults] setBool:v forKey:kYumiAutoPlayer]; }

- (BOOL)mediaHookEnabled { return [[self defaults] boolForKey:kYumiMediaHook]; }
- (void)setMediaHookEnabled:(BOOL)v { [[self defaults] setBool:v forKey:kYumiMediaHook]; }

- (BOOL)webpCoversEnabled { return [[self defaults] boolForKey:kYumiWebPCovers]; }
- (void)setWebpCoversEnabled:(BOOL)v { [[self defaults] setBool:v forKey:kYumiWebPCovers]; }

- (BOOL)alwaysShowQuality { return [[self defaults] boolForKey:kYumiAlwaysShowQuality]; }
- (void)setAlwaysShowQuality:(BOOL)v { [[self defaults] setBool:v forKey:kYumiAlwaysShowQuality]; }

- (YumiSearchEngine)searchEngine {
    return (YumiSearchEngine)[[self defaults] integerForKey:kYumiSearchEngine];
}

- (void)setSearchEngine:(YumiSearchEngine)engine {
    [[self defaults] setInteger:engine forKey:kYumiSearchEngine];
}

- (NSString *)searchEngineName {
    switch (self.searchEngine) {
        case YumiSearchEngineBing: return @"Bing";
        case YumiSearchEngineDuckDuckGo: return @"DuckDuckGo";
        default: return @"Яндекс";
    }
}

- (NSURL *)searchURLForQuery:(NSString *)query {
    NSString *text = [(query ?: @"") stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!text.length) return nil;

    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:
        @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"];
    NSString *encoded = [text stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: text;

    NSString *format = @"https://yandex.ru/search/?text=%@";
    if (self.searchEngine == YumiSearchEngineBing) {
        format = @"https://www.bing.com/search?q=%@";
    } else if (self.searchEngine == YumiSearchEngineDuckDuckGo) {
        format = @"https://html.duckduckgo.com/html/?q=%@";
    }
    return [NSURL URLWithString:[NSString stringWithFormat:format, encoded]];
}

#pragma mark - UA

- (NSString *)mobileUA {
    NSString *ver = [[UIDevice currentDevice] systemVersion] ?: @"12.0";
    NSString *under = [ver stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    BOOL pad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
    NSString *device = pad ? @"iPad" : @"iPhone";
    NSString *cpu = pad ? @"CPU OS" : @"CPU iPhone OS";
    // UA должен соответствовать реальному движку: Cloudflare и другие антиботы
    // по UA выбирают версию скрипта. Если соврать про iOS 16, они пришлют
    // современный бандл, который WebKit 12 не может даже распарсить.
    return [NSString stringWithFormat:
            @"Mozilla/5.0 (%@; %@ %@ like Mac OS X) "
            @"AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Mobile/15E148 Safari/604.1",
            device, cpu, under];
}

- (NSString *)desktopUA {
    return @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
           @"(KHTML, like Gecko) Version/16.6 Safari/605.1.15";
}

- (NSMutableDictionary *)desktopHosts {
    NSDictionary *d = [[self defaults] dictionaryForKey:kYumiDesktopHosts];
    return d ? [d mutableCopy] : [NSMutableDictionary dictionary];
}

- (NSString *)normalizedHost:(NSString *)host {
    NSString *h = [(host ?: @"") lowercaseString];
    if ([h hasPrefix:@"www."]) h = [h substringFromIndex:4];
    return h;
}

- (BOOL)isDesktopForHost:(NSString *)host {
    NSString *h = [self normalizedHost:host];
    if (!h.length) return (self.uaMode == YumiUAModeDesktop);
    NSNumber *v = [self desktopHosts][h];
    if (v) return [v boolValue];
    return (self.uaMode == YumiUAModeDesktop);
}

- (void)setDesktop:(BOOL)desktop forHost:(NSString *)host {
    NSString *h = [self normalizedHost:host];
    if (!h.length) { self.uaMode = desktop ? YumiUAModeDesktop : YumiUAModeMobile; return; }
    NSMutableDictionary *d = [self desktopHosts];
    d[h] = @(desktop);
    [[self defaults] setObject:d forKey:kYumiDesktopHosts];
}

#pragma mark - Режим совместимости

- (NSMutableDictionary *)compatHosts {
    NSDictionary *d = [[self defaults] dictionaryForKey:kYumiCompatHosts];
    return d ? [d mutableCopy] : [NSMutableDictionary dictionary];
}

- (BOOL)isCompatModeForHost:(NSString *)host {
    NSString *h = [self normalizedHost:host];
    if (!h.length) return NO;
    NSNumber *value = [self compatHosts][h];
    return [value boolValue];
}

- (void)setCompatMode:(BOOL)enabled forHost:(NSString *)host {
    NSString *h = [self normalizedHost:host];
    if (!h.length) return;
    NSMutableDictionary *d = [self compatHosts];
    if (enabled) d[h] = @YES;
    else [d removeObjectForKey:h];
    [[self defaults] setObject:d forKey:kYumiCompatHosts];
}

/**
 * UA старого Safari: сайты отдают ES5-бандлы, которые парсит WebKit 12.
 * Для сайтов в полной версии берём настольный Safari 10 — у них самый полный
 * legacy-бандл; для мобильных — iPad Safari 10.
 */
- (NSString *)compatUAForHost:(NSString *)host {
    if ([self isDesktopForHost:host]) {
        return @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_6) AppleWebKit/603.3.8 "
                "(KHTML, like Gecko) Version/10.1.2 Safari/603.3.8";
    }
    BOOL pad = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
    if (pad) {
        return @"Mozilla/5.0 (iPad; CPU OS 10_3_3 like Mac OS X) AppleWebKit/603.3.8 "
                "(KHTML, like Gecko) Version/10.0 Mobile/14G60 Safari/602.1";
    }
    return @"Mozilla/5.0 (iPhone; CPU iPhone OS 10_3_3 like Mac OS X) AppleWebKit/603.3.8 "
            "(KHTML, like Gecko) Version/10.0 Mobile/14G60 Safari/602.1";
}

- (NSString *)userAgentForHost:(NSString *)host {
    NSString *h = [self normalizedHost:host];
    if ([self isCompatModeForHost:h]) return [self compatUAForHost:h];
    if (self.uaMode == YumiUAModeCustom && self.customUA.length) return self.customUA;
    if ([self isDesktopForHost:h]) return [self desktopUA];
    return [self mobileUA];
}

- (void)reset {
    NSDictionary *d = [[self defaults] dictionaryRepresentation];
    for (NSString *key in d.allKeys) {
        if ([key hasPrefix:@"Yumi"]) [[self defaults] removeObjectForKey:key];
    }
    self.uaMode = YumiUAModeMobile;
    self.adblockEnabled = YES;
    self.autoNativePlayer = NO;
    self.mediaHookEnabled = YES;
    self.webpCoversEnabled = YES;
    self.searchEngine = YumiSearchEngineYandex;
    [[self defaults] synchronize];
}

@end

