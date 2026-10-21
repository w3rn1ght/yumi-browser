#import "YumiSettings.h"
#import <UIKit/UIKit.h>

static NSString *const kYumiUAMode = @"YumiUAMode";
static NSString *const kYumiCustomUA = @"YumiCustomUA";
static NSString *const kYumiAdblock = @"YumiAdblock";
static NSString *const kYumiAutoPlayer = @"YumiAutoPlayer";
static NSString *const kYumiMediaHook = @"YumiMediaHook";
static NSString *const kYumiDesktopHosts = @"YumiDesktopHosts";

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

#pragma mark - UA

- (NSString *)mobileUA {
    NSString *ver = [[UIDevice currentDevice] systemVersion] ?: @"12.0";
    NSString *under = [ver stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    return [NSString stringWithFormat:
            @"Mozilla/5.0 (iPhone; CPU iPhone OS %@ like Mac OS X) "
            @"AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Mobile/15E148 Safari/604.1", under];
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

- (NSString *)userAgentForHost:(NSString *)host {
    if (self.uaMode == YumiUAModeCustom && self.customUA.length) return self.customUA;
    if ([self isDesktopForHost:host]) return [self desktopUA];
    return [self mobileUA];
}

- (void)reset {
    NSUserDefaults *d = [[self defaults] dictionaryRepresentation];
    for (NSString *key in d.allKeys) {
        if ([key hasPrefix:@"Yumi"]) [[self defaults] removeObjectForKey:key];
    }
    self.uaMode = YumiUAModeMobile;
    self.adblockEnabled = YES;
    self.autoNativePlayer = NO;
    self.mediaHookEnabled = YES;
    [[self defaults] synchronize];
}

@end

