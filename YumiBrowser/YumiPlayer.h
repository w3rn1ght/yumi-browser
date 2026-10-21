#import <UIKit/UIKit.h>

@interface YumiPlayerViewController : UIViewController

- (instancetype)initWithURL:(NSURL *)url
                    headers:(NSDictionary<NSString *, NSString *> *)headers
                      title:(NSString *)title;

@end
