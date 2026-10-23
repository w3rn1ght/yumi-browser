#import "YumiAdBlocker.h"

static NSString *const kYumiRuleID = @"yumi-ads-v3";

@interface YumiAdBlocker ()
@property (nonatomic, strong, readwrite) WKContentRuleList *ruleList;
@property (nonatomic, strong, readwrite) WKContentRuleList *anilibriaRuleList;
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

    // Captcha providers must never be caught by a broad cosmetic/ad rule.
    // ignore-previous-rules is supported since iOS 11.2 and wins over the
    // host rules above when a captcha asset happens to share a blocked host.
    NSArray<NSString *> *captchaPatterns = @[
        @"^https?://([^/]+\\.)?google\\.com/recaptcha/",
        @"^https?://([^/]+\\.)?gstatic\\.com/recaptcha/",
        @"^https?://([^/]+\\.)?recaptcha\\.net/",
        @"^https?://([^/]+\\.)?challenges\\.cloudflare\\.com/",
        @"^https?://([^/]+\\.)?hcaptcha\\.com/",
        @"^https?://([^/]+\\.)?yandexcloud\\.net/",
        @"^https?://([^/]+\\.)?yandex\\.ru/(captcha|checkcaptcha)",
        @"^https?://([^/]+\\.)?yandex\\.com/(captcha|checkcaptcha)",
        @"^https?://([^/]+\\.)?ya\\.ru/(captcha|checkcaptcha)"
    ];
    for (NSString *pattern in captchaPatterns) {
        [rules addObject:@{
            @"trigger": @{ @"url-filter": pattern },
            @"action": @{ @"type": @"ignore-previous-rules" }
        }];
    }

    NSData *data = [NSJSONSerialization dataWithJSONObject:rules options:0 error:nil];
    if (!data) return @"[]";
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[]";
}

- (NSString *)anilibriaRulesJSON {
    NSMutableArray *rules = [NSMutableArray array];
    for (NSString *host in @[@"anilibria.fun", @"anilibria.top", @"anilibria.tv"]) {
        NSString *escaped = [self regexEscape:host];
        NSString *pattern = [NSString stringWithFormat:
            @"^https?://([^/]+\\.)?%@/_next/static/.*\\.js", escaped];
        [rules addObject:@{
            @"trigger": @{ @"url-filter": pattern, @"resource-type": @[@"script"] },
            @"action": @{ @"type": @"block" }
        }];
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:rules options:0 error:nil];
    if (!data) return @"[]";
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"[]";
}

- (void)ensureListWithIdentifier:(NSString *)identifier
                            json:(NSString *)json
                          assign:(void (^)(WKContentRuleList *list))assign
                      completion:(void (^)(void))completion {
    WKContentRuleListStore *store = [WKContentRuleListStore defaultStore];
    void (^done)(void) = ^{
        if (!completion) return;
        dispatch_async(dispatch_get_main_queue(), completion);
    };

    [store getAvailableContentRuleListIdentifiers:^(NSArray<NSString *> *identifiers) {
        if ([identifiers containsObject:identifier]) {
            [store lookUpContentRuleListForIdentifier:identifier
                                   completionHandler:^(WKContentRuleList *list, NSError *error) {
                if (list) {
                    if (assign) assign(list);
                } else {
                    NSLog(@"[Yumi] rule lookup failed %@: %@", identifier, error);
                }
                done();
            }];
        } else {
            [store compileContentRuleListForIdentifier:identifier
                                encodedContentRuleList:json
                                     completionHandler:^(WKContentRuleList *list, NSError *error) {
                if (error) {
                    NSLog(@"[Yumi] rule compile failed %@: %@", identifier, error);
                } else if (list) {
                    if (assign) assign(list);
                }
                done();
            }];
        }
    }];
}

- (void)prepareWithCompletion:(void (^)(void))completion {
    if (self.ruleList && self.anilibriaRuleList) {
        if (completion) dispatch_async(dispatch_get_main_queue(), completion);
        return;
    }
    if (self.preparing) return;
    self.preparing = YES;

    __weak typeof(self) weakSelf = self;
    [self ensureListWithIdentifier:kYumiRuleID
                              json:[self rulesJSON]
                            assign:^(WKContentRuleList *list) {
        weakSelf.ruleList = list;
    }
                        completion:^{
        [weakSelf ensureListWithIdentifier:@"yumi-anilibria-v1"
                                      json:[weakSelf anilibriaRulesJSON]
                                    assign:^(WKContentRuleList *list) {
            weakSelf.anilibriaRuleList = list;
        }
                                completion:^{
            weakSelf.preparing = NO;
            NSLog(@"[Yumi] content rule lists ready");
            if (completion) dispatch_async(dispatch_get_main_queue(), completion);
        }];
    }];
}

@end
