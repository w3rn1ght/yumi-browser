#import "YumiBridge.h"

@implementation YumiBridge

+ (instancetype)shared {
    static YumiBridge *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[YumiBridge alloc] init]; });
    return shared;
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"yumi"]) return;
    id body = message.body;
    if (![body isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *dict = (NSDictionary *)body;
    WKWebView *webView = message.webView;
    void (^handler)(WKWebView *, NSDictionary *) = self.handler;
    if (!handler) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(webView, dict);
    });
}

@end
