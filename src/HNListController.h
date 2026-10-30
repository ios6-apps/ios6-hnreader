#import <UIKit/UIKit.h>
#import "HNAPI.h"

/* One tab: a pull-to-refresh list of stories drawn as paper strips on linen. */
@interface HNListController : UITableViewController
- (id)initWithKind:(HNKind)kind;
@end
