#import <Foundation/Foundation.h>

/* Routes every https:// request of the app (the Algolia API, article pages and their images, scripts and styles) through the bundled
   TLS stack instead of iOS 6's own. Call +install once at launch. */
@interface HNSecureProtocol : NSURLProtocol
+ (void)install;
@end
