#import <Foundation/Foundation.h>

/** Одна запись истории. */
@interface YumiHistoryEntry : NSObject

@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSDate *date;

- (NSString *)displayTitle;

@end

/**
 * История посещений в NSUserDefaults. В инкогнито не пишется — решение
 * принимает вызывающая сторона.
 */
@interface YumiHistoryStore : NSObject

+ (void)recordURL:(NSURL *)url title:(NSString *)title;
+ (NSArray<YumiHistoryEntry *> *)entries;
+ (NSArray<YumiHistoryEntry *> *)entriesMatching:(NSString *)query;
+ (void)removeEntry:(YumiHistoryEntry *)entry;
+ (void)clear;

@end
