#import "YumiScripts.h"

@implementation YumiScripts

+ (NSString *)stringFromResource:(NSString *)name extension:(NSString *)ext {
    static NSMutableDictionary *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSMutableDictionary dictionary]; });

    NSString *key = [NSString stringWithFormat:@"%@.%@", name, ext];
    NSString *cached = cache[key];
    if (cached) return cached;

    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:ext];
    NSString *text = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] : nil;
    if (!text) {
        NSLog(@"[Yumi] resource missing: %@", key);
        text = @"";
    }
    cache[key] = text;
    return text;
}

+ (NSString *)polyfills { return [self stringFromResource:@"polyfills" extension:@"js"]; }
+ (NSString *)hook { return [self stringFromResource:@"hook" extension:@"js"]; }
+ (NSString *)homeHTML { return [self stringFromResource:@"home" extension:@"html"]; }

@end
