#import "HNListController.h"
#import "HNStoryController.h"
#import "HNChrome.h"
#import "HNStyle.h"

#define TEXT_X 54
#define SIDE_W 70

@interface HNStoryView : UIView
@property (nonatomic, strong) HNStory *story;
@property (nonatomic) NSInteger rank;
@property (nonatomic) BOOL lit;
+ (CGFloat)heightForStory:(HNStory *)s width:(CGFloat)w;
@end

@implementation HNStoryView

+ (UIFont *)titleFont { return [UIFont fontWithName:@"Georgia-Bold" size:16]; }
+ (UIFont *)metaFont { return [UIFont fontWithName:@"HelveticaNeue" size:12]; }

+ (CGFloat)titleHeight:(HNStory *)s width:(CGFloat)w {
    return HNTextHeight(s.title, [self titleFont], w - TEXT_X - SIDE_W, 66);
}

+ (CGFloat)heightForStory:(HNStory *)s width:(CGFloat)w {
    return MAX(90, [self titleHeight:s width:w] + 56);
}

- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat w = self.bounds.size.width;
    HNStory *s = self.story;
    CGRect card = CGRectMake(8, 5, w - 16, self.bounds.size.height - 10);

    /* a paper card lying on the linen */
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 1.5), 4, [UIColor colorWithWhite:0 alpha:0.5].CGColor);
    HNRoundRectPath(c, card, 6);
    [HNRGB(250, 247, 238) setFill];
    CGContextFillPath(c);
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    HNRoundRectPath(c, card, 6); CGContextClip(c);
    if (self.lit) HNFillGradient(c, card, HNRGB(255, 226, 190), HNRGB(250, 200, 150));
    else HNFillGradient(c, card, HNRGB(255, 253, 247), HNRGB(242, 237, 224));
    [[UIColor colorWithWhite:1 alpha:0.9] set]; CGContextFillRect(c, CGRectMake(card.origin.x, card.origin.y, card.size.width, 1));
    CGContextRestoreGState(c);
    HNRoundRectPath(c, CGRectInset(card, 0.5, 0.5), 5.5);
    [HNRGB(186, 176, 156) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);

    /* rank: a glossy dark button */
    CGRect badge = CGRectMake(20, 20, 26, 26);
    CGContextSaveGState(c);
    CGContextAddEllipseInRect(c, badge); CGContextClip(c);
    HNFillGradient(c, badge, HNRGB(120, 110, 100), HNRGB(38, 32, 28));
    CGContextRestoreGState(c);
    [HNRGB(30, 24, 20) set]; CGContextSetLineWidth(c, 1); CGContextStrokeEllipseInRect(c, CGRectInset(badge, 0.5, 0.5));
    CGContextSaveGState(c);
    CGRect gloss = CGRectMake(badge.origin.x + 3, badge.origin.y + 1.5, 20, 11);
    CGContextAddEllipseInRect(c, gloss); CGContextClip(c);
    HNFillGradient(c, gloss, [UIColor colorWithWhite:1 alpha:0.38], [UIColor colorWithWhite:1 alpha:0.04]);
    CGContextRestoreGState(c);
    HNDrawText([NSString stringWithFormat:@"%ld", (long)self.rank], CGRectMake(badge.origin.x, badge.origin.y + 6, 26, 16),
               [UIFont fontWithName:@"HelveticaNeue-Bold" size:12], [UIColor whiteColor], [UIColor colorWithWhite:0 alpha:0.6], 1, NSTextAlignmentCenter);

    /* title letterpressed into the paper */
    CGFloat tw = w - TEXT_X - SIDE_W;
    CGFloat th = [HNStoryView titleHeight:s width:w];
    HNDrawText(s.title, CGRectMake(TEXT_X, 17, tw, th), [HNStoryView titleFont], HNRGB(43, 33, 24), [UIColor whiteColor], 1, NSTextAlignmentLeft);

    NSMutableArray *bits = [NSMutableArray array];
    if (s.domain) [bits addObject:s.domain.length > 20 ? [[s.domain substringToIndex:19] stringByAppendingString:@"…"] : s.domain];
    if (s.author) [bits addObject:[@"by " stringByAppendingString:s.author]];
    [bits addObject:HNTimeAgo(s.created)];
    HNDrawText([bits componentsJoinedByString:@"  ·  "], CGRectMake(TEXT_X, 17 + th + 5, tw + 4, 16),
               [HNStoryView metaFont], HNRGB(128, 112, 92), [UIColor whiteColor], 1, NSTextAlignmentLeft);

    /* points: glossy orange pill */
    CGRect pill = CGRectMake(w - 66, 19, 50, 22);
    HNGlossRoundRect(c, pill, 11, HNRGB(246, 142, 62), HNRGB(210, 80, 10), HNRGB(150, 52, 0));
    HNDrawText([NSString stringWithFormat:@"%ld", (long)s.points], CGRectMake(pill.origin.x, pill.origin.y + 3, pill.size.width, 16),
               [UIFont fontWithName:@"HelveticaNeue-Bold" size:13], [UIColor whiteColor], [UIColor colorWithWhite:0 alpha:0.35], -1, NSTextAlignmentCenter);

    /* comment count: speech bubble */
    CGRect bub = CGRectMake(w - 66, 49, 50, 22);
    {   /* one closed path: rounded body + tail, so fill and outline meet cleanly */
        CGFloat x0 = bub.origin.x + 0.5, y0 = bub.origin.y + 0.5, x1 = CGRectGetMaxX(bub) - 0.5, y1 = CGRectGetMaxY(bub) - 0.5, rr = 8;
        CGContextSaveGState(c);
        CGContextMoveToPoint(c, x0 + rr, y0);
        CGContextAddArcToPoint(c, x1, y0, x1, y1, rr);
        CGContextAddArcToPoint(c, x1, y1, x0, y1, rr);
        CGContextAddLineToPoint(c, x0 + 20, y1);
        CGContextAddLineToPoint(c, x0 + 11, y1 + 6);
        CGContextAddLineToPoint(c, x0 + 12, y1);
        CGContextAddArcToPoint(c, x0, y1, x0, y0, rr);
        CGContextAddArcToPoint(c, x0, y0, x1, y0, rr);
        CGContextClosePath(c);
        CGPathRef path = CGContextCopyPath(c);
        CGContextClip(c);
        HNFillGradient(c, CGRectMake(x0, y0, x1 - x0, y1 - y0 + 7), HNRGB(242, 238, 228), HNRGB(204, 198, 184));
        HNFillGradient(c, CGRectMake(x0, y0, x1 - x0, 10), [UIColor colorWithWhite:1 alpha:0.5], [UIColor colorWithWhite:1 alpha:0.05]);
        CGContextRestoreGState(c);
        CGContextAddPath(c, path); CGPathRelease(path);
        [HNRGB(160, 150, 132) setStroke]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
    }
    HNDrawText([NSString stringWithFormat:@"%ld", (long)s.comments], CGRectMake(bub.origin.x, bub.origin.y + 3, bub.size.width, 16),
               [UIFont fontWithName:@"HelveticaNeue-Bold" size:13], HNRGB(70, 58, 44), [UIColor colorWithWhite:1 alpha:0.8], 1, NSTextAlignmentCenter);
}
@end

@interface HNStoryCell : UITableViewCell
@property (nonatomic, strong) HNStoryView *card;
@end

@implementation HNStoryCell
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:style reuseIdentifier:rid])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.card = [[HNStoryView alloc] initWithFrame:self.contentView.bounds];
        [self.contentView addSubview:self.card];
        self.accessoryType = UITableViewCellAccessoryNone;
    }
    return self;
}
- (void)light:(BOOL)on { self.card.lit = on; [self.card setNeedsDisplay]; }
- (void)setHighlighted:(BOOL)h animated:(BOOL)a { [super setHighlighted:h animated:a]; [self light:h]; }
@end

@interface HNListController () <HNScreen>
@property (nonatomic) HNKind kind;
@property (nonatomic, strong) NSArray *stories;
@property (nonatomic, strong) NSArray *heights;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic) CGFloat heightsWidth;
@end

@implementation HNListController

- (NSString *)hnTitle { return self.title; }

- (id)initWithKind:(HNKind)kind {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        self.kind = kind;
        NSArray *titles = [NSArray arrayWithObjects:@"Hacker News", @"Ask HN", @"Show HN", @"Saved", nil];
        self.title = [titles objectAtIndex:kind];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [UIColor colorWithPatternImage:HNLinenImage()];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    if (self.kind != HNKindSaved) {
        self.refreshControl = [[UIRefreshControl alloc] init];
        self.refreshControl.tintColor = HNDarkOrange();
        [self.refreshControl addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    }

    self.status = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 90)];
    self.status.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.status.backgroundColor = [UIColor clearColor];
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.numberOfLines = 3;
    self.status.font = [UIFont fontWithName:@"Georgia-Italic" size:15];
    self.status.textColor = HNRGB(90, 76, 60);
    self.status.shadowColor = [UIColor colorWithWhite:1 alpha:0.8];
    self.status.shadowOffset = CGSizeMake(0, 1);
    self.status.text = @"Loading…";
    self.tableView.tableHeaderView = self.status;
    [self reload];
}

/* rows are measured at the table's width, which is only final after layout */
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.stories.count && fabs(self.tableView.bounds.size.width - self.heightsWidth) > 0.5) [self showStories:self.stories];
}

- (void)hnWillShow { if (self.kind == HNKindSaved && self.isViewLoaded) [self reload]; }

- (void)showStories:(NSArray *)stories {
    CGFloat w = self.tableView.bounds.size.width;
    NSMutableArray *hs = [NSMutableArray array];
    for (HNStory *s in stories) [hs addObject:[NSNumber numberWithFloat:(float)[HNStoryView heightForStory:s width:w]]];
    self.stories = stories;
    self.heights = hs;
    self.heightsWidth = w;
    self.status.text = self.kind == HNKindSaved ? @"Nothing saved yet.\nOpen a story and tap the star." : @"Nothing here yet.";
    self.tableView.tableHeaderView = stories.count ? nil : self.status;
    [self.tableView reloadData];
}

- (void)reload {
    if (self.kind == HNKindSaved) { [self showStories:[HNFavorites stories]]; return; }
    [HNAPI loadStories:self.kind done:^(NSArray *stories, NSString *err) {
        [self.refreshControl endRefreshing];
        if (err) {
            if (!self.stories.count) {
                self.status.text = [NSString stringWithFormat:@"Couldn't load stories.\n%@\nPull down to retry.", err];
                self.tableView.tableHeaderView = self.status;
            }
            return;
        }
        [self showStories:stories];
#ifdef HN_PREVIEW   /* simulator screenshots: open a story automatically */
        static BOOL opened;
        if (getenv("HN_OPEN") && !opened && stories.count && self.kind == (HNKind)atoi(getenv("HN_TAB") ?: "0")) {
            opened = YES;
            HNStoryController *sc = [[HNStoryController alloc] initWithStory:[stories objectAtIndex:atoi(getenv("HN_ROW") ?: "0")]];
            [[HNRootController shared] push:sc];
            [sc performSelector:@selector(previewPane:) withObject:[NSNumber numberWithInt:atoi(getenv("HN_OPEN"))] afterDelay:0.6];
        }
#endif
    }];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.stories.count; }

- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)ip {
    return [[self.heights objectAtIndex:ip.row] floatValue];
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    HNStoryCell *cell = [t dequeueReusableCellWithIdentifier:@"story"];
    if (!cell) cell = [[HNStoryCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"story"];
    cell.card.story = [self.stories objectAtIndex:ip.row];
    cell.card.rank = ip.row + 1;
    [cell.card setNeedsDisplay];
    return cell;
}

- (BOOL)tableView:(UITableView *)t canEditRowAtIndexPath:(NSIndexPath *)ip { return self.kind == HNKindSaved; }

- (void)tableView:(UITableView *)t commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)ip {
    if (style != UITableViewCellEditingStyleDelete) return;
    [HNFavorites remove:[[self.stories objectAtIndex:ip.row] sid]];
    NSMutableArray *s = [self.stories mutableCopy], *h = [self.heights mutableCopy];
    [s removeObjectAtIndex:ip.row]; [h removeObjectAtIndex:ip.row];
    self.stories = s; self.heights = h;
    [t deleteRowsAtIndexPaths:[NSArray arrayWithObject:ip] withRowAnimation:UITableViewRowAnimationFade];
    if (!s.count) { [self showStories:s]; }
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    [[HNRootController shared] push:[[HNStoryController alloc] initWithStory:[self.stories objectAtIndex:ip.row]]];
}

@end
