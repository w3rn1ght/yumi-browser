#import <UIKit/UIKit.h>

@class YummyEpisodesViewController;

typedef void (^YumiEpisodesFetchBlock)(void (^completion)(NSArray<NSDictionary *> *episodes, NSError *error));
typedef void (^YumiEpisodeResolveBlock)(NSDictionary *source,
                                        NSString *episode,
                                        void (^completion)(NSURL *url,
                                                           NSDictionary<NSString *, NSString *> *headers,
                                                           NSArray<NSDictionary<NSString *, NSString *> *> *qualities,
                                                           NSString *title,
                                                           NSError *error));

@protocol YummyEpisodesViewControllerDelegate <NSObject>
- (void)yummyEpisodesController:(YummyEpisodesViewController *)controller
                  playStreamURL:(NSURL *)url
                        headers:(NSDictionary<NSString *, NSString *> *)headers
                          title:(NSString *)title
                         resume:(NSDictionary *)resume;
@end

@interface YummyEpisodesViewController : UIViewController

- (instancetype)initWithPageID:(NSString *)pageID
                     pageTitle:(NSString *)pageTitle
                        resume:(NSDictionary *)resume
                    fetchBlock:(YumiEpisodesFetchBlock)fetchBlock
                  resolveBlock:(YumiEpisodeResolveBlock)resolveBlock;

@property (nonatomic, weak) id<YummyEpisodesViewControllerDelegate> delegate;

@end
