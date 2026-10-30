/* Native macOS test of the reader-view extraction (HNReaderMode needs only Foundation). Run through tests/run.sh. */
#import <Foundation/Foundation.h>
#import "HNReaderMode.h"

static int fails = 0;
#define CHECK(cond, ...) do { if (!(cond)) { fails++; NSLog(@"FAIL: " __VA_ARGS__); } } while (0)

static NSString *para(int n) {
    NSMutableString *s = [NSMutableString string];
    for (int i = 0; i < n; i++) [s appendString:@"The quick brown fox jumps over the lazy dog, again and again. "];
    return s;
}

int main(void) {
    @autoreleasepool {
        NSURL *base = [NSURL URLWithString:@"https://example.com/posts/hello/"];

        NSString *page = [NSString stringWithFormat:
            @"<html><head><title>Hello &amp; welcome</title><meta property=\"og:site_name\" content=\"Example Blog\">"
            "<script>var tracker = 'SCRIPT_MARKER';</script><style>.x{color:red}</style></head><body>"
            "<nav><a href=\"/\">Home</a> <a href=\"/about\">About</a> NAV_MARKER</nav>"
            "<div class=\"cookie-banner\">COOKIE_MARKER accept all the things please</div>"
            "<article><h1>Hello &amp; welcome</h1>"
            "<p>%@</p><p>Caf&eacute; &#8212; &#x263A; and a <a href=\"../next\">relative link</a>.</p>"
            "<img src=\"/img/photo.jpg\"><img src=\"/img/tracking-pixel.gif\" width=\"1\" height=\"1\">"
            "<p>%@</p></article>"
            "<div class=\"sidebar\">SIDEBAR_MARKER related posts and other things nobody wants</div>"
            "<footer>FOOTER_MARKER</footer></body></html>", para(4), para(4)];
        NSString *out = [HNReaderMode readableHTMLFromHTML:page baseURL:base];

        CHECK(out != nil, @"article page produced no output");
        if (out) {
            CHECK([out rangeOfString:@"quick brown fox"].location != NSNotFound, @"article text is missing");
            for (NSString *junk in @[@"SCRIPT_MARKER", @"NAV_MARKER", @"COOKIE_MARKER", @"SIDEBAR_MARKER", @"FOOTER_MARKER"])
                CHECK([out rangeOfString:junk].location == NSNotFound, @"%@ leaked into the reader view", junk);
            CHECK([out rangeOfString:@"<h1 class=\"t\">Hello &amp; welcome</h1>"].location != NSNotFound, @"title missing or not escaped");
            CHECK([out rangeOfString:@"Example Blog"].location != NSNotFound, @"og:site_name missing");
            CHECK([out rangeOfString:@"Café — ☺"].location != NSNotFound, @"entities not decoded");
            CHECK([out rangeOfString:@"href=\"https://example.com/posts/next\""].location != NSNotFound, @"relative link not made absolute");
            CHECK([out rangeOfString:@"src=\"https://example.com/img/photo.jpg\""].location != NSNotFound, @"relative image not made absolute");
            CHECK([out rangeOfString:@"tracking-pixel"].location == NSNotFound, @"tracking pixel kept");
            NSRange h1 = [out rangeOfString:@"<h1>"];
            CHECK(h1.location == NSNotFound, @"duplicate headline kept in the body");
            CHECK([out rangeOfString:@"Open the original page"].location != NSNotFound, @"footer link missing");
        }

        /* a page with no article text falls back to nil, so the app shows the page itself */
        CHECK([HNReaderMode readableHTMLFromHTML:@"<html><body><p>Too short.</p></body></html>" baseURL:base] == nil, @"short page should give nil");
        CHECK([HNReaderMode readableHTMLFromHTML:@"<html><body><ul><li><a href=\"/a\">One</a></li><li><a href=\"/b\">Two</a></li></ul></body></html>" baseURL:base] == nil, @"link list should give nil");

        /* script bodies containing markup must not derail the parser */
        NSString *tricky = [NSString stringWithFormat:@"<html><body><script>document.write('<p>SCRIPT_P</p>');</script><div id=\"content\"><p>%@</p><p>%@</p></div></body></html>", para(4), para(3)];
        NSString *o2 = [HNReaderMode readableHTMLFromHTML:tricky baseURL:base];
        CHECK(o2 && [o2 rangeOfString:@"SCRIPT_P"].location == NSNotFound && [o2 rangeOfString:@"lazy dog"].location != NSNotFound, @"script with markup handled wrongly");
    }
    NSLog(fails ? @"%d FAILED" : @"ALL OK", fails);
    return fails ? 1 : 0;
}
