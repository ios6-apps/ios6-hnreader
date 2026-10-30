#import <Foundation/Foundation.h>

/* Reader view: downloads an article, throws away scripts, styles, menus and ads, and returns just the text and pictures as simple
   HTML that iOS 6's UIWebView can show. Needs no JavaScript, so it works on pages whose scripts are far too new for this phone. */
@interface HNReaderMode : NSObject
/* done runs on the main thread; html is nil when the page could not be fetched or has no article text (show the page itself then) */
+ (void)loadURL:(NSURL *)url done:(void (^)(NSString *html, NSURL *baseURL))done;
/* the extraction alone, for pages already in memory */
+ (NSString *)readableHTMLFromHTML:(NSString *)html baseURL:(NSURL *)base;
@end
