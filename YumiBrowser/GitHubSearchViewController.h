#import <UIKit/UIKit.h>

@class GitHubSearchViewController;

@protocol GitHubSearchViewControllerDelegate <NSObject>
- (void)gitHubSearchController:(GitHubSearchViewController *)controller openURL:(NSURL *)url;
@end

@interface GitHubSearchViewController : UITableViewController

@property (nonatomic, weak) id<GitHubSearchViewControllerDelegate> delegate;

@end
