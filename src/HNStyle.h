#import <UIKit/UIKit.h>

/* Drawing helpers for the iOS 6 skeuomorphic look: linen, paper, glossy bars, embossed text. Everything is drawn in code, no image assets. */

UIColor *HNRGB(int r, int g, int b);
UIColor *HNOrange(void);
UIColor *HNDarkOrange(void);

UIImage *HNLinenImage(void);
UIImage *HNTabIcon(int kind);   /* 0 news, 1 ask, 2 show, 3 saved */
UIImage *HNLeatherImage(void);
void HNGlossRoundRect(CGContextRef c, CGRect r, CGFloat radius, UIColor *top, UIColor *bottom, UIColor *stroke);

void HNFillGradient(CGContextRef c, CGRect r, UIColor *top, UIColor *bottom);
void HNRoundRectPath(CGContextRef c, CGRect r, CGFloat radius);
void HNDrawText(NSString *s, CGRect r, UIFont *font, UIColor *color, UIColor *shadow, CGFloat shadowDY, NSTextAlignment align);
CGFloat HNTextHeight(NSString *s, UIFont *font, CGFloat width, CGFloat maxHeight);

NSString *HNTimeAgo(NSTimeInterval t);
NSString *HNPlainText(NSString *html);
