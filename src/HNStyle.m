#import "HNStyle.h"

UIColor *HNRGB(int r, int g, int b) { return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1]; }
UIColor *HNOrange(void) { return HNRGB(224, 96, 16); }
UIColor *HNDarkOrange(void) { return HNRGB(176, 62, 0); }

static void rgba(UIColor *c, CGFloat *out) {
    if (![c getRed:out green:out + 1 blue:out + 2 alpha:out + 3]) {
        CGFloat w, a;
        [c getWhite:&w alpha:&a];
        out[0] = out[1] = out[2] = w; out[3] = a;
    }
}

void HNFillGradient(CGContextRef c, CGRect r, UIColor *top, UIColor *bottom) {
    CGFloat comps[8];
    rgba(top, comps); rgba(bottom, comps + 4);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, comps, NULL, 2);
    CGContextSaveGState(c);
    CGContextClipToRect(c, r);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, CGRectGetMinY(r)), CGPointMake(0, CGRectGetMaxY(r)), 0);
    CGContextRestoreGState(c);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
}

void HNRoundRectPath(CGContextRef c, CGRect r, CGFloat rad) {
    CGFloat x0 = CGRectGetMinX(r), x1 = CGRectGetMaxX(r), y0 = CGRectGetMinY(r), y1 = CGRectGetMaxY(r);
    CGContextMoveToPoint(c, x0 + rad, y0);
    CGContextAddArcToPoint(c, x1, y0, x1, y1, rad);
    CGContextAddArcToPoint(c, x1, y1, x0, y1, rad);
    CGContextAddArcToPoint(c, x0, y1, x0, y0, rad);
    CGContextAddArcToPoint(c, x0, y0, x1, y0, rad);
    CGContextClosePath(c);
}

void HNDrawText(NSString *s, CGRect r, UIFont *font, UIColor *color, UIColor *shadow, CGFloat dy, NSTextAlignment align) {
    if (!s.length) return;
    /* a one-line box truncates instead of wrapping */
    NSLineBreakMode mode = r.size.height < font.lineHeight * 1.5 ? NSLineBreakByTruncatingTail : NSLineBreakByWordWrapping;
    if (shadow) {
        [shadow set];
        [s drawInRect:CGRectOffset(r, 0, dy) withFont:font lineBreakMode:mode alignment:align];
    }
    [color set];
    [s drawInRect:r withFont:font lineBreakMode:mode alignment:align];
}

CGFloat HNTextHeight(NSString *s, UIFont *font, CGFloat width, CGFloat maxHeight) {
    if (!s.length) return 0;
    CGSize sz = [s sizeWithFont:font constrainedToSize:CGSizeMake(width, maxHeight) lineBreakMode:NSLineBreakByWordWrapping];
    return ceil(sz.height);
}

UIImage *HNLinenImage(void) {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(64, 64), YES, 0);
        CGContextRef c = UIGraphicsGetCurrentContext();
        [HNRGB(178, 173, 163) setFill];
        CGContextFillRect(c, CGRectMake(0, 0, 64, 64));
        srand(7);
        for (int y = 0; y < 64; y += 2) {
            CGContextSetRGBFillColor(c, 1, 1, 1, 0.08 + (rand() % 16) / 100.0);
            CGContextFillRect(c, CGRectMake(0, y, 64, 1));
        }
        for (int x = 0; x < 64; x += 2) {
            CGContextSetRGBFillColor(c, 0.15, 0.12, 0.1, 0.06 + (rand() % 12) / 100.0);
            CGContextFillRect(c, CGRectMake(x, 0, 1, 64));
        }
        for (int i = 0; i < 140; i++) {
            CGContextSetRGBFillColor(c, 0.25, 0.22, 0.2, 0.06);
            CGContextFillRect(c, CGRectMake(rand() % 64, rand() % 64, 1, 1));
        }
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

UIImage *HNTabIcon(int kind) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    [[UIColor blackColor] set];
    if (kind == 0) {            /* newspaper */
        HNRoundRectPath(c, CGRectMake(4, 5, 22, 20), 2.5);
        CGContextSetLineWidth(c, 2);
        CGContextStrokePath(c);
        CGContextFillRect(c, CGRectMake(8, 9, 8, 6));
        CGContextFillRect(c, CGRectMake(18, 9, 5, 2));
        CGContextFillRect(c, CGRectMake(18, 13, 5, 2));
        CGContextFillRect(c, CGRectMake(8, 18, 15, 2));
    } else if (kind == 1) {     /* question mark */
        UIFont *f = [UIFont fontWithName:@"Georgia-Bold" size:28];
        [@"?" drawInRect:CGRectMake(0, 0, 30, 32) withFont:f lineBreakMode:NSLineBreakByClipping alignment:NSTextAlignmentCenter];
    } else if (kind == 3) {     /* star */
        for (int i = 0; i < 10; i++) {
            CGFloat a = -M_PI / 2 + i * M_PI / 5, rad = (i % 2) ? 5.8 : 13;
            CGPoint pt = CGPointMake(15 + cos(a) * rad, 16 + sin(a) * rad);
            if (i == 0) CGContextMoveToPoint(c, pt.x, pt.y); else CGContextAddLineToPoint(c, pt.x, pt.y);
        }
        CGContextClosePath(c);
        CGContextSetLineWidth(c, 2); CGContextSetLineJoin(c, kCGLineJoinRound);
        CGContextStrokePath(c);
    } else {                    /* eye */
        CGContextSetLineWidth(c, 2);
        CGContextStrokeEllipseInRect(c, CGRectMake(3, 8, 24, 14));
        CGContextFillEllipseInRect(c, CGRectMake(11, 10, 8, 10));
    }
    UIImage *i = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return i;
}

UIImage *HNLeatherImage(void) {
    static UIImage *img;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(64, 64), YES, 0);
        CGContextRef c = UIGraphicsGetCurrentContext();
        [HNRGB(66, 44, 32) setFill];
        CGContextFillRect(c, CGRectMake(0, 0, 64, 64));
        srand(11);
        for (int i = 0; i < 520; i++) {          /* pebbled grain: small dark dimples with a light rim */
            CGFloat x = rand() % 64, y = rand() % 64, r = 0.8 + (rand() % 10) / 10.0;
            CGContextSetRGBFillColor(c, 0.1, 0.05, 0.02, 0.28);
            CGContextFillEllipseInRect(c, CGRectMake(x, y, r, r));
            CGContextSetRGBFillColor(c, 1, 0.85, 0.7, 0.07);
            CGContextFillEllipseInRect(c, CGRectMake(x - 0.6, y - 0.6, r, r));
        }
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

void HNGlossRoundRect(CGContextRef c, CGRect r, CGFloat rad, UIColor *top, UIColor *bot, UIColor *stroke) {
    CGContextSaveGState(c);
    HNRoundRectPath(c, r, rad); CGContextClip(c);
    HNFillGradient(c, r, top, bot);
    HNFillGradient(c, CGRectMake(r.origin.x, r.origin.y, r.size.width, r.size.height / 2), [UIColor colorWithWhite:1 alpha:0.30], [UIColor colorWithWhite:1 alpha:0.04]);
    CGContextRestoreGState(c);
    HNRoundRectPath(c, CGRectInset(r, 0.5, 0.5), rad);
    [stroke set]; CGContextSetLineWidth(c, 1); CGContextStrokePath(c);
}

NSString *HNTimeAgo(NSTimeInterval t) {
    long d = (long)([[NSDate date] timeIntervalSince1970] - t);
    if (d < 60) return @"just now";
    if (d < 3600) return [NSString stringWithFormat:@"%ldm", d / 60];
    if (d < 86400) return [NSString stringWithFormat:@"%ldh", d / 3600];
    if (d < 86400 * 60) return [NSString stringWithFormat:@"%ldd", d / 86400];
    return [NSString stringWithFormat:@"%ldmo", d / (86400 * 30)];
}

static void appendCode(NSMutableString *s, unsigned code) {
    NSString *e = [[NSString alloc] initWithBytes:&code length:4 encoding:NSUTF32LittleEndianStringEncoding];
    if (e) [s appendString:e];
}

NSString *HNPlainText(NSString *html) {
    if (![html isKindOfClass:[NSString class]] || !html.length) return @"";
    NSMutableString *s = [NSMutableString stringWithCapacity:html.length];
    NSUInteger i = 0, n = html.length;
    while (i < n) {
        unichar ch = [html characterAtIndex:i];
        if (ch == '<') {
            NSRange r = [html rangeOfString:@">" options:0 range:NSMakeRange(i, n - i)];
            if (r.location == NSNotFound) break;
            NSString *tag = [[html substringWithRange:NSMakeRange(i + 1, r.location - i - 1)] lowercaseString];
            if ([tag isEqualToString:@"p"] || [tag hasPrefix:@"p "]) [s appendString:@"\n\n"];
            else if ([tag hasPrefix:@"br"] || [tag hasPrefix:@"pre"] || [tag isEqualToString:@"/pre"]) [s appendString:@"\n"];
            i = r.location + 1;
            continue;
        }
        if (ch == '&') {
            NSRange r = [html rangeOfString:@";" options:0 range:NSMakeRange(i, MIN((NSUInteger)10, n - i))];
            if (r.location != NSNotFound) {
                NSString *name = [html substringWithRange:NSMakeRange(i + 1, r.location - i - 1)];
                if ([name isEqualToString:@"amp"]) [s appendString:@"&"];
                else if ([name isEqualToString:@"lt"]) [s appendString:@"<"];
                else if ([name isEqualToString:@"gt"]) [s appendString:@">"];
                else if ([name isEqualToString:@"quot"]) [s appendString:@"\""];
                else if ([name isEqualToString:@"apos"]) [s appendString:@"'"];
                else if ([name isEqualToString:@"nbsp"]) [s appendString:@" "];
                else if ([name hasPrefix:@"#x"] || [name hasPrefix:@"#X"]) {
                    unsigned v = 0; [[NSScanner scannerWithString:[name substringFromIndex:2]] scanHexInt:&v]; appendCode(s, v);
                } else if ([name hasPrefix:@"#"]) appendCode(s, (unsigned)[[name substringFromIndex:1] intValue]);
                else { [s appendString:[html substringWithRange:NSMakeRange(i, r.location - i + 1)]]; }
                i = r.location + 1;
                continue;
            }
        }
        [s appendFormat:@"%C", ch];
        i++;
    }
    NSString *t = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([t rangeOfString:@"\n\n\n"].location != NSNotFound) t = [t stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
    return t;
}
