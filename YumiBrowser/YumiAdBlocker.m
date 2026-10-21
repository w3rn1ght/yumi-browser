#import "YumiAdBlocker.h"

static NSString *const kYumiRuleID = @"yumi-ads-v2";

@interface YumiAdBlocker ()
@property (nonatomic, strong, readwrite) WKContentRuleList *ruleList;
@property (nonatomic, assign) BOOL preparing;
@end

@implementation YumiAdBlocker

+ (instancetype)shared {
    static YumiAdBlocker *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[YumiAdBlocker alloc] init]; });
    return shared;
}

+ (NSArray<NSString *> *)adHosts {
    static NSArray *hosts = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        hosts = @[
            // рекламные сети / трекеры
            @"doubleclick.net", @"googlesyndication.com", @"googleadservices.com",
            @"adservice.google.com", @"2mdn.net", @"adsafeprotected.com",
            @"googletagmanager.com", @"googletagservices.com",
            @"adfox.ru", @"adfox.yandex.ru", @"an.yandex.ru", @"ads.yandex.ru",
            @"ad.mail.ru", @"adriver.ru", @"adnxs.com", @"adsrvr.org",
            @"amazon-adsystem.com", @"criteo.com", @"criteo.net", @"taboola.com",
            @"outbrain.com", @"pubmatic.com", @"rubiconproject.com", @"casalemedia.com",
            @"openx.net", @"scorecardresearch.com", @"quantserve.com",
            @"smartadserver.com", @"yieldmo.com", @"moatads.com",
            @"mc.yandex.ru", @"top-fwz1.mail.ru", @"ssp.rambler.ru",
            // попандеры / пуш-сети, которыми часто грешат аниме-сайты
            @"popads.net", @"popcash.net", @"propellerads.com", @"adsterra.com",
            @"hilltopads.net", @"exoclick.com", @"juicyads.com", @"trafficjunky.net",
            @"onclickads.net", @"adcash.com", @"push-notifications.net"
        ];
    });
    return hosts;
}

+ (BOOL)isAdHost:(NSString *)host {
    NSString *h = [(host ?: @"") lowercaseString];
    if (!h.length) return NO;
    for (NSString *d in [self adHosts]) {
        if ([h isEqualToString:d]) return YES;
        if ([h hasSuffix:[@"." stringByAppendingString:d]]) return YES;
    }
    return NO;
}

#pragma mark - Rule list

- (NSString *)regexEscape:(NSString *)s {
    return [s stringByReplacingOccurrencesOfString:@"." withString:@"\\."];
}

- (NSString *)rulesJSON {
    NSMutableArray *rules = [NSMutableArray array];
    for (NSString *host in [[self class] adHosts]) {
        NSString *pattern = [NSString stringWithFormat:@"^https?://([^/]+\\.)?%@(:[0-9]+)?/",
                             [self regexEscape:host]];
        [rules addObject:@{
            @"trigger": @{ @"url-filter": pattern },
            @"action": @{ @"type": @"block" }
        }];
    }
    // метрики и счётчики, которые часто висят на страницах с плеером
    [rules addObject:@{
        @"trigger": @{ @"url-filter": @"^https?://[^/]+/([^/]+/)*(vast|preroll|pre-roll)\\.xml" },
        @"action": @{ @"type": @"block" }
    }];
    NSData *data = [NSJSONSerialization dataWithJSONObject:rules options:0 error:nil];
    if (!data) return @"[]";
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[]";
}

- (void)prepareWithCompletion:(void (^)(void))completion {
    void (^finish)(void) = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion();
        });
    };

    if (self.ruleList) { finish(); return; }
    if (self.preparing) { finish(); return; }
    self.preparing = YES;

    WKContentRuleListStore *store = [WKContentRuleListStore defaultStore];
    __weak YumiAdBlocker *weakSelf = self;

    void (^compile)(void) = ^{
        NSString *json = [weakSelf rulesJSON];
        [store compileContentRuleListForIdentifier:kYumiRuleID
                            encodedContentRuleList:json
                                 completionHandler:^(WKContentRuleList *list, NSError *error) {
            YumiAdBlocker *strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.preparing = NO;
            if (error) {
                NSLog(@"[Yumi] adblock compile error: %@", error);
            } else {
                strongSelf.ruleList = list;
                NSLog(@"[Yumi] adblock rules ready");
            }
            if (completion) completion();
        }];
    };

    [store getAvailableContentRuleListIdentifiers:^(NSArray<NSString *> *identifiers) {
        if ([identifiers containsObject:kYumiRuleID]) {
            [store lookUpContentRuleListForIdentifier:kYumiRuleID
                                   completionHandler:^(WKContentRuleList *list, NSError *error) {
                YumiAdBlocker *strongSelf = weakSelf;
                if (!strongSelf) return;
                if (list) {
                    strongSelf.ruleList = list;
                    strongSelf.preparing = NO;
                    NSLog(@"[Yumi] adblock rules loaded from cache");
                    if (completion) completion();
                } else {
                    compile();
                }
            }];
        } else {
            compile();
        }
    }];
}

@end
