#import <UIKit/UIKit.h>

@interface YumiPlayerViewController : UIViewController

- (instancetype)initWithURL:(NSURL *)url
                    headers:(NSDictionary<NSString *, NSString *> *)headers
                      title:(NSString *)title;

@property (nonatomic, copy) NSString *resumeKey;     // id страницы тайтла (для памяти просмотра)
@property (nonatomic, copy) NSString *animeID;
@property (nonatomic, copy) NSString *episode;
@property (nonatomic, copy) NSString *dubbing;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, copy) NSArray<NSDictionary<NSString *, NSString *> *> *qualityOptions;
@property (nonatomic, copy) void (^onDismiss)(void);

@end
