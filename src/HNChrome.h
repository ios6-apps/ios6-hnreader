#import <UIKit/UIKit.h>

/* Custom-drawn chrome (nav bar, back button, segmented control, leather tab bar) and a tiny navigation stack.
   UIKit's own bars are not used, so the app looks the same on every iOS version. */

@protocol HNScreen <NSObject>
@optional
- (NSString *)hnTitle;
- (UIView *)hnTitleView;    /* replaces the title (e.g. the Article / Comments control) */
- (UIView *)hnRightView;
- (void)hnWillShow;         /* the screen is about to become visible again */
@end

/* glossy segmented control for the nav bar */
@interface HNSegmented : UIControl
@property (nonatomic) NSInteger selectedIndex;
- (id)initWithItems:(NSArray *)items;
- (void)setEnabled:(BOOL)on forIndex:(NSInteger)i;
@end

/* round glossy "open in Safari" button */
@interface HNActionButton : UIControl
@end

/* glossy star button: filled when the story is saved */
@interface HNStarButton : UIControl
@property (nonatomic) BOOL on;
@end

@interface HNRootController : UIViewController
+ (HNRootController *)shared;
- (void)push:(UIViewController *)vc;
- (void)pop;
- (void)selectTab:(NSInteger)tab;
- (void)refreshBar;         /* call when a screen's title / right view changed */
@end
