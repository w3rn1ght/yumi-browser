#import <UIKit/UIKit.h>
#import "BrowserViewController.h"
#import "YumiAdBlocker.h"
#import "YumiSettings.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) BrowserViewController *browser;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];

    self.browser = [[BrowserViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self.browser];
    nav.toolbarHidden = NO;
    nav.navigationBar.translucent = NO;
    nav.toolbar.translucent = NO;
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];

    __weak typeof(self) weakSelf = self;
    [[YumiAdBlocker shared] prepareWithCompletion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.browser refreshContentBlocking];
        });
    }];

    return YES;
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
    if (url.absoluteString.length) [self.browser openURLString:url.absoluteString];
    return YES;
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    NSLog(@"[Yumi] memory warning");
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
