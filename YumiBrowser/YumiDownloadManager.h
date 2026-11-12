#import <Foundation/Foundation.h>

extern NSString *const YumiDownloadsDidChangeNotification;
extern NSString *const YumiDownloadDidFinishNotification;
extern NSString *const YumiDownloadDidFailNotification;

/** Одна загрузка. Прогресс и состояние читает UI. */
@interface YumiDownloadItem : NSObject

@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *filename;
@property (nonatomic, copy) NSString *destinationPath;
@property (nonatomic, copy) NSString *pageURLString;
@property (nonatomic, assign) double progress;        // 0.0 … 1.0
@property (nonatomic, assign) BOOL finished;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, copy) NSString *errorMessage;

/** "Готово", "Ошибка", "Отменено", "Скачивается 42%" — для таблицы загрузок. */
- (NSString *)stateText;

@end

/**
 * Очередь загрузок. Никаких модальных окон: задачи идут в фоне (в пределах
 * лимита iOS), а прогресс UI читает из items по нотификации.
 */
@interface YumiDownloadManager : NSObject

+ (instancetype)shared;

/** Новые сверху. */
@property (nonatomic, readonly) NSArray<YumiDownloadItem *> *items;

/** Вызывается на главном потоке после старта/финиша/ошибки. */
@property (nonatomic, copy) void (^onEvent)(YumiDownloadItem *item, NSString *event);

- (void)enqueueURL:(NSURL *)url
          filename:(NSString *)filename
           pageURL:(NSURL *)pageURL
            cookie:(NSString *)cookie
         userAgent:(NSString *)userAgent;

- (void)cancelItem:(YumiDownloadItem *)item;
- (void)removeItem:(YumiDownloadItem *)item;

- (NSString *)downloadsDirectory;

@end
