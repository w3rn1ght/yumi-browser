#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "YumiTab.h"

@interface BrowserViewController : UIViewController <YumiTabDelegate, UITextFieldDelegate>

- (void)openURLString:(NSString *)string;
- (void)handleBridgeMessage:(NSDictionary *)message fromWebView:(WKWebView *)webView;

/** Применяет свежескомпилированные правила блокировки к открытым вкладкам. */
- (void)refreshContentBlocking;

@end
