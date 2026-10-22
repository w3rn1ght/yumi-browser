#import <UIKit/UIKit.h>

@class YummyEpisodesViewController;

@protocol YummyEpisodesViewControllerDelegate <NSObject>
- (void)yummyEpisodesController:(YummyEpisodesViewController *)controller
                  playStreamURL:(NSURL *)url
                        headers:(NSDictionary<NSString *, NSString *> *)headers
                          title:(NSString *)title;
@end

@interface YummyEpisodesViewController : UITableViewController

- (instancetype)initWithPageID:(NSString *)pageID pageTitle:(NSString *)pageTitle;

@property (nonatomic, weak) id<YummyEpisodesViewControllerDelegate> delegate;

@end
