#import <UIKit/UIKit.h>
#import "HNAPI.h"

/* A story: segmented Article / Comments, the article in a web view, the comments as threaded paper cards. */
@interface HNStoryController : UIViewController
- (id)initWithStory:(HNStory *)story;
@end
