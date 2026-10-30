#import "HNChrome.h"
#import "HNStyle.h"
#import "HNListController.h"

#define NAV_H 44
#define TAB_H 49

#pragma mark - small controls

@interface HNBackButton : UIControl
@property (nonatomic, copy) NSString *label;
@end

@implementation HNBackButton
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    /* one path: a rounded body with a pointed left end */
    CGContextMoveToPoint(c, 12, 0.5);
    CGContextAddLineToPoint(c, w - 5.5, 0.5);
    CGContextAddArcToPoint(c, w - 0.5, 0.5, w - 0.5, 5.5, 5);
    CGContextAddLineToPoint(c, w - 0.5, h - 5.5);
    CGContextAddArcToPoint(c, w - 0.5, h - 0.5, w - 5.5, h - 0.5, 5);
    CGContextAddLineToPoint(c, 12, h - 0.5);
    CGContextAddLineToPoint(c, 0.5, h / 2);
    CGContextClosePath(c);
    CGPathRef path = CGContextCopyPath(c);
    CGContextSaveGState(c);
    CGContextClip(c);
    BOOL d = self.highlighted;
    HNFillGradient(c, self.bounds, d ? HNRGB(130, 44, 0) : HNRGB(206, 86, 18), d ? HNRGB(160, 54, 0) : HNRGB(168, 56, 0));
    HNFillGradient(c, CGRectMake(0, 0, w, h / 2), [UIColor colorWithWhite:1 alpha:d ? 0.08 : 0.26], [UIColor colorWithWhite:1 alpha:0.02]);
    CGContextRestoreGState(c);
    CGContextAddPath(c, path); CGPathRelease(path);
    [HNRGB(100, 30, 0) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
    HNDrawText(self.label, CGRectMake(13, 7, w - 17, 16), [UIFont fontWithName:@"HelveticaNeue-Bold" size:12.5],
               [UIColor whiteColor], [UIColor colorWithWhite:0 alpha:0.5], -1, NSTextAlignmentCenter);
}
@end

@implementation HNActionButton
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; } return self; }
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    BOOL d = self.highlighted;
    HNGlossRoundRect(c, self.bounds, 5, d ? HNRGB(130, 44, 0) : HNRGB(206, 86, 18), d ? HNRGB(160, 54, 0) : HNRGB(168, 56, 0), HNRGB(100, 30, 0));
    CGFloat cx = self.bounds.size.width / 2, cy = self.bounds.size.height / 2;
    [[UIColor whiteColor] set];
    CGContextSetLineWidth(c, 2);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 1), 0, [UIColor colorWithWhite:0 alpha:0.4].CGColor);
    /* box with an arrow leaving it */
    CGContextMoveToPoint(c, cx - 1, cy - 6); CGContextAddLineToPoint(c, cx - 6, cy - 6); CGContextAddLineToPoint(c, cx - 6, cy + 6);
    CGContextAddLineToPoint(c, cx + 6, cy + 6); CGContextAddLineToPoint(c, cx + 6, cy + 1);
    CGContextStrokePath(c);
    CGContextMoveToPoint(c, cx - 2, cy + 2); CGContextAddLineToPoint(c, cx + 6, cy - 6); CGContextStrokePath(c);
    CGContextMoveToPoint(c, cx + 1, cy - 7); CGContextAddLineToPoint(c, cx + 7, cy - 7); CGContextAddLineToPoint(c, cx + 7, cy - 1); CGContextStrokePath(c);
}
@end

@implementation HNStarButton
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; } return self; }
- (void)setOn:(BOOL)on { _on = on; [self setNeedsDisplay]; }
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; [self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    BOOL d = self.highlighted;
    HNGlossRoundRect(c, self.bounds, 5, d ? HNRGB(130, 44, 0) : HNRGB(206, 86, 18), d ? HNRGB(160, 54, 0) : HNRGB(168, 56, 0), HNRGB(100, 30, 0));
    CGFloat cx = self.bounds.size.width / 2, cy = self.bounds.size.height / 2 + 0.5, R = 9.5, r = 4.2;
    for (int i = 0; i < 10; i++) {
        CGFloat a = -M_PI / 2 + i * M_PI / 5, rad = (i % 2) ? r : R;
        CGPoint pt = CGPointMake(cx + cos(a) * rad, cy + sin(a) * rad);
        if (i == 0) CGContextMoveToPoint(c, pt.x, pt.y); else CGContextAddLineToPoint(c, pt.x, pt.y);
    }
    CGContextClosePath(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 1), 0, [UIColor colorWithWhite:0 alpha:0.4].CGColor);
    if (self.on) { [HNRGB(255, 232, 150) setFill]; CGContextFillPath(c); }
    else { [[UIColor whiteColor] setStroke]; CGContextSetLineWidth(c, 1.8); CGContextSetLineJoin(c, kCGLineJoinRound); CGContextStrokePath(c); }
}
@end

@interface HNSegmented ()
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) NSMutableArray *disabled;
@end

@implementation HNSegmented
- (id)initWithItems:(NSArray *)items {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 148, 30)])) {
        self.items = items;
        self.disabled = [NSMutableArray array];
        for (NSUInteger i = 0; i < items.count; i++) [self.disabled addObject:[NSNumber numberWithBool:NO]];
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}
- (void)setSelectedIndex:(NSInteger)i { _selectedIndex = i; [self setNeedsDisplay]; }
- (void)setEnabled:(BOOL)on forIndex:(NSInteger)i { [self.disabled replaceObjectAtIndex:i withObject:[NSNumber numberWithBool:!on]]; [self setNeedsDisplay]; }

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    CGFloat sw = b.size.width / self.items.count;
    /* recessed track */
    CGContextSaveGState(c);
    HNRoundRectPath(c, CGRectInset(b, 0.5, 0.5), 6); CGContextClip(c);
    HNFillGradient(c, b, HNRGB(110, 36, 0), HNRGB(150, 50, 0));
    for (NSUInteger i = 0; i < self.items.count; i++) {
        CGRect seg = CGRectMake(i * sw, 0, sw, b.size.height);
        BOOL sel = (NSInteger)i == self.selectedIndex;
        if (sel) {
            HNFillGradient(c, CGRectInset(seg, 1, 1), HNRGB(248, 160, 88), HNRGB(222, 104, 30));
            HNFillGradient(c, CGRectMake(seg.origin.x + 1, 1, sw - 2, b.size.height / 2 - 1), [UIColor colorWithWhite:1 alpha:0.32], [UIColor colorWithWhite:1 alpha:0.04]);
        } else {
            HNFillGradient(c, seg, HNRGB(196, 78, 12), HNRGB(158, 52, 0));
            HNFillGradient(c, CGRectMake(seg.origin.x, 0, sw, b.size.height / 2), [UIColor colorWithWhite:1 alpha:0.2], [UIColor colorWithWhite:1 alpha:0.02]);
        }
        if (i > 0) { [HNRGB(100, 30, 0) set]; CGContextFillRect(c, CGRectMake(seg.origin.x, 0, 1, b.size.height)); }
    }
    CGContextRestoreGState(c);
    HNRoundRectPath(c, CGRectInset(b, 0.5, 0.5), 6);
    [HNRGB(90, 26, 0) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
    for (NSUInteger i = 0; i < self.items.count; i++) {
        BOOL off = [[self.disabled objectAtIndex:i] boolValue], sel = (NSInteger)i == self.selectedIndex;
        UIColor *col = off ? [UIColor colorWithWhite:1 alpha:0.35] : (sel ? HNRGB(96, 30, 0) : [UIColor whiteColor]);
        UIColor *sh = sel ? [UIColor colorWithWhite:1 alpha:0.5] : [UIColor colorWithWhite:0 alpha:0.45];
        HNDrawText([self.items objectAtIndex:i], CGRectMake(i * sw, 7, sw, 16), [UIFont fontWithName:@"HelveticaNeue-Bold" size:13], col, sh, sel ? 1 : -1, NSTextAlignmentCenter);
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {
    CGPoint p = [[touches anyObject] locationInView:self];
    NSInteger i = MIN((NSInteger)self.items.count - 1, MAX(0, (NSInteger)(p.x / (self.bounds.size.width / self.items.count))));
    if ([[self.disabled objectAtIndex:i] boolValue] || i == self.selectedIndex) return;
    self.selectedIndex = i;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}
@end

#pragma mark - bars

@interface HNShadowView : UIView
@property (nonatomic) BOOL flip;
@end
@implementation HNShadowView
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.userInteractionEnabled = NO; } return self; }
- (void)drawRect:(CGRect)r {
    HNFillGradient(UIGraphicsGetCurrentContext(), self.bounds, [UIColor colorWithWhite:0 alpha:self.flip ? 0 : 0.4], [UIColor colorWithWhite:0 alpha:self.flip ? 0.4 : 0]);
}
@end

@interface HNNavBar : UIView
@property (nonatomic, strong) HNBackButton *back;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *titleView, *rightView;
- (void)setTitle:(NSString *)t titleView:(UIView *)tv rightView:(UIView *)rv showBack:(BOOL)b;
@end

@implementation HNNavBar
- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.backgroundColor = [UIColor clearColor];
        self.back = [[HNBackButton alloc] initWithFrame:CGRectMake(6, 7, 58, 30)];
        self.back.backgroundColor = [UIColor clearColor];
        self.back.label = @"Back";
        [self addSubview:self.back];
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.font = [UIFont fontWithName:@"Georgia-Bold" size:20];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.5];
        self.titleLabel.shadowOffset = CGSizeMake(0, -1);
        [self addSubview:self.titleLabel];
    }
    return self;
}
- (void)setTitle:(NSString *)t titleView:(UIView *)tv rightView:(UIView *)rv showBack:(BOOL)b {
    if (self.titleView != tv) { [self.titleView removeFromSuperview]; self.titleView = tv; if (tv) [self addSubview:tv]; }
    if (self.rightView != rv) { [self.rightView removeFromSuperview]; self.rightView = rv; if (rv) [self addSubview:rv]; }
    self.titleLabel.text = t;
    self.titleLabel.hidden = tv != nil;
    self.back.hidden = !b;
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    CGFloat w = self.bounds.size.width;
    self.titleLabel.frame = CGRectMake(72, 0, w - 144, NAV_H - 2);
    self.titleView.center = CGPointMake(w / 2, NAV_H / 2 - 1);
    CGRect r = self.rightView.bounds;
    self.rightView.frame = CGRectMake(w - 8 - r.size.width, (NAV_H - r.size.height) / 2 - 1, r.size.width, r.size.height);
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    HNFillGradient(c, CGRectMake(0, 0, b.size.width, NAV_H / 2), HNRGB(244, 134, 56), HNRGB(226, 104, 26));
    HNFillGradient(c, CGRectMake(0, NAV_H / 2, b.size.width, NAV_H / 2), HNRGB(210, 82, 10), HNRGB(186, 60, 0));
    [[UIColor colorWithWhite:1 alpha:0.45] set]; CGContextFillRect(c, CGRectMake(0, 0, b.size.width, 1));
    [HNRGB(96, 28, 0) set]; CGContextFillRect(c, CGRectMake(0, NAV_H - 1, b.size.width, 1));
}
@end

@interface HNTabBar : UIView
@property (nonatomic) NSInteger selected;
@property (nonatomic, copy) void (^onSelect)(NSInteger);
@end

@implementation HNTabBar
- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.opaque = YES; } return self; }
- (void)setSelected:(NSInteger)s { _selected = s; [self setNeedsDisplay]; }

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    CGFloat w = b.size.width;
    [[UIColor colorWithPatternImage:HNLeatherImage()] setFill];
    CGContextFillRect(c, b);
    HNFillGradient(c, b, [UIColor colorWithWhite:1 alpha:0.14], [UIColor colorWithWhite:0 alpha:0.35]);
    [[UIColor colorWithWhite:0 alpha:0.7] set]; CGContextFillRect(c, CGRectMake(0, 0, w, 1));
    [[UIColor colorWithWhite:1 alpha:0.25] set]; CGContextFillRect(c, CGRectMake(0, 1, w, 1));

    NSArray *names = [NSArray arrayWithObjects:@"News", @"Ask", @"Show", @"Saved", nil];
    CGFloat iw = w / 4;
    for (int i = 0; i < 4; i++) {
        BOOL sel = i == self.selected;
        CGRect cell = CGRectMake(i * iw, 0, iw, TAB_H);
        if (!sel && i > 0 && i - 1 != self.selected) {   /* hairline dividers between idle tabs */
            [[UIColor colorWithWhite:0 alpha:0.35] set]; CGContextFillRect(c, CGRectMake(cell.origin.x - 1, 6, 1, TAB_H - 10));
            [[UIColor colorWithWhite:1 alpha:0.08] set]; CGContextFillRect(c, CGRectMake(cell.origin.x, 6, 1, TAB_H - 10));
        }
        if (sel) {   /* pressed-in, full height: the slot runs edge to edge under the top bevel */
            CGRect slot = CGRectMake(cell.origin.x, 2, iw, TAB_H - 2);
            CGContextSaveGState(c);
            CGContextClipToRect(c, slot);
            HNFillGradient(c, slot, HNRGB(16, 9, 5), HNRGB(70, 46, 32));
            HNFillGradient(c, CGRectMake(slot.origin.x, slot.origin.y, iw, 12), [UIColor colorWithWhite:0 alpha:0.65], [UIColor colorWithWhite:0 alpha:0]);
            CGFloat gc[8] = {1.0, 0.45, 0.1, 0.42,  1.0, 0.45, 0.1, 0.0};
            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            CGGradientRef g = CGGradientCreateWithColorComponents(cs, gc, NULL, 2);
            CGPoint ctr = CGPointMake(CGRectGetMidX(slot), 19);
            CGContextDrawRadialGradient(c, g, ctr, 0, ctr, 34, 0);
            CGGradientRelease(g); CGColorSpaceRelease(cs);
            [[UIColor colorWithWhite:0 alpha:0.8] set];
            CGContextFillRect(c, CGRectMake(slot.origin.x, slot.origin.y, 1, slot.size.height));
            CGContextFillRect(c, CGRectMake(CGRectGetMaxX(slot) - 1, slot.origin.y, 1, slot.size.height));
            [[UIColor colorWithWhite:1 alpha:0.07] set];
            CGContextFillRect(c, CGRectMake(slot.origin.x + 1, slot.origin.y, 1, slot.size.height));
            CGContextFillRect(c, CGRectMake(CGRectGetMaxX(slot) - 2, slot.origin.y, 1, slot.size.height));
            CGContextRestoreGState(c);
        }
        /* icon: gradient poured through the glyph's alpha mask */
        UIImage *ic = HNTabIcon(i);
        CGRect ir = CGRectMake(cell.origin.x + (iw - 24) / 2, 7, 24, 24);
        CGContextSaveGState(c);
        CGContextTranslateCTM(c, ir.origin.x, ir.origin.y + 24);
        CGContextScaleCTM(c, 1, -1);
        CGContextClipToMask(c, CGRectMake(0, 0, 24, 24), ic.CGImage);
        CGContextScaleCTM(c, 1, -1);
        CGContextTranslateCTM(c, -ir.origin.x, -(ir.origin.y + 24));
        if (sel) HNFillGradient(c, ir, HNRGB(255, 206, 140), HNRGB(238, 110, 24));
        else HNFillGradient(c, ir, HNRGB(206, 200, 192), HNRGB(116, 110, 102));
        CGContextRestoreGState(c);
        HNDrawText([names objectAtIndex:i], CGRectMake(cell.origin.x, 32, iw, 12), [UIFont fontWithName:@"HelveticaNeue-Bold" size:10],
                   sel ? HNRGB(255, 176, 96) : HNRGB(170, 164, 154), [UIColor blackColor], -1, NSTextAlignmentCenter);
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {
    NSInteger i = MIN(3, MAX(0, (NSInteger)([[touches anyObject] locationInView:self].x / (self.bounds.size.width / 4))));
    if (self.onSelect) self.onSelect(i);
}
@end

#pragma mark - root controller

static __unsafe_unretained HNRootController *gRoot;

@interface HNRootController () {
    NSMutableArray *_stacks;
    NSInteger _tab;
    HNNavBar *_nav;
    UIView *_content, *_strip;
    HNTabBar *_tabs;
    HNShadowView *_shadowTop, *_shadowBottom;
    CGFloat _top;
}
@end

@implementation HNRootController

+ (HNRootController *)shared { return gRoot; }

- (id)init {
    if ((self = [super init])) {
        gRoot = self;
        _stacks = [NSMutableArray array];
        for (int k = 0; k < 4; k++) [_stacks addObject:[NSMutableArray arrayWithObject:[[HNListController alloc] initWithKind:(HNKind)k]]];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    _strip = [[UIView alloc] init];
    _strip.backgroundColor = [UIColor blackColor];
    _content = [[UIView alloc] init];
    _content.clipsToBounds = YES;
    _content.backgroundColor = [UIColor colorWithPatternImage:HNLinenImage()];
    _nav = [[HNNavBar alloc] init];
    [_nav.back addTarget:self action:@selector(pop) forControlEvents:UIControlEventTouchUpInside];
    _tabs = [[HNTabBar alloc] init];
    __unsafe_unretained HNRootController *me = self;
    _tabs.onSelect = ^(NSInteger i) { [me selectTab:i]; };
    _shadowTop = [[HNShadowView alloc] init];
    _shadowBottom = [[HNShadowView alloc] init];
    _shadowBottom.flip = YES;
    for (UIView *v in [NSArray arrayWithObjects:_content, _shadowTop, _shadowBottom, _nav, _tabs, _strip, nil]) [self.view addSubview:v];
#ifdef HN_PREVIEW
    UILabel *t = [[UILabel alloc] initWithFrame:CGRectMake(0, 2, 320, 16)];
    t.text = @"9:41"; t.textAlignment = NSTextAlignmentCenter; t.backgroundColor = [UIColor clearColor];
    t.textColor = [UIColor whiteColor]; t.font = [UIFont boldSystemFontOfSize:12];
    [_strip addSubview:t];
#endif
    [self showTop];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    /* iOS 6 puts the root view below the status bar already; later systems extend it underneath (and the simulator preview offsets it) */
    CGRect inWindow = [self.view convertRect:self.view.bounds toView:nil];
    _top = fabs(inWindow.origin.y - 20) < 1 ? 0 : 20;   /* iOS 6: view starts at y=20 */
    CGFloat w = b.size.width, h = b.size.height;
    _strip.frame = CGRectMake(0, 0, w, _top);
    _nav.frame = CGRectMake(0, _top, w, NAV_H);
    _tabs.frame = CGRectMake(0, h - TAB_H, w, TAB_H);
    _content.frame = CGRectMake(0, _top + NAV_H, w, h - _top - NAV_H - TAB_H);
    _shadowTop.frame = CGRectMake(0, _top + NAV_H, w, 6);
    _shadowBottom.frame = CGRectMake(0, h - TAB_H - 6, w, 6);
    [_nav setNeedsDisplay]; [_tabs setNeedsDisplay];
    for (NSArray *st in _stacks) { UIViewController *vc = st.lastObject; if (vc.isViewLoaded && vc.view.superview) vc.view.frame = _content.bounds; }
}

- (NSMutableArray *)stack { return [_stacks objectAtIndex:_tab]; }

- (void)showTop {
    UIViewController *vc = [self stack].lastObject;
    if (vc.parentViewController != self) [self addChildViewController:vc];
    UIView *v = vc.view;
    v.frame = _content.bounds;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_content addSubview:v];
    [vc didMoveToParentViewController:self];
    if ([vc respondsToSelector:@selector(hnWillShow)]) [(id<HNScreen>)vc hnWillShow];
    _tabs.selected = _tab;
    [self refreshBar];
}

- (void)refreshBar {
    UIViewController *vc = [self stack].lastObject;
    id<HNScreen> s = (id<HNScreen>)vc;
    NSString *t = [s respondsToSelector:@selector(hnTitle)] ? [s hnTitle] : nil;
    UIView *tv = [s respondsToSelector:@selector(hnTitleView)] ? [s hnTitleView] : nil;
    UIView *rv = [s respondsToSelector:@selector(hnRightView)] ? [s hnRightView] : nil;
    [_nav setTitle:t titleView:tv rightView:rv showBack:[self stack].count > 1];
}

- (void)selectTab:(NSInteger)tab {
    if (tab == _tab) {
        while ([self stack].count > 1) [self popImmediately];   /* tapping the active tab returns to its list */
        return;
    }
    [[[self stack].lastObject view] removeFromSuperview];
    _tab = tab;
    [self showTop];
}

- (void)popImmediately {
    NSMutableArray *st = [self stack];
    UIViewController *gone = st.lastObject;
    [gone willMoveToParentViewController:nil];
    [gone.view removeFromSuperview];
    [gone removeFromParentViewController];
    [st removeLastObject];
    [self showTop];
}

- (void)push:(UIViewController *)vc {
    NSMutableArray *st = [self stack];
    UIViewController *old = st.lastObject;
    CGFloat w = _content.bounds.size.width;
    [st addObject:vc];
    [self addChildViewController:vc];
    UIView *v = vc.view;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    v.frame = CGRectOffset(_content.bounds, w, 0);
    [_content addSubview:v];
    [vc didMoveToParentViewController:self];
    [self refreshBar];
    [UIView animateWithDuration:0.3 animations:^{
        v.frame = self->_content.bounds;
        old.view.frame = CGRectOffset(self->_content.bounds, -w / 3, 0);
    } completion:^(BOOL f) {
        [old.view removeFromSuperview];
        old.view.frame = self->_content.bounds;
    }];
}

- (void)pop {
    NSMutableArray *st = [self stack];
    if (st.count < 2) return;
    UIViewController *gone = st.lastObject, *prev = [st objectAtIndex:st.count - 2];
    CGFloat w = _content.bounds.size.width;
    if ([prev respondsToSelector:@selector(hnWillShow)]) [(id<HNScreen>)prev hnWillShow];
    prev.view.frame = CGRectOffset(_content.bounds, -w / 3, 0);
    [_content insertSubview:prev.view belowSubview:gone.view];
    [st removeLastObject];
    [self refreshBar];
    [UIView animateWithDuration:0.3 animations:^{
        gone.view.frame = CGRectOffset(self->_content.bounds, w, 0);
        prev.view.frame = self->_content.bounds;
    } completion:^(BOOL f) {
        [gone willMoveToParentViewController:nil];
        [gone.view removeFromSuperview];
        [gone removeFromParentViewController];
    }];
}

- (BOOL)shouldAutorotate { return NO; }
- (NSUInteger)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }

@end
