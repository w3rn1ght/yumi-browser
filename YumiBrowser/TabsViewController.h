#import <UIKit/UIKit.h>

@class TabsViewController, YumiTab;

@protocol TabsViewControllerDelegate <NSObject>
- (void)tabsController:(TabsViewController *)controller didSelectTabAtIndex:(NSInteger)index;
- (void)tabsController:(TabsViewController *)controller didCloseTabAtIndex:(NSInteger)index;
- (void)tabsControllerDidRequestNewTab:(TabsViewController *)controller;
@end

@interface TabsViewController : UIViewController

- (instancetype)initWithTabs:(NSArray<YumiTab *> *)tabs activeIndex:(NSInteger)activeIndex;

@property (nonatomic, weak) id<TabsViewControllerDelegate> delegate;

@end
