#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface YumiBridge : NSObject <WKScriptMessageHandler>

+ (instancetype)shared;

/** Вызывается на главном потоке. */
@property (nonatomic, copy) void (^handler)(WKWebView *webView, NSDictionary *message);

@end
