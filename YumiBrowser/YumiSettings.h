#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, YumiUAMode) {
    YumiUAModeMobile = 0,
    YumiUAModeDesktop = 1,
    YumiUAModeCustom = 2
};

@interface YumiSettings : NSObject

+ (instancetype)shared;

@property (nonatomic, assign) YumiUAMode uaMode;
@property (nonatomic, copy) NSString *customUA;
@property (nonatomic, assign) BOOL adblockEnabled;
@property (nonatomic, assign) BOOL autoNativePlayer;
@property (nonatomic, assign) BOOL mediaHookEnabled;

- (NSString *)userAgentForHost:(NSString *)host;
- (BOOL)isDesktopForHost:(NSString *)host;
- (void)setDesktop:(BOOL)desktop forHost:(NSString *)host;
- (void)reset;

@end
