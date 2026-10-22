#import <UIKit/UIKit.h>

@class YummyEpisodesViewController;

@protocol YummyEpisodesViewControllerDelegate <NSObject>
- (void)yummyEpisodesController:(YummyEpisodesViewController *)controller
                  playStreamURL:(NSURL *)url
                        headers:(NSDictionary<NSString *, NSString *> *)headers
                          title:(NSString *)title
                         resume:(NSDictionary *)resume;
@end

@interface YummyEpisodesViewController : UIViewController

- (instancetype)initWithPageID:(NSString *)pageID
                     pageTitle:(NSString *)pageTitle
                        resume:(NSDictionary *)resume;

@property (nonatomic, weak) id<YummyEpisodesViewControllerDelegate> delegate;

@end
