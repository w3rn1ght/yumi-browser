#import "YumiTab.h"
#import "YumiSettings.h"
#import "YumiScripts.h"
#import "YumiBridge.h"
#import "YumiAdBlocker.h"
#import "YumiSiteStore.h"
#import <UIKit/UIKit.h>

static void YumiDisableITP(WKWebsiteDataStore *store) {
    SEL sel = NSSelectorFromString(@"_setResourceLoadStatisticsEnabled:");
    if (![store respondsToSelector:sel]) return;
    @try {
        NSMethodSignature *sig = [store methodSignatureForSelector:sel];
        if (!sig || sig.numberOfArguments < 3) return;
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        inv.target = store;
        inv.selector = sel;
        BOOL no = NO;
        [inv setArgument:&no atIndex:2];
        [inv invoke];
        NSLog(@"[Yumi] ITP disabled (private API)");
    } @catch (NSException *e) {
        NSLog(@"[Yumi] ITP disable failed: %@", e);
    }
}

@interface YumiTab () <WKNavigationDelegate, WKUIDelegate>
@property (nonatomic, strong, readwrite) WKWebView *webView;
- (void)reportStreamURL:(NSURL *)url kind:(NSString *)kind;
@end

@implementation YumiTab

+ (WKWebViewConfiguration *)defaultConfiguration {
    YumiSettings *settings = [YumiSettings shared];
    WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];

    WKUserContentController *ucc = [[WKUserContentController alloc] init];
    [ucc addScriptMessageHandler:[YumiBridge shared] name:@"yumi"];

    if (settings.mediaHookEnabled) {
        NSString *poly = [YumiScripts polyfills];
        if (poly.length) {
            [ucc addUserScript:[[WKUserScript alloc] initWithSource:poly
                                                       injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                    forMainFrameOnly:NO]];
        }
        NSString *hook = [YumiScripts hook];
        if (hook.length) {
            [ucc addUserScript:[[WKUserScript alloc] initWithSource:hook
                                                       injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                    forMainFrameOnly:NO]];
        }
    }

    if (settings.adblockEnabled) {
        WKContentRuleList *rules = [YumiAdBlocker shared].ruleList;
        if (rules) [ucc addContentRuleList:rules];
    }

    cfg.userContentController = ucc;
    cfg.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    cfg.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    cfg.preferences.minimumFontSize = 0;
    cfg.allowsInlineMediaPlayback = YES;
    cfg.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    cfg.allowsAirPlayForMediaPlayback = YES;
    cfg.suppressesIncrementalRendering = NO;
    cfg.dataDetectorTypes = WKDataDetectorTypeNone;
    YumiDisableITP(cfg.websiteDataStore);
    return cfg;
}

+ (BOOL)isDirectMediaURL:(NSURL *)url {
    if (![url isKindOfClass:[NSURL class]]) return NO;
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return NO;
    NSString *ext = url.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"m3u8"] || [ext isEqualToString:@"mp4"] ||
        [ext isEqualToString:@"m4v"] || [ext isEqualToString:@"mov"] ||
        [ext isEqualToString:@"mpd"]) {
        return YES;
    }
    NSString *lower = url.absoluteString.lowercaseString;
    if ([lower containsString:@".m3u8?"] || [lower containsString:@".mp4?"]) return YES;
    return NO;
}

- (instancetype)initWithConfiguration:(WKWebViewConfiguration *)configuration
                             delegate:(id<YumiTabDelegate>)delegate {
    if ((self = [super init])) {
        _delegate = delegate;
        _title = @"Новая вкладка";
        WKWebViewConfiguration *cfg = configuration ?: [[self class] defaultConfiguration];
        _webView = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) configuration:cfg];
        _webView.navigationDelegate = self;
        _webView.UIDelegate = self;
        _webView.allowsBackForwardNavigationGestures = YES;
        _webView.allowsLinkPreview = YES;
        _webView.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
        _webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        _webView.opaque = YES;
        _webView.backgroundColor = [UIColor whiteColor];
        [_webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:NULL];
        [_webView addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:NULL];
        [_webView addObserver:self forKeyPath:@"URL" options:NSKeyValueObservingOptionNew context:NULL];
        [self applyUserAgent];
    }
    return self;
}

- (void)dealloc {
    @try {
        [_webView removeObserver:self forKeyPath:@"estimatedProgress"];
        [_webView removeObserver:self forKeyPath:@"title"];
        [_webView removeObserver:self forKeyPath:@"URL"];
    } @catch (NSException *e) {}
    _webView.navigationDelegate = nil;
    _webView.UIDelegate = nil;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (object != self.webView) return;
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        [self.delegate tab:self didUpdateProgress:self.webView.estimatedProgress];
    } else if ([keyPath isEqualToString:@"title"]) {
        NSString *t = self.webView.title;
        if (!t.length) t = self.webView.URL.host ?: @"Новая вкладка";
        self.title = t;
        [self.delegate tab:self didUpdateTitle:t];
    } else if ([keyPath isEqualToString:@"URL"]) {
        NSURL *u = self.webView.URL;
        if (u && ![[u absoluteString] isEqualToString:@"about:blank"]) {
            self.url = u;
            [self.delegate tab:self didUpdateURL:u];
        }
    }
}

#pragma mark - Загрузка

- (void)applyUserAgent {
    NSString *host = self.webView.URL.host ?: self.url.host;
    self.webView.customUserAgent = [[YumiSettings shared] userAgentForHost:host];
}

- (void)loadURL:(NSURL *)url {
    if (!url) return;
    self.pendingURLString = nil;
    [self applyUserAgent];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                      cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                  timeoutInterval:60.0];
    [req setValue:@"ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7" forHTTPHeaderField:@"Accept-Language"];
    [self.webView loadRequest:req];
}

- (void)loadHome {
    self.pendingURLString = nil;
    self.url = nil;
    self.title = @"Yumi";
    [self applyUserAgent];
    NSString *html = [YumiScripts homeHTML];
    NSString *json = [YumiSiteStore sitesJSON];
    html = [html stringByReplacingOccurrencesOfString:@"__YUMI_SITES_JSON__" withString:json];
    [self.webView loadHTMLString:html baseURL:nil];
}

- (void)reload {
    if (!self.webView.URL || [[self.webView.URL absoluteString] isEqualToString:@"about:blank"]) {
        if (self.pendingURLString.length) {
            [self loadURL:[NSURL URLWithString:self.pendingURLString]];
        } else {
            [self loadHome];
        }
        return;
    }
    [self applyUserAgent];
    [self.webView reload];
}

- (void)stopLoading { [self.webView stopLoading]; }
- (void)goBack { if ([self.webView canGoBack]) [self.webView goBack]; }
- (void)goForward { if ([self.webView canGoForward]) [self.webView goForward]; }
- (BOOL)canGoBack { return [self.webView canGoBack]; }
- (BOOL)canGoForward { return [self.webView canGoForward]; }
- (BOOL)isLoading { return self.webView.isLoading; }

- (NSString *)displayURLString {
    NSString *s = self.webView.URL.absoluteString;
    if (!s.length || [s isEqualToString:@"about:blank"]) return @"";
    return s;
}

- (void)pauseMedia {
    [self.webView evaluateJavaScript:@"window.__yumiPauseAll && window.__yumiPauseAll();"
                  completionHandler:nil];
}

#pragma mark - Cookies

- (void)cookieHeaderForURL:(NSURL *)url completion:(void (^)(NSString *))completion {
    if (!completion) return;
    NSString *host = url.host.lowercaseString;
    if (!host.length) { completion(nil); return; }
    WKHTTPCookieStore *store = self.webView.configuration.websiteDataStore.httpCookieStore;
    [store getAllCookies:^(NSArray<NSHTTPCookie *> *cookies) {
        NSMutableArray *parts = [NSMutableArray array];
        NSDate *now = [NSDate date];
        BOOL isHTTPS = [url.scheme.lowercaseString isEqualToString:@"https"];
        for (NSHTTPCookie *c in cookies) {
            if (c.expiresDate && [c.expiresDate compare:now] == NSOrderedAscending) continue;
            if (c.isSecure && !isHTTPS) continue;
            NSString *domain = [c.domain lowercaseString];
            if (domain.length == 0) continue;
            if ([domain hasPrefix:@"."]) domain = [domain substringFromIndex:1];
            if (![host isEqualToString:domain] &&
                ![host hasSuffix:[@"." stringByAppendingString:domain]]) continue;
            [parts addObject:[NSString stringWithFormat:@"%@=%@", c.name, c.value]];
        }
        completion(parts.count ? [parts componentsJoinedByString:@"; "] : nil);
    }];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
                    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = navigationAction.request.URL;
    if (!url) { decisionHandler(WKNavigationActionPolicyAllow); return; }

    NSString *scheme = url.scheme.lowercaseString;
    if (!scheme.length) { decisionHandler(WKNavigationActionPolicyAllow); return; }

    BOOL allowedScheme = [@[@"http", @"https", @"about", @"file", @"data", @"blob", @"javascript"]
                          containsObject:scheme];
    if (!allowedScheme) {
        decisionHandler(WKNavigationActionPolicyCancel);
        [self.delegate tab:self openExternalURL:url];
        return;
    }

    if ([YumiSettings shared].adblockEnabled && [YumiAdBlocker isAdHost:url.host]) {
        NSLog(@"[Yumi] blocked nav: %@", url.host);
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"] &&
        ![scheme isEqualToString:@"about"] && ![scheme isEqualToString:@"file"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }

    if (navigationAction.targetFrame.isMainFrame && [YumiTab isDirectMediaURL:url]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        [self reportStreamURL:url kind:nil];
        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView
    decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse
                     decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    if (!navigationResponse.isForMainFrame) { decisionHandler(WKNavigationResponsePolicyAllow); return; }
    NSString *mime = [(navigationResponse.response.MIMEType ?: @"") lowercaseString];
    BOOL isHLS = [mime containsString:@"mpegurl"];
    BOOL isDash = [mime containsString:@"dash+xml"];
    BOOL isMedia = isHLS || isDash || [mime hasPrefix:@"video/"];
    if (isMedia) {
        NSURL *u = navigationResponse.response.URL;
        if (u && ([YumiTab isDirectMediaURL:u] || isHLS || isDash)) {
            decisionHandler(WKNavigationResponsePolicyCancel);
            NSString *kind = isHLS ? @"hls" : (isDash ? @"dash" : nil);
            [self reportStreamURL:u kind:kind];
            return;
        }
    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    [self.delegate tabDidStartLoading:self];
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    [self applyUserAgent];
    if (webView.URL.absoluteString.length) {
        self.url = webView.URL;
        [self.delegate tab:self didUpdateURL:webView.URL];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    if (webView.URL.absoluteString.length) {
        self.url = webView.URL;
    }
    if (!self.title.length) self.title = webView.title ?: @"";
    [self.delegate tabDidFinishLoading:self];
    [self.delegate tab:self didUpdateURL:self.url];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) return;
    [self.delegate tabDidFinishLoading:self];
    [self.delegate tab:self didFailWithError:error];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) return;
    [self.delegate tabDidFinishLoading:self];
    [self.delegate tab:self didFailWithError:error];
}

- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    NSLog(@"[Yumi] web content process terminated, reloading");
    [webView reload];
}

#pragma mark - Стримы

- (void)reportStreamURL:(NSURL *)url kind:(NSString *)kind {
    if (!url || !url.absoluteString.length) return;
    NSString *k = kind;
    if (!k) {
        NSString *ext = url.pathExtension.lowercaseString;
        k = [ext isEqualToString:@"m3u8"] ? @"hls" : ([ext isEqualToString:@"mpd"] ? @"dash" : @"mp4");
    }
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"url"] = url.absoluteString;
    info[@"kind"] = k;
    info[@"page"] = self.webView.URL.absoluteString ?: (self.url.absoluteString ?: @"");
    info[@"title"] = self.title ?: (self.webView.title ?: @"");
    info[@"top"] = @1;
    info[@"ad"] = @([YumiAdBlocker isAdHost:url.host]);
    [self.delegate tab:self didFindStreamInfo:info];
}

#pragma mark - WKUIDelegate

- (WKWebView *)webView:(WKWebView *)webView
    createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
               forNavigationAction:(WKNavigationAction *)navigationAction
                    windowFeatures:(WKWindowFeatures *)windowFeatures {
    return [self.delegate tab:self
 createWebViewWithConfiguration:configuration
              navigationAction:navigationAction];
}

- (void)webView:(WKWebView *)webView
    runJavaScriptAlertPanelWithMessage:(NSString *)message
                      initiatedByFrame:(WKFrameInfo *)frame
                     completionHandler:(void (^)(void))completionHandler {
    [self.delegate tab:self showAlertWithTitle:self.title message:message];
    if (completionHandler) completionHandler();
}

- (void)webView:(WKWebView *)webView
    runJavaScriptConfirmPanelWithMessage:(NSString *)message
                        initiatedByFrame:(WKFrameInfo *)frame
                       completionHandler:(void (^)(BOOL))completionHandler {
    [self.delegate tab:self showConfirmWithTitle:self.title message:message completion:^(BOOL ok) {
        if (completionHandler) completionHandler(ok);
    }];
}

- (void)webView:(WKWebView *)webView
    runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt
                              defaultText:(NSString *)defaultText
                         initiatedByFrame:(WKFrameInfo *)frame
                        completionHandler:(void (^)(NSString *))completionHandler {
    if (completionHandler) completionHandler(nil);
}

- (void)webViewDidClose:(WKWebView *)webView {
    // окно, открытое через window.close(), просто остаётся; закрытие вкладки делает браузер
}

@end

