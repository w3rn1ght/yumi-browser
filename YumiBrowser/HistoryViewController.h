#import <UIKit/UIKit.h>

@class HistoryViewController;

@protocol HistoryViewControllerDelegate <NSObject>
- (void)historyController:(HistoryViewController *)controller openURL:(NSURL *)url;
@end

@interface HistoryViewController : UITableViewController

@property (nonatomic, weak) id<HistoryViewControllerDelegate> delegate;

@end
