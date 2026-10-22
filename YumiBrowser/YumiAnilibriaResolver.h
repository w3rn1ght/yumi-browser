#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface YumiAnilibriaResolver : NSObject

+ (BOOL)isItemURL:(NSURL *)url;

/** JS-выражение, возвращающее shikimoriId текущей страницы. */
+ (NSString *)pageIDScript;

+ (void)fetchEpisodesFromWebView:(WKWebView *)webView
                          pageID:(NSString *)pageID
                      completion:(void (^)(NSArray<NSDictionary *> *episodes, NSError *error))completion;

+ (void)resolveSource:(NSDictionary *)source
              episode:(NSString *)episode
               pageID:(NSString *)pageID
              webView:(WKWebView *)webView
           completion:(void (^)(NSURL *url,
                                NSDictionary<NSString *, NSString *> *headers,
                                NSArray<NSDictionary<NSString *, NSString *> *> *qualities,
                                NSString *title,
                                NSError *error))completion;

@end
