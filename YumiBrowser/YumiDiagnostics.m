#import "YumiDiagnostics.h"
#import <UIKit/UIKit.h>

NSString *const YumiDiagnosticsDidChangeNotification = @"YumiDiagnosticsDidChange";

static const NSUInteger kYumiDiagnosticsLimit = 200;

@interface YumiDiagnostics ()
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *mutableEntries;
@end

@implementation YumiDiagnostics

+ (instancetype)shared {
    static YumiDiagnostics *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[YumiDiagnostics alloc] init]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _mutableEntries = [NSMutableArray array];
    }
    return self;
}

- (NSArray<NSDictionary *> *)entries {
    return [self.mutableEntries copy] ?: @[];
}

- (void)addKind:(NSString *)kind
           page:(NSString *)page
        message:(NSString *)message
         source:(NSString *)source {
    if (!message.length && !source.length) return;

    NSDictionary *entry = @{
        @"time": [NSDate date],
        @"kind": kind ?: @"info",
        @"page": page ?: @"",
        @"message": message ?: @"",
        @"source": source ?: @""
    };

    [self.mutableEntries insertObject:entry atIndex:0];
    while (self.mutableEntries.count > kYumiDiagnosticsLimit) {
        [self.mutableEntries removeLastObject];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:YumiDiagnosticsDidChangeNotification
                                                            object:self];
    });
}

- (NSString *)plainText {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"HH:mm:ss";

    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"Yumi %@ · iOS %@\n\n",
     [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"?",
     [[UIDevice currentDevice] systemVersion]];

    for (NSDictionary *entry in self.entries) {
        NSString *time = [formatter stringFromDate:entry[@"time"]];
        [text appendFormat:@"[%@] %@ — %@\n%@\n\n",
         time, entry[@"kind"], entry[@"message"], entry[@"page"]];
        if ([entry[@"source"] description].length) {
            [text appendFormat:@"%@\n\n", entry[@"source"]];
        }
    }
    if (!self.entries.count) [text appendString:@"Записей нет."];
    return text;
}

- (void)clear {
    [self.mutableEntries removeAllObjects];
    [[NSNotificationCenter defaultCenter] postNotificationName:YumiDiagnosticsDidChangeNotification
                                                        object:self];
}

@end
