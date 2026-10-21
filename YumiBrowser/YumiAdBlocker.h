#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface YumiAdBlocker : NSObject

+ (instancetype)shared;

/** Готовит скомпилированный список правил. Вызывать до создания вкладок. */
- (void)prepareWithCompletion:(void (^)(void))completion;

@property (nonatomic, strong, readonly) WKContentRuleList *ruleList;

+ (BOOL)isAdHost:(NSString *)host;
+ (NSArray<NSString *> *)adHosts;

@end
