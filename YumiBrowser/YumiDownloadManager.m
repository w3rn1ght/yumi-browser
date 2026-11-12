#import "YumiDownloadManager.h"
#import <UIKit/UIKit.h>

NSString *const YumiDownloadsDidChangeNotification = @"YumiDownloadsDidChange";
NSString *const YumiDownloadDidFinishNotification = @"YumiDownloadDidFinish";
NSString *const YumiDownloadDidFailNotification = @"YumiDownloadDidFail";

static const NSInteger kYumiMaxConcurrentDownloads = 2;

/** GitHub release-ассеты отдают файл только «настоящему» десктопному клиенту. */
static NSString *const kYumiGitHubDownloadUA =
    @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 "
    @"(KHTML, like Gecko) Version/16.6 Safari/605.1.15";

@interface YumiDownloadItem ()
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, copy) NSString *userAgent;
@property (nonatomic, copy) NSString *cookie;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) BOOL saved;
@end

@implementation YumiDownloadItem

- (instancetype)init {
    if ((self = [super init])) {
        _identifier = [[NSUUID UUID] UUIDString];
        _progress = 0.0;
    }
    return self;
}

- (NSString *)stateText {
    if (self.cancelled) return @"Отменено";
    if (self.errorMessage.length) return @"Ошибка";
    if (self.finished) return @"Готово";
    if (!self.started) return @"В очереди";
    if (self.progress > 0.001 && self.progress < 0.999) {
        return [NSString stringWithFormat:@"Скачивается %.0f%%", self.progress * 100.0];
    }
    return @"Скачивается";
}

@end

@interface YumiDownloadManager () <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSMutableArray<YumiDownloadItem *> *mutableItems;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTask;
@property (nonatomic, assign) NSInteger lastPercent;
@end

@implementation YumiDownloadManager

+ (instancetype)shared {
    static YumiDownloadManager *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[YumiDownloadManager alloc] init]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _mutableItems = [NSMutableArray array];
        _backgroundTask = UIBackgroundTaskInvalid;
    }
    return self;
}

- (NSArray<YumiDownloadItem *> *)items {
    return [self.mutableItems copy] ?: @[];
}

- (NSString *)downloadsDirectory {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                               NSUserDomainMask, YES) firstObject];
    NSString *directory = [documents stringByAppendingPathComponent:@"Downloads"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    return directory;
}

#pragma mark - Публичное API

- (void)enqueueURL:(NSURL *)url
          filename:(NSString *)filename
           pageURL:(NSURL *)pageURL
            cookie:(NSString *)cookie
         userAgent:(NSString *)userAgent {
    if (![url isKindOfClass:[NSURL class]]) return;

    YumiDownloadItem *item = [[YumiDownloadItem alloc] init];
    item.url = url;
    item.filename = [self sanitizedFilename:filename url:url];
    item.pageURLString = pageURL.absoluteString ?: @"";
    item.cookie = cookie ?: @"";
    item.userAgent = userAgent ?: @"";

    [self.mutableItems insertObject:item atIndex:0];
    [self postChange];
    if (self.onEvent) self.onEvent(item, @"start");

    [self startPendingItems];
}

- (void)cancelItem:(YumiDownloadItem *)item {
    if (!item) return;
    item.cancelled = YES;
    item.errorMessage = nil;
    [item.task cancel];
    [item.session invalidateAndCancel];
    item.session = nil;
    item.task = nil;
    [self postChange];
    if (self.onEvent) self.onEvent(item, @"cancel");
    [self startPendingItems];
}

- (void)removeItem:(YumiDownloadItem *)item {
    if (!item) return;
    if (!item.finished && !item.errorMessage.length && !item.cancelled) {
        [self cancelItem:item];
    }
    [self.mutableItems removeObjectIdenticalTo:item];
    [self postChange];
}

#pragma mark - Очередь

- (void)startPendingItems {
    NSInteger active = 0;
    NSMutableArray<YumiDownloadItem *> *pending = [NSMutableArray array];
    for (YumiDownloadItem *item in [self.mutableItems copy]) {
        BOOL running = item.started && !item.finished && !item.cancelled && !item.errorMessage.length;
        if (running) active += 1;
        if (!item.started && !item.finished && !item.cancelled && !item.errorMessage.length) {
            [pending addObject:item];
        }
    }

    for (YumiDownloadItem *item in pending) {
        if (active >= kYumiMaxConcurrentDownloads) break;
        if ([self startItem:item]) active += 1;
    }
}

- (BOOL)startItem:(YumiDownloadItem *)item {
    if (!item.url) return NO;

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 300.0;
    config.timeoutIntervalForResource = 1800.0;
    config.HTTPShouldSetCookies = NO;
    config.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;

    NSString *host = item.url.host.lowercaseString ?: @"";
    BOOL github = [host isEqualToString:@"github.com"] ||
                  [host hasSuffix:@".github.com"] ||
                  [host hasSuffix:@"githubusercontent.com"];
    NSString *ua = github ? kYumiGitHubDownloadUA : item.userAgent;

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:item.url
                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                            timeoutInterval:300.0];
    [request setValue:(github ? @"application/octet-stream" : @"*/*") forHTTPHeaderField:@"Accept"];
    [request setValue:@"ru-RU,ru;q=0.9,en;q=0.8" forHTTPHeaderField:@"Accept-Language"];
    if (ua.length) [request setValue:ua forHTTPHeaderField:@"User-Agent"];
    if (item.cookie.length) [request setValue:item.cookie forHTTPHeaderField:@"Cookie"];
    if (item.pageURLString.length) [request setValue:item.pageURLString forHTTPHeaderField:@"Referer"];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:self
                                                     delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request];
    item.session = session;
    item.task = task;
    item.started = YES;
    [task resume];

    [self beginBackgroundWork];
    [self postChange];
    return YES;
}

#pragma mark - NSURLSessionDownloadDelegate

- (YumiDownloadItem *)itemForTask:(NSURLSessionTask *)task {
    if (!task) return nil;
    for (YumiDownloadItem *item in self.mutableItems) {
        if (item.task == task) return item;
    }
    return nil;
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    YumiDownloadItem *item = [self itemForTask:downloadTask];
    if (!item) return;

    if (totalBytesExpectedToWrite > 0) {
        item.progress = (double)totalBytesWritten / (double)totalBytesExpectedToWrite;
        NSInteger percent = (NSInteger)(item.progress * 100.0);
        if (percent != self.lastPercent) {
            self.lastPercent = percent;
            [self postChange];
        }
    }
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    YumiDownloadItem *item = [self itemForTask:downloadTask];
    if (!item || !location) return;

    NSHTTPURLResponse *http = (NSHTTPURLResponse *)downloadTask.response;
    NSString *mime = [(http.MIMEType ?: @"") lowercaseString];
    if ([mime containsString:@"text/html"]) {
        item.errorMessage = @"Сервер вернул страницу вместо файла";
        return;
    }
    if ([http isKindOfClass:[NSHTTPURLResponse class]] &&
        (http.statusCode < 200 || http.statusCode >= 300)) {
        item.errorMessage = [NSString stringWithFormat:@"HTTP %ld", (long)http.statusCode];
        return;
    }

    NSString *directory = [self downloadsDirectory];
    NSString *destination = [self uniquePathInDirectory:directory filename:item.filename ?: @"download"];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *fileError = nil;
    BOOL saved = [fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:destination] error:&fileError];
    if (!saved) {
        fileError = nil;
        saved = [fm copyItemAtURL:location toURL:[NSURL fileURLWithPath:destination] error:&fileError];
    }
    if (!saved) {
        item.errorMessage = fileError.localizedDescription ?: @"Не удалось сохранить файл";
        return;
    }

    item.destinationPath = destination;
    item.progress = 1.0;
    item.finished = YES;
    item.saved = YES;
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    YumiDownloadItem *item = [self itemForTask:task];
    if (!item) {
        [session finishTasksAndInvalidate];
        return;
    }

    [session finishTasksAndInvalidate];
    item.session = nil;
    item.task = nil;

    if (error && !item.finished) {
        if (error.code == NSURLErrorCancelled || item.cancelled) {
            item.cancelled = YES;
        } else {
            item.errorMessage = error.localizedDescription ?: @"Ошибка загрузки";
        }
    } else if (!item.finished && !item.cancelled && !item.errorMessage.length) {
        item.errorMessage = @"Загрузка завершилась без файла";
    }

    if (self.onEvent) {
        if (item.finished) self.onEvent(item, @"finish");
        else if (item.errorMessage.length) self.onEvent(item, @"error");
    }

    [self postChange];
    [self startPendingItems];
    [self endBackgroundWorkIfIdle];
}

#pragma mark - Служебное

- (void)postChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:YumiDownloadsDidChangeNotification
                                                            object:self];
    });
}

- (NSString *)sanitizedFilename:(NSString *)filename url:(NSURL *)url {
    NSString *name = filename.length ? [filename copy] : (url.lastPathComponent ?: @"download");
    NSString *decoded = [name stringByRemovingPercentEncoding];
    if (decoded.length) name = decoded;

    NSArray<NSString *> *bad = @[@"/", @"\\", @":"];
    for (NSString *token in bad) {
        name = [name stringByReplacingOccurrencesOfString:token withString:@"_"];
    }
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!name.length || [name isEqualToString:@"."] || [name isEqualToString:@".."]) {
        name = @"download";
    }
    if (![name pathExtension].length && [url pathExtension].length) {
        name = [name stringByAppendingPathExtension:url.pathExtension];
    }
    return name;
}

- (NSString *)uniquePathInDirectory:(NSString *)directory filename:(NSString *)name {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *destination = [directory stringByAppendingPathComponent:name];
    if (![fm fileExistsAtPath:destination]) return destination;

    NSString *base = [name stringByDeletingPathExtension];
    NSString *extension = [name pathExtension];
    NSInteger index = 1;
    while (YES) {
        NSString *candidate = extension.length
            ? [NSString stringWithFormat:@"%@-%ld.%@", base, (long)index, extension]
            : [NSString stringWithFormat:@"%@-%ld", base, (long)index];
        destination = [directory stringByAppendingPathComponent:candidate];
        if (![fm fileExistsAtPath:destination]) break;
        index += 1;
    }
    return destination;
}

- (void)beginBackgroundWork {
    if (self.backgroundTask != UIBackgroundTaskInvalid) return;
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        // iOS даёт около трёх минут; после этого задачи продолжатся, когда
        // пользователь вернётся в приложение.
    }];
}

- (void)endBackgroundWorkIfIdle {
    BOOL active = NO;
    for (YumiDownloadItem *item in self.mutableItems) {
        if (item.started && !item.finished && !item.cancelled && !item.errorMessage.length) {
            active = YES;
            break;
        }
    }
    if (active) return;
    if (self.backgroundTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }
}

@end
