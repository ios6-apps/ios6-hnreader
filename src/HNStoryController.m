#import "HNStoryController.h"
#import "HNStyle.h"
#import "HNChrome.h"
#import "HNReaderMode.h"

#define INDENT 12
#define MAX_DEPTH 8

@interface HNCommentView : UIView
@property (nonatomic, strong) HNComment *item;
@property (nonatomic) BOOL lit;
+ (CGFloat)heightForItem:(HNComment *)c width:(CGFloat)w;
@end

@implementation HNCommentView

+ (UIFont *)bodyFont { return [UIFont fontWithName:@"HelveticaNeue" size:14]; }
+ (UIFont *)headFont { return [UIFont fontWithName:@"HelveticaNeue-Bold" size:12]; }
+ (UIFont *)titleFont { return [UIFont fontWithName:@"Georgia-Bold" size:18]; }

+ (CGRect)cardForItem:(HNComment *)c width:(CGFloat)w {
    CGFloat ind = c.isHeader ? 0 : MIN(c.depth, MAX_DEPTH) * INDENT;
    return CGRectMake(8 + ind, 4, w - 16 - ind, 0);
}

+ (CGFloat)heightForItem:(HNComment *)c width:(CGFloat)w {
    if (c.height > 0 && c.heightWidth == w) return c.height;
    CGFloat inner = [self cardForItem:c width:w].size.width - 26, h;
    if (c.isHeader) {
        h = 12 + HNTextHeight(c.story.title, [self titleFont], inner, 120) + 6 + 16 + 8;
        if (c.story.text.length) h += 8 + HNTextHeight(c.story.text, [self bodyFont], inner, 4000);
        h += 12 + 18 + 12 + 8;
    } else if (c.collapsed) {
        h = 40;
    } else {
        h = 8 + 17 + 4 + HNTextHeight(c.text, [self bodyFont], inner, 8000) + 12 + 8;
    }
    c.height = h; c.heightWidth = w;
    return h;
}

- (id)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (UIColor *)stripeColor {
    static NSArray *p;
    if (!p) p = [NSArray arrayWithObjects:HNRGB(224, 96, 16), HNRGB(46, 140, 150), HNRGB(120, 140, 40), HNRGB(140, 72, 150),
                 HNRGB(60, 110, 190), HNRGB(200, 70, 80), HNRGB(150, 120, 50), HNRGB(90, 90, 90), nil];
    return [p objectAtIndex:MIN(self.item.depth, MAX_DEPTH) % p.count];
}

- (void)drawRect:(CGRect)rect {
    HNComment *k = self.item;
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat w = self.bounds.size.width;
    CGRect card = [HNCommentView cardForItem:k width:w];
    card.size.height = self.bounds.size.height - 8;

    /* a paper card with a soft drop shadow */
    CGContextSaveGState(c);
    CGContextSetShadowWithColor(c, CGSizeMake(0, 1), 3, [UIColor colorWithWhite:0 alpha:0.45].CGColor);
    HNRoundRectPath(c, card, 5);
    [HNRGB(250, 247, 238) setFill];
    CGContextFillPath(c);
    CGContextRestoreGState(c);
    CGContextSaveGState(c);
    HNRoundRectPath(c, card, 5); CGContextClip(c);
    if (self.lit) HNFillGradient(c, card, HNRGB(255, 226, 190), HNRGB(250, 205, 160));
    else HNFillGradient(c, card, HNRGB(255, 253, 247), HNRGB(244, 239, 226));
    if (!k.isHeader) { [[self stripeColor] set]; CGContextFillRect(c, CGRectMake(card.origin.x, card.origin.y, 5, card.size.height)); }
    CGContextRestoreGState(c);
    HNRoundRectPath(c, CGRectInset(card, 0.5, 0.5), 4.5);
    [HNRGB(190, 180, 160) set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);

    CGFloat x = card.origin.x + 16, inner = card.size.width - 26, y = card.origin.y + 8;
    NSString *ago = HNTimeAgo(k.created);

    if (k.isHeader) {
        HNStory *s = k.story;
        y += 4;
        CGFloat th = HNTextHeight(s.title, [HNCommentView titleFont], inner, 120);
        HNDrawText(s.title, CGRectMake(x, y, inner, th), [HNCommentView titleFont], HNRGB(43, 33, 24), [UIColor whiteColor], 1, NSTextAlignmentLeft);
        y += th + 6;
        NSMutableArray *bits = [NSMutableArray array];
        if (s.domain) [bits addObject:s.domain];
        if (s.author) [bits addObject:[@"by " stringByAppendingString:s.author]];
        [bits addObject:HNTimeAgo(s.created)];
        HNDrawText([bits componentsJoinedByString:@"  ·  "], CGRectMake(x, y, inner, 16), [UIFont fontWithName:@"HelveticaNeue" size:12],
                   HNRGB(128, 112, 92), [UIColor whiteColor], 1, NSTextAlignmentLeft);
        y += 24;
        if (s.text.length) {
            CGFloat bh = HNTextHeight(s.text, [HNCommentView bodyFont], inner, 4000);
            HNDrawText(s.text, CGRectMake(x, y, inner, bh), [HNCommentView bodyFont], HNRGB(50, 40, 32), nil, 0, NSTextAlignmentLeft);
            y += bh + 8;
        }
        y += 4;
        [HNRGB(214, 206, 188) set]; CGContextFillRect(c, CGRectMake(x, y, inner, 1));
        [[UIColor whiteColor] set]; CGContextFillRect(c, CGRectMake(x, y + 1, inner, 1));
        y += 8;
        HNDrawText([NSString stringWithFormat:@"▲ %ld points     %ld comments", (long)s.points, (long)s.comments],
                   CGRectMake(x, y, inner, 18), [UIFont fontWithName:@"HelveticaNeue-Bold" size:13], HNDarkOrange(), [UIColor whiteColor], 1, NSTextAlignmentLeft);
        return;
    }

    NSString *head = [NSString stringWithFormat:@"%@  ·  %@", k.author, ago];
    HNDrawText(head, CGRectMake(x, y, inner, 16), [HNCommentView headFont], HNRGB(150, 64, 12), [UIColor whiteColor], 1, NSTextAlignmentLeft);
    if (k.collapsed) {
        HNDrawText([NSString stringWithFormat:@"▸ %ld hidden", (long)k.hidden + 1], CGRectMake(x, y, inner, 16), [HNCommentView headFont],
                   HNRGB(128, 112, 92), nil, 0, NSTextAlignmentRight);
        return;
    }
    CGFloat bh = HNTextHeight(k.text, [HNCommentView bodyFont], inner, 8000);
    HNDrawText(k.text, CGRectMake(x, y + 21, inner, bh), [HNCommentView bodyFont], HNRGB(50, 40, 32), nil, 0, NSTextAlignmentLeft);
}
@end

@interface HNCommentCell : UITableViewCell
@property (nonatomic, strong) HNCommentView *card;
@end

@implementation HNCommentCell
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:style reuseIdentifier:rid])) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.card = [[HNCommentView alloc] initWithFrame:self.contentView.bounds];
        [self.contentView addSubview:self.card];
    }
    return self;
}
- (void)light:(BOOL)on { self.card.lit = on; [self.card setNeedsDisplay]; }
- (void)setHighlighted:(BOOL)h animated:(BOOL)a { [super setHighlighted:h animated:a]; [self light:h]; }
@end

@interface HNStoryController () <UIWebViewDelegate, UITableViewDataSource, UITableViewDelegate, HNScreen>
@property (nonatomic, strong) HNStory *story;
@property (nonatomic, strong) HNSegmented *seg;
@property (nonatomic, strong) UIView *rightItem;
@property (nonatomic, strong) HNStarButton *star;
@property (nonatomic, strong) UIWebView *web;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) NSArray *all, *visible;
@property (nonatomic) BOOL hasArticle;
@end

@implementation HNStoryController

- (id)initWithStory:(HNStory *)story {
    if ((self = [super init])) {
        self.story = story;
        self.hasArticle = story.url.length > 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *v = self.view;
    v.backgroundColor = [UIColor colorWithPatternImage:HNLinenImage()];

    self.seg = [[HNSegmented alloc] initWithItems:[NSArray arrayWithObjects:@"Article", @"Comments", nil]];
    [self.seg addTarget:self action:@selector(switchPane) forControlEvents:UIControlEventValueChanged];

    self.web = [[UIWebView alloc] initWithFrame:v.bounds];
    self.web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.web.delegate = self;
    self.web.scalesPageToFit = YES;
    self.web.backgroundColor = HNRGB(236, 232, 222);

    self.table = [[UITableView alloc] initWithFrame:v.bounds style:UITableViewStylePlain];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.table.dataSource = self; self.table.delegate = self;
    self.table.backgroundColor = [UIColor colorWithPatternImage:HNLinenImage()];
    self.table.separatorStyle = UITableViewCellSeparatorStyleNone;

    self.status = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 70)];
    self.status.backgroundColor = [UIColor clearColor];
    self.status.textAlignment = NSTextAlignmentCenter;
    self.status.numberOfLines = 3;
    self.status.font = [UIFont fontWithName:@"Georgia-Italic" size:15];
    self.status.textColor = HNRGB(90, 76, 60);
    self.status.shadowColor = [UIColor colorWithWhite:1 alpha:0.8];
    self.status.shadowOffset = CGSizeMake(0, 1);

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [v addSubview:self.table];
    [v addSubview:self.web];

    HNComment *head = [[HNComment alloc] init];
    head.isHeader = YES; head.story = self.story;
    self.all = [NSArray arrayWithObject:head];
    self.visible = self.all;
    self.status.text = @"Loading comments…";
    self.table.tableFooterView = self.status;

    if (self.hasArticle) {
        self.seg.selectedIndex = 0;
        [self loadArticle];
    } else {
        [self.seg setEnabled:NO forIndex:0];
        self.seg.selectedIndex = 1;
    }
    self.star = [[HNStarButton alloc] initWithFrame:CGRectMake(0, 0, 34, 30)];
    self.star.on = [HNFavorites contains:self.story.sid];
    [self.star addTarget:self action:@selector(toggleStar) forControlEvents:UIControlEventTouchUpInside];
    [self rebuildRight:self.hasArticle ? [self actionButton] : nil];
    [self switchPane];

    [HNAPI loadItem:self.story.sid done:^(HNStory *s, NSArray *comments, NSString *err) {
        if (err) { self.status.text = [NSString stringWithFormat:@"Couldn't load comments.\n%@", err]; return; }
        if (s.title.length) {
            s.comments = self.story.comments ?: (NSInteger)comments.count;   /* the items endpoint has no comment count */
            head.story = s; head.height = 0;
        }
        NSMutableArray *a = [NSMutableArray arrayWithObject:head];
        [a addObjectsFromArray:comments];
        self.all = a;
        self.status.text = comments.count ? @"" : @"No comments yet.";
        self.table.tableFooterView = comments.count ? nil : self.status;
        [self recompute];
    }];
}

/* reader view first: fetch the page, keep the text and pictures; if there is no article in it, show the page as it is */
- (void)loadArticle {
    NSURL *url = [NSURL URLWithString:self.story.url];
    if (!url) { return; }
    [self webViewDidStartLoad:self.web];
    [HNReaderMode loadURL:url done:^(NSString *html, NSURL *base) {
        if (html) [self.web loadHTMLString:html baseURL:base];
        else [self.web loadRequest:[NSURLRequest requestWithURL:url]];
    }];
}

- (UIView *)actionButton {
    HNActionButton *b = [[HNActionButton alloc] initWithFrame:CGRectMake(0, 0, 34, 30)];
    [b addTarget:self action:@selector(openExternally) forControlEvents:UIControlEventTouchUpInside];
    return b;
}

/* nav bar right side: star, plus the Safari button (or the loading spinner) when there is an article */
- (void)rebuildRight:(UIView *)trailing {
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, trailing ? 72 : 34, 30)];
    [box addSubview:self.star];
    if (trailing) { trailing.frame = CGRectMake(38, 0, 34, 30); [box addSubview:trailing]; }
    self.rightItem = box;
}

- (void)toggleStar {
    self.star.on = [HNFavorites toggle:self.story];
}

- (UIView *)hnTitleView { return self.seg; }
- (UIView *)hnRightView { return self.rightItem; }

- (void)switchPane {
    BOOL art = self.hasArticle && self.seg.selectedIndex == 0;
    self.web.hidden = !art;
    self.table.hidden = art;
}

#ifdef HN_PREVIEW
- (void)previewPane:(NSNumber *)n { self.seg.selectedIndex = [n intValue]; [self switchPane]; }
#endif

- (void)openExternally {
    NSURL *u = self.web.request.URL ?: [NSURL URLWithString:self.story.url];
    if (u) [[UIApplication sharedApplication] openURL:u];
}

/* hide the replies of collapsed comments */
- (void)recompute {
    NSMutableArray *vis = [NSMutableArray array];
    NSInteger skip = -1;
    for (NSUInteger i = 0; i < self.all.count; i++) {
        HNComment *k = [self.all objectAtIndex:i];
        if (!k.isHeader && skip >= 0 && k.depth > skip) continue;
        skip = -1;
        [vis addObject:k];
        if (k.collapsed) {
            skip = k.depth;
            NSInteger n = 0;
            for (NSUInteger j = i + 1; j < self.all.count && [[self.all objectAtIndex:j] depth] > k.depth; j++) n++;
            k.hidden = n;
        }
    }
    self.visible = vis;
    [self.table reloadData];
}

#pragma mark web view

- (void)webViewDidStartLoad:(UIWebView *)w {
    [self.spinner startAnimating];
    self.spinner.frame = CGRectMake(0, 0, 34, 30);
    self.spinner.contentMode = UIViewContentModeCenter;
    [self rebuildRight:self.spinner];
    [[HNRootController shared] refreshBar];
}

- (void)webViewDidFinishLoad:(UIWebView *)w {
    [self.spinner stopAnimating];
    [self rebuildRight:[self actionButton]];
    [[HNRootController shared] refreshBar];
}

- (void)webView:(UIWebView *)w didFailLoadWithError:(NSError *)e {
    if ([e code] == NSURLErrorCancelled || [e code] == 102) return;
    [self webViewDidFinishLoad:w];
    NSString *html = [NSString stringWithFormat:@"<html><body style='font-family:Georgia;color:#5a4c3c;background:#ece8de;text-align:center;padding:60px 24px'>"
                      "<h2>Couldn't load the article</h2><p>%@</p><p>Use the action button to open it in Safari, or read the comments.</p></body></html>",
                      [e localizedDescription]];
    [w loadHTMLString:html baseURL:nil];
}

#pragma mark table

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return self.visible.count; }

- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)ip {
    return [HNCommentView heightForItem:[self.visible objectAtIndex:ip.row] width:t.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip {
    HNCommentCell *cell = [t dequeueReusableCellWithIdentifier:@"c"];
    if (!cell) cell = [[HNCommentCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"c"];
    cell.card.item = [self.visible objectAtIndex:ip.row];
    [cell.card setNeedsDisplay];
    return cell;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    HNComment *k = [self.visible objectAtIndex:ip.row];
    [t deselectRowAtIndexPath:ip animated:NO];
    if (k.isHeader) return;
    k.collapsed = !k.collapsed;
    k.height = 0;
    [self recompute];
}

@end
