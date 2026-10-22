#import <Foundation/Foundation.h>

@interface YumiSiteStore : NSObject

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)sites;
+ (NSString *)sitesJSON;
+ (BOOL)addSiteWithName:(NSString *)name urlString:(NSString *)urlString;
+ (void)removeSiteAtIndex:(NSInteger)index;
+ (void)reset;

@end
