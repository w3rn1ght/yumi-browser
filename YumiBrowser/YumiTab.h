#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@class YumiTab;

@protocol YumiTabDelegate <NSObject>

- (void)tabDidStartLoading:(YumiTab *)tab;
- (void)tabDidFinishLoading:(YumiTab *)tab;
- (void)tab:(YumiTab *)tab didUpdateTitle:(NSString *)title;
- (void)tab:(YumiTab *)tab didUpdateURL:(NSURL *)url;
- (void)tab:(YumiTab *)tab didUpdateProgress:(double)progress;
- (void)tab:(YumiTab *)tab didFailWithError:(NSError *)error;
- (void)tab:(YumiTab *)tab didFindStreamInfo:(NSDictionary *)info;
- (void)tab:(YumiTab *)tab openExternalURL:(NSURL *)url;
- (WKWebView *)tab:(YumiTab *)tab
    createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
                 navigationAction:(WKNavigationAction *)navigationAction;
- (void)tab:(YumiTab *)tab showAlertWithTitle:(NSString *)title message:(NSString *)message;
- (void)tab:(YumiTab *)tab
    showConfirmWithTitle:(NSString *)title
                 message:(NSString *)message
              completion:(void (^)(BOOL ok))completion;

@end

@interface YumiTab : NSObject

@property (nonatomic, strong, readonly) WKWebView *webView;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, copy) NSString *pendingURLString;
@property (nonatomic, weak) id<YumiTabDelegate> delegate;
@property (nonatomic, readonly) BOOL isLoading;

+ (WKWebViewConfiguration *)defaultConfiguration;
+ (WKWebViewConfiguration *)configurationWithDataStore:(WKWebsiteDataStore *)store;
+ (BOOL)isDirectMediaURL:(NSURL *)url;

- (instancetype)initWithConfiguration:(WKWebViewConfiguration *)configuration
                             delegate:(id<YumiTabDelegate>)delegate;

- (void)loadURL:(NSURL *)url;
- (void)loadHome;
- (void)reload;
- (void)stopLoading;
- (void)goBack;
- (void)goForward;
- (BOOL)canGoBack;
- (BOOL)canGoForward;
- (NSString *)displayURLString;
- (void)applyUserAgent;
- (void)pauseMedia;
- (void)cookieHeaderForURL:(NSURL *)url completion:(void (^)(NSString *cookie))completion;

@end
