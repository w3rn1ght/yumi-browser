#import <Foundation/Foundation.h>

@interface YumiResumeStore : NSObject

/** Последняя позиция просмотра для страницы тайтла (pageID). */
+ (NSDictionary *)resumeForPageID:(NSString *)pageID;

+ (void)saveForPageID:(NSString *)pageID
              animeID:(NSString *)animeID
              episode:(NSString *)episode
              dubbing:(NSString *)dubbing
                 time:(NSTimeInterval)time
             duration:(NSTimeInterval)duration
                title:(NSString *)title;

+ (void)clearForPageID:(NSString *)pageID;

+ (NSString *)timeStringForSeconds:(NSTimeInterval)seconds;

@end
