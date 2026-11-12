#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, YumiUAMode) {
    YumiUAModeMobile = 0,
    YumiUAModeDesktop = 1,
    YumiUAModeCustom = 2
};

typedef NS_ENUM(NSInteger, YumiSearchEngine) {
    YumiSearchEngineYandex = 0,
    YumiSearchEngineBing = 1,
    YumiSearchEngineDuckDuckGo = 2
};

@interface YumiSettings : NSObject

+ (instancetype)shared;

@property (nonatomic, assign) YumiUAMode uaMode;
@property (nonatomic, copy) NSString *customUA;
@property (nonatomic, assign) BOOL adblockEnabled;
@property (nonatomic, assign) BOOL autoNativePlayer;
@property (nonatomic, assign) BOOL mediaHookEnabled;
@property (nonatomic, assign) BOOL webpCoversEnabled;
@property (nonatomic, assign) BOOL alwaysShowQuality;
@property (nonatomic, assign) YumiSearchEngine searchEngine;

- (NSString *)userAgentForHost:(NSString *)host;
- (BOOL)isDesktopForHost:(NSString *)host;
- (BOOL)isCompatModeForHost:(NSString *)host;
- (void)setCompatMode:(BOOL)enabled forHost:(NSString *)host;
- (void)setDesktop:(BOOL)desktop forHost:(NSString *)host;
- (NSString *)searchEngineName;
- (NSURL *)searchURLForQuery:(NSString *)query;
- (void)reset;

@end
