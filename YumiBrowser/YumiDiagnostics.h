#import <Foundation/Foundation.h>

extern NSString *const YumiDiagnosticsDidChangeNotification;

/** Журнал ошибок страниц и челленджей: чтобы смотреть проблемы без консоли. */
@interface YumiDiagnostics : NSObject

+ (instancetype)shared;

/** Новые сверху. Каждый элемент: time, page, kind, message, source. */
@property (nonatomic, readonly) NSArray<NSDictionary *> *entries;

- (void)addKind:(NSString *)kind
           page:(NSString *)page
        message:(NSString *)message
         source:(NSString *)source;

- (NSString *)plainText;
- (void)clear;

@end
