#import <UIKit/UIKit.h>

@class SettingsViewController;

@protocol SettingsViewControllerDelegate <NSObject>
- (void)settingsDidChange:(SettingsViewController *)controller;
- (void)settingsDidRequestClearData:(SettingsViewController *)controller;
- (void)settingsDidRequestReset:(SettingsViewController *)controller;
@end

@interface SettingsViewController : UITableViewController

@property (nonatomic, weak) id<SettingsViewControllerDelegate> delegate;

@end
