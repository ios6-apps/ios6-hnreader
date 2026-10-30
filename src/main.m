#import <UIKit/UIKit.h>
#import "HNChrome.h"
#import "HNSecureProtocol.h"

@interface HNAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation HNAppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    [HNSecureProtocol install];
    [app setStatusBarStyle:UIStatusBarStyleBlackOpaque];
#ifdef HN_PREVIEW
    if (getenv("HN_SAVE")) {   /* simulator screenshots: seed the Saved tab */
        NSMutableArray *a = [NSMutableArray array];
        NSArray *t = [NSArray arrayWithObjects:@"Show HN: A tiny Lisp that fits in a QR code", @"Why the Amiga still matters", @"Ask HN: What are you reading this winter?", nil];
        for (NSUInteger i = 0; i < t.count; i++)
            [a addObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%lu", (unsigned long)(100 + i)], @"objectID", [t objectAtIndex:i], @"title",
                          i == 2 ? @"" : @"https://example.com/post", @"url", @"pg", @"author", [NSNumber numberWithInt:240 - 70 * (int)i], @"points",
                          [NSNumber numberWithInt:90 - 30 * (int)i], @"num_comments", [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970] - 7200 * (i + 1)], @"created_at_i", nil]];
        [[NSUserDefaults standardUserDefaults] setObject:a forKey:@"hn.saved"];
    }
#endif
#ifdef HN_PREVIEW
    if (getenv("HN_TLSTEST")) {   /* simulator: fetch a few sites through the bundled TLS and log the outcome */
        NSArray *urls = [NSArray arrayWithObjects:@"https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=1", @"https://lwn.net/", @"https://www.wired.com/", @"https://gizmodo.com/", @"https://www.apple.com/", @"https://discord.com/", @"https://en.wikipedia.org/wiki/Main_Page", @"https://github.com/", @"https://expired.badssl.com/", @"https://self-signed.badssl.com/", @"http://example.com/", @"https://www.google.com/", nil];
        for (NSString *u in urls) {
            NSURLRequest *rq = [NSURLRequest requestWithURL:[NSURL URLWithString:u] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:25];
            [NSURLConnection sendAsynchronousRequest:rq queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
                NSString *line = e ? [NSString stringWithFormat:@"%@ ERR %ld %@", u, (long)e.code, e.localizedDescription]
                                   : [NSString stringWithFormat:@"%@ %ld %lu bytes final=%@", u, (long)[(NSHTTPURLResponse *)r statusCode], (unsigned long)d.length, r.URL];
                FILE *f = fopen("/tmp/hn_tls.log", "a"); if (f) { fprintf(f, "%s\n", [line UTF8String]); fclose(f); }
            }];
        }
    }
#endif
    HNRootController *root = [[HNRootController alloc] init];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
#ifdef HN_PREVIEW
    if (getenv("HN_TAB")) [root selectTab:atoi(getenv("HN_TAB"))];
#endif
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([HNAppDelegate class]));
    }
}
