#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, HNKind) { HNKindNews, HNKindAsk, HNKindShow, HNKindSaved };

@interface HNStory : NSObject
@property (nonatomic, copy) NSString *sid, *title, *url, *author, *text, *domain;
@property (nonatomic) NSInteger points, comments;
@property (nonatomic) NSTimeInterval created;
+ (HNStory *)storyFromDict:(NSDictionary *)d;
- (NSDictionary *)dictionary;   /* same keys as the Algolia hit, for storing */
@end

/* one row of the comments table: the story header (isHeader) or a flattened comment with its depth */
@interface HNComment : NSObject
@property (nonatomic, copy) NSString *author, *text;
@property (nonatomic, strong) HNStory *story;
@property (nonatomic) NSInteger depth, hidden;
@property (nonatomic) NSTimeInterval created;
@property (nonatomic) BOOL collapsed, isHeader;
@property (nonatomic) CGFloat height, heightWidth;
@end

typedef void (^HNStoriesBlock)(NSArray *stories, NSString *error);
typedef void (^HNItemBlock)(HNStory *story, NSArray *comments, NSString *error);

/* Saved stories, kept in NSUserDefaults, newest first. */
@interface HNFavorites : NSObject
+ (NSArray *)stories;
+ (BOOL)contains:(NSString *)sid;
+ (BOOL)toggle:(HNStory *)story;     /* returns the new state */
+ (void)remove:(NSString *)sid;
@end

/* Reads the HN Algolia API (one request returns a story with its whole comment tree).
   The base URL can be overridden by putting a URL in /var/mobile/hnbase.txt (e.g. a local proxy while debugging TLS). */
@interface HNAPI : NSObject
+ (void)loadStories:(HNKind)kind done:(HNStoriesBlock)done;
+ (void)loadItem:(NSString *)sid done:(HNItemBlock)done;
@end
