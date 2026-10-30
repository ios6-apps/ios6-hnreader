#import "HNReaderMode.h"

/* ---------- a forgiving little HTML parser ---------- */

@interface HNNode : NSObject
@property (nonatomic, copy) NSString *tag;          /* nil for text */
@property (nonatomic, copy) NSString *text;
@property (nonatomic, strong) NSMutableDictionary *attrs;
@property (nonatomic, strong) NSMutableArray *kids;
@property (nonatomic, weak) HNNode *parent;
@property (nonatomic) double score;
@property (nonatomic) NSInteger textLen, linkLen;
@end
@implementation HNNode
- (NSString *)attr:(NSString *)n { return [self.attrs objectForKey:n]; }
@end

static NSSet *SetOf(NSString *words) { return [NSSet setWithArray:[words componentsSeparatedByString:@" "]]; }

static NSString *DecodeEntities(NSString *s) {
    if ([s rangeOfString:@"&"].location == NSNotFound) return s;
    static NSDictionary *named;
    if (!named) named = [NSDictionary dictionaryWithObjectsAndKeys:
        @"&", @"amp", @"<", @"lt", @">", @"gt", @"\"", @"quot", @"'", @"apos", @" ", @"nbsp", @"—", @"mdash", @"–", @"ndash",
        @"…", @"hellip", @"‘", @"lsquo", @"’", @"rsquo", @"“", @"ldquo", @"”", @"rdquo", @"©", @"copy",
        @"®", @"reg", @"™", @"trade", @"·", @"middot", @"•", @"bull", @"«", @"laquo", @"»", @"raquo",
        @"é", @"eacute", @"è", @"egrave", @"ü", @"uuml", @"ö", @"ouml", @"ä", @"auml", @"ß", @"szlig",
        @"°", @"deg", @"×", @"times", @"→", @"rarr", @"←", @"larr", @"€", @"euro", @"£", @"pound", nil];
    NSMutableString *out = [NSMutableString stringWithCapacity:s.length];
    NSUInteger i = 0, n = s.length;
    while (i < n) {
        unichar ch = [s characterAtIndex:i];
        if (ch == '&') {
            NSRange semi = [s rangeOfString:@";" options:0 range:NSMakeRange(i, MIN((NSUInteger)10, n - i))];
            if (semi.location != NSNotFound) {
                NSString *name = [s substringWithRange:NSMakeRange(i + 1, semi.location - i - 1)];
                NSString *rep = nil;
                if ([name hasPrefix:@"#"]) {
                    unsigned long code = [name hasPrefix:@"#x"] || [name hasPrefix:@"#X"] ? strtoul([[name substringFromIndex:2] UTF8String], NULL, 16)
                                                                                           : strtoul([[name substringFromIndex:1] UTF8String], NULL, 10);
                    if (code > 0 && code < 0x10000) rep = [NSString stringWithFormat:@"%C", (unichar)code];
                    else if (code >= 0x10000 && code < 0x110000) { unsigned long c = code - 0x10000; rep = [NSString stringWithFormat:@"%C%C", (unichar)(0xD800 + (c >> 10)), (unichar)(0xDC00 + (c & 0x3FF))]; }
                } else rep = [named objectForKey:name];
                if (rep) { [out appendString:rep]; i = semi.location + 1; continue; }
            }
        }
        [out appendFormat:@"%C", ch];
        i++;
    }
    return out;
}

static HNNode *Parse(NSString *html) {
    static NSSet *voidTags, *closesP, *selfClosing;
    if (!voidTags) {
        voidTags = SetOf(@"area base br col embed hr img input link meta param source track wbr");
        closesP = SetOf(@"div ul ol h1 h2 h3 h4 h5 h6 blockquote pre table section article aside header footer nav form p figure hr dl");
        selfClosing = SetOf(@"p li dt dd tr td th option");
    }
    const char *s = [html UTF8String];
    if (!s) return nil;
    size_t n = strlen(s), i = 0;
    HNNode *root = [[HNNode alloc] init];
    root.tag = @"#root"; root.kids = [NSMutableArray array]; root.attrs = [NSMutableDictionary dictionary];
    NSMutableArray *stack = [NSMutableArray arrayWithObject:root];

    while (i < n) {
        if (s[i] != '<') {
            size_t j = i;
            while (j < n && s[j] != '<') j++;
            NSString *t = [[NSString alloc] initWithBytes:s + i length:j - i encoding:NSUTF8StringEncoding];
            if (t.length) {
                HNNode *top = [stack lastObject];
                HNNode *tn = [[HNNode alloc] init];
                tn.text = DecodeEntities(t); tn.parent = top;
                [top.kids addObject:tn];
            }
            i = j;
            continue;
        }
        if (i + 3 < n && !strncmp(s + i, "<!--", 4)) {
            const char *e = strstr(s + i + 4, "-->");
            i = e ? (size_t)(e - s) + 3 : n;
            continue;
        }
        if (i + 1 < n && (s[i + 1] == '!' || s[i + 1] == '?')) {
            const char *e = memchr(s + i, '>', n - i);
            i = e ? (size_t)(e - s) + 1 : n;
            continue;
        }
        BOOL closing = i + 1 < n && s[i + 1] == '/';
        size_t j = i + (closing ? 2 : 1);
        size_t ns = j;
        while (j < n && (isalnum((unsigned char)s[j]) || s[j] == '-' || s[j] == ':' || s[j] == '_')) j++;
        if (j == ns) {   /* a stray '<' */
            HNNode *top = [stack lastObject];
            HNNode *tn = [[HNNode alloc] init]; tn.text = @"<"; tn.parent = top; [top.kids addObject:tn];
            i++;
            continue;
        }
        NSString *name = [[[NSString alloc] initWithBytes:s + ns length:j - ns encoding:NSUTF8StringEncoding] lowercaseString];
        if (closing) {
            const char *e = memchr(s + j, '>', n - j);
            i = e ? (size_t)(e - s) + 1 : n;
            for (NSInteger k = (NSInteger)stack.count - 1; k >= 1; k--)
                if ([[[stack objectAtIndex:(NSUInteger)k] tag] isEqualToString:name]) { [stack removeObjectsInRange:NSMakeRange((NSUInteger)k, stack.count - (NSUInteger)k)]; break; }
            continue;
        }
        NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
        BOOL selfClose = NO;
        while (j < n && s[j] != '>') {
            while (j < n && isspace((unsigned char)s[j])) j++;
            if (j >= n || s[j] == '>') break;
            if (s[j] == '/') { selfClose = YES; j++; continue; }
            size_t as = j;
            while (j < n && !isspace((unsigned char)s[j]) && s[j] != '=' && s[j] != '>' && s[j] != '/') j++;
            NSString *an = [[[NSString alloc] initWithBytes:s + as length:j - as encoding:NSUTF8StringEncoding] lowercaseString];
            while (j < n && isspace((unsigned char)s[j])) j++;
            NSString *av = @"";
            if (j < n && s[j] == '=') {
                j++;
                while (j < n && isspace((unsigned char)s[j])) j++;
                if (j < n && (s[j] == '"' || s[j] == '\'')) {
                    char q = s[j++]; size_t vs = j;
                    while (j < n && s[j] != q) j++;
                    av = [[NSString alloc] initWithBytes:s + vs length:j - vs encoding:NSUTF8StringEncoding] ?: @"";
                    if (j < n) j++;
                } else {
                    size_t vs = j;
                    while (j < n && !isspace((unsigned char)s[j]) && s[j] != '>') j++;
                    av = [[NSString alloc] initWithBytes:s + vs length:j - vs encoding:NSUTF8StringEncoding] ?: @"";
                }
            }
            if (an.length) [attrs setObject:DecodeEntities(av) forKey:an];
        }
        i = j < n ? j + 1 : n;

        if ([name isEqualToString:@"script"] || [name isEqualToString:@"style"]) {   /* raw text: skip to the closing tag */
            NSString *endTag = [NSString stringWithFormat:@"</%@", name];
            const char *e = strcasestr(s + i, [endTag UTF8String]);
            if (!e) { i = n; continue; }
            const char *g = memchr(e, '>', n - (size_t)(e - s));
            i = g ? (size_t)(g - s) + 1 : n;
            continue;
        }

        HNNode *top = [stack lastObject];
        if ([closesP containsObject:name] && [top.tag isEqualToString:@"p"] && stack.count > 1) { [stack removeLastObject]; top = [stack lastObject]; }
        else if ([selfClosing containsObject:name] && [top.tag isEqualToString:name] && stack.count > 1) { [stack removeLastObject]; top = [stack lastObject]; }
        HNNode *node = [[HNNode alloc] init];
        node.tag = name; node.attrs = attrs; node.kids = [NSMutableArray array]; node.parent = top;
        [top.kids addObject:node];
        if (!selfClose && ![voidTags containsObject:name] && stack.count < 400) [stack addObject:node];
    }
    return root;
}

/* ---------- finding the article ---------- */

static NSSet *DropTags(void) { static NSSet *s; if (!s) s = SetOf(@"script style noscript template svg iframe form nav aside footer button select input textarea canvas video audio object embed head link meta"); return s; }

static BOOL Matches(NSString *haystack, NSString *pattern) {
    if (!haystack.length) return NO;
    return [haystack rangeOfString:pattern options:NSRegularExpressionSearch | NSCaseInsensitiveSearch].location != NSNotFound;
}

static NSString *IdClass(HNNode *n) { return [NSString stringWithFormat:@"%@ %@", [n attr:@"class"] ?: @"", [n attr:@"id"] ?: @""]; }

static BOOL Junk(HNNode *n) {
    if (!n.tag) return NO;
    if ([DropTags() containsObject:n.tag]) return YES;
    if ([n attr:@"hidden"] || [[n attr:@"aria-hidden"] isEqualToString:@"true"]) return YES;
    NSString *style = [n attr:@"style"];
    if (style && Matches(style, @"display:\\s*none")) return YES;
    if ([n.tag isEqualToString:@"body"] || [n.tag isEqualToString:@"html"] || [n.tag isEqualToString:@"article"] || [n.tag isEqualToString:@"main"]) return NO;
    return Matches(IdClass(n), @"(^|[^a-z])(comment|comments|disqus|sidebar|share|sharing|social|promo|newsletter|subscribe|related|advert|ad-|ads|banner|popup|modal|cookie|breadcrumb|menu|toolbar|sponsor|outbrain|taboola|paywall|signup|skip-link|screen-reader)([^a-z]|$)");
}

static NSString *PlainText(HNNode *n) {
    if (!n.tag) return n.text ?: @"";
    if (Junk(n)) return @"";
    NSMutableString *m = [NSMutableString string];
    for (HNNode *k in n.kids) [m appendString:PlainText(k)];
    return m;
}

static void Measure(HNNode *n, BOOL inLink) {
    if (!n.tag) { NSInteger l = (NSInteger)[[n.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length]; n.textLen = l; n.linkLen = inLink ? l : 0; return; }
    if (Junk(n)) { n.textLen = n.linkLen = 0; return; }
    BOOL link = inLink || [n.tag isEqualToString:@"a"];
    NSInteger t = 0, l = 0;
    for (HNNode *k in n.kids) { Measure(k, link); t += k.textLen; l += k.linkLen; }
    n.textLen = t; n.linkLen = l;
}

static void Collect(HNNode *n, NSMutableArray *cands) {
    if (!n.tag || Junk(n)) return;
    if ([n.tag isEqualToString:@"p"] || [n.tag isEqualToString:@"pre"] || [n.tag isEqualToString:@"blockquote"]) {
        if (n.textLen >= 25 && n.parent) {
            NSString *t = PlainText(n);
            double sc = 1 + [[t componentsSeparatedByString:@","] count] - 1 + MIN((double)n.textLen / 100.0, 3);
            sc *= 1.0 - (double)n.linkLen / MAX((double)n.textLen, 1);
            n.parent.score += sc;
            if (n.parent.parent) n.parent.parent.score += sc / 2;
            if (![cands containsObject:n.parent]) [cands addObject:n.parent];
            if (n.parent.parent && ![cands containsObject:n.parent.parent]) [cands addObject:n.parent.parent];
        }
        return;
    }
    for (HNNode *k in n.kids) Collect(k, cands);
}

static HNNode *Find(HNNode *n, NSString *tag) {
    if (n.tag && [n.tag isEqualToString:tag]) return n;
    for (HNNode *k in n.kids) { HNNode *r = Find(k, tag); if (r) return r; }
    return nil;
}

static NSString *Meta(HNNode *root, NSString *prop) {
    __block NSString *found = nil;
    __block void (^walk)(HNNode *) = ^(HNNode *n) {
        if (found) return;
        if ([n.tag isEqualToString:@"meta"] && ([[n attr:@"property"] isEqualToString:prop] || [[n attr:@"name"] isEqualToString:prop])) found = [n attr:@"content"];
        for (HNNode *k in n.kids) walk(k);
    };
    walk(root);
    walk = nil;
    return found;
}

/* ---------- writing it back out ---------- */

static NSString *Escape(NSString *s) {
    s = [s stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
    s = [s stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
    s = [s stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
    return s;
}

static NSString *Absolute(NSString *u, NSURL *base) {
    u = [u stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!u.length || [u hasPrefix:@"data:"] || [u hasPrefix:@"javascript:"]) return nil;
    NSURL *r = [NSURL URLWithString:u relativeToURL:base];
    if (!r) r = [NSURL URLWithString:[u stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] relativeToURL:base];
    return [[r absoluteURL] absoluteString];
}

static NSString *ImageURL(HNNode *n, NSURL *base) {
    NSString *src = nil;
    for (NSString *k in [NSArray arrayWithObjects:@"data-src", @"data-lazy-src", @"data-original", @"src", nil]) {
        NSString *v = [n attr:k];
        if (v.length && ![v hasPrefix:@"data:"]) { src = v; break; }
    }
    if (!src) {
        NSString *ss = [n attr:@"srcset"] ?: [n attr:@"data-srcset"];
        if (ss.length) src = [[[[ss componentsSeparatedByString:@","] objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] componentsSeparatedByString:@" "].firstObject;
    }
    if (!src.length) return nil;
    if ([n attr:@"width"] && [[n attr:@"width"] intValue] > 0 && [[n attr:@"width"] intValue] < 60) return nil;
    if ([n attr:@"height"] && [[n attr:@"height"] intValue] > 0 && [[n attr:@"height"] intValue] < 60) return nil;
    if (Matches(src, @"(pixel|spacer|tracking|1x1|blank\\.|sprite|/icons?/|avatar|emoji|\\.svg|\\.gif\\?)")) return nil;
    return Absolute(src, base);
}

static NSSet *BlockTags(void) { static NSSet *s; if (!s) s = SetOf(@"p h1 h2 h3 h4 h5 h6 ul ol li blockquote pre figure figcaption hr table tr div section article main dl dt dd header address"); return s; }
static NSSet *InlineKeep(void) { static NSSet *s; if (!s) s = SetOf(@"em i strong b code sub sup mark u small cite q kbd s del ins"); return s; }

static void Render(HNNode *n, NSURL *base, NSMutableString *out, NSInteger depth);

static BOOL HasBlockKid(HNNode *n) {
    for (HNNode *k in n.kids) if (k.tag && !Junk(k) && ([BlockTags() containsObject:k.tag] || HasBlockKid(k))) return YES;
    return NO;
}

static void Inline(HNNode *n, NSURL *base, NSMutableString *out) {
    if (!n.tag) {
        NSString *t = Escape(n.text ?: @"");
        t = [t stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        t = [t stringByReplacingOccurrencesOfString:@"\t" withString:@" "];
        [out appendString:t];
        return;
    }
    if (Junk(n)) return;
    if ([n.tag isEqualToString:@"br"]) { [out appendString:@"<br>"]; return; }
    if ([n.tag isEqualToString:@"img"]) { NSString *u = ImageURL(n, base); if (u) [out appendFormat:@"<img src=\"%@\">", Escape(u)]; return; }
    if ([n.tag isEqualToString:@"a"]) {
        NSString *h = [n attr:@"href"] ? Absolute([n attr:@"href"], base) : nil;
        if (h && ![h hasPrefix:@"#"]) {
            [out appendFormat:@"<a href=\"%@\">", [Escape(h) stringByReplacingOccurrencesOfString:@"\"" withString:@"%22"]];
            for (HNNode *k in n.kids) Inline(k, base, out);
            [out appendString:@"</a>"];
            return;
        }
    }
    BOOL keep = [InlineKeep() containsObject:n.tag];
    if (keep) [out appendFormat:@"<%@>", n.tag];
    for (HNNode *k in n.kids) Inline(k, base, out);
    if (keep) [out appendFormat:@"</%@>", n.tag];
}

static BOOL BlankHTML(NSString *s) {
    NSString *t = [s stringByReplacingOccurrencesOfString:@"&nbsp;" withString:@""];
    t = [t stringByReplacingOccurrencesOfString:@" " withString:@""];
    if ([t rangeOfString:@"<img"].location != NSNotFound) return NO;
    NSMutableString *plain = [NSMutableString string];
    BOOL tag = NO;
    for (NSUInteger i = 0; i < t.length; i++) { unichar c = [t characterAtIndex:i]; if (c == '<') tag = YES; else if (c == '>') tag = NO; else if (!tag) [plain appendFormat:@"%C", c]; }
    return [[plain stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0;
}

static void Render(HNNode *n, NSURL *base, NSMutableString *out, NSInteger depth) {
    if (!n.tag) {
        NSString *t = [n.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length) [out appendFormat:@"<p>%@</p>\n", Escape(t)];
        return;
    }
    if (Junk(n) || depth > 60) return;
    NSString *t = n.tag;
    if ([t isEqualToString:@"img"]) { NSString *u = ImageURL(n, base); if (u) [out appendFormat:@"<p class=\"pic\"><img src=\"%@\"></p>\n", Escape(u)]; return; }
    if ([t isEqualToString:@"hr"]) { [out appendString:@"<hr>\n"]; return; }
    if (n.textLen < 200 && n.textLen > 0 && (double)n.linkLen / n.textLen > 0.5 && ![t hasPrefix:@"h"] && ![t isEqualToString:@"p"]) return;   /* link lists */

    if ([t length] == 2 && [t characterAtIndex:0] == 'h' && isdigit([t characterAtIndex:1])) {
        NSMutableString *m = [NSMutableString string];
        for (HNNode *k in n.kids) Inline(k, base, m);
        if (!BlankHTML(m)) [out appendFormat:@"<%@>%@</%@>\n", t, m, t];
        return;
    }
    if ([t isEqualToString:@"p"] || [t isEqualToString:@"figcaption"] || [t isEqualToString:@"dt"] || [t isEqualToString:@"dd"] || [t isEqualToString:@"address"]) {
        NSMutableString *m = [NSMutableString string];
        for (HNNode *k in n.kids) Inline(k, base, m);
        if (!BlankHTML(m)) [out appendFormat:@"<%@>%@</%@>\n", [t isEqualToString:@"figcaption"] ? @"p class=\"cap\"" : @"p", m, @"p"];
        return;
    }
    if ([t isEqualToString:@"pre"]) {
        NSString *txt = PlainText(n);
        if (txt.length) [out appendFormat:@"<pre>%@</pre>\n", Escape(txt)];
        return;
    }
    if ([t isEqualToString:@"ul"] || [t isEqualToString:@"ol"] || [t isEqualToString:@"blockquote"]) {
        NSMutableString *m = [NSMutableString string];
        for (HNNode *k in n.kids) Render(k, base, m, depth + 1);
        if (!BlankHTML(m)) [out appendFormat:@"<%@>\n%@</%@>\n", t, m, t];
        return;
    }
    if ([t isEqualToString:@"li"]) {
        NSMutableString *m = [NSMutableString string];
        if (HasBlockKid(n)) for (HNNode *k in n.kids) Render(k, base, m, depth + 1);
        else for (HNNode *k in n.kids) Inline(k, base, m);
        if (!BlankHTML(m)) [out appendFormat:@"<li>%@</li>\n", m];
        return;
    }
    /* containers: recurse; a container holding only inline content becomes one paragraph */
    if (!HasBlockKid(n) && ![t isEqualToString:@"table"] && ![t isEqualToString:@"tr"] && ![t isEqualToString:@"tbody"]) {
        NSMutableString *m = [NSMutableString string];
        for (HNNode *k in n.kids) Inline(k, base, m);
        if (!BlankHTML(m)) [out appendFormat:@"<p>%@</p>\n", m];
        return;
    }
    for (HNNode *k in n.kids) Render(k, base, out, depth + 1);
}

@implementation HNReaderMode

+ (NSString *)readableHTMLFromHTML:(NSString *)html baseURL:(NSURL *)base {
    HNNode *root = Parse(html);
    if (!root) return nil;
    Measure(root, NO);
    NSMutableArray *cands = [NSMutableArray array];
    Collect(root, cands);

    HNNode *best = nil; double bestScore = 0;
    for (HNNode *c in cands) {
        double sc = c.score;
        NSString *ic = IdClass(c);
        if ([c.tag isEqualToString:@"article"] || [c.tag isEqualToString:@"main"]) sc += 20;
        if (Matches(ic, @"(article|content|post|entry|story|text|body|main)")) sc += 20;
        if (Matches(ic, @"(hentry|footer|foot|header|widget|nav|aside)")) sc -= 20;
        sc *= 1.0 - (double)c.linkLen / MAX((double)c.textLen, 1);
        if (sc > bestScore) { bestScore = sc; best = c; }
    }
    /* an article element that wraps the winner is the better container (it carries the headline and the figures) */
    for (HNNode *p = best.parent; p; p = p.parent)
        if ([p.tag isEqualToString:@"article"] && p.textLen < best.textLen * 1.6 + 400) { best = p; break; }
    if (!best || best.textLen < 250) return nil;

    NSString *title = Meta(root, @"og:title") ?: Meta(root, @"twitter:title");
    if (!title.length) { HNNode *t = Find(root, @"title"); title = t ? PlainText(t) : nil; }
    title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *site = Meta(root, @"og:site_name") ?: base.host;

    NSMutableString *body = [NSMutableString string];
    Render(best, base, body, 0);
    /* the headline is printed above, so drop an identical first heading */
    if (title.length) {
        NSRange h1 = [body rangeOfString:@"<h1>"];
        if (h1.location != NSNotFound && h1.location < 400) {
            NSRange end = [body rangeOfString:@"</h1>" options:0 range:NSMakeRange(h1.location, body.length - h1.location)];
            if (end.location != NSNotFound) [body deleteCharactersInRange:NSMakeRange(h1.location, end.location + 5 - h1.location)];
        }
    }
    if (body.length > 600000) [body deleteCharactersInRange:NSMakeRange(600000, body.length - 600000)];
    if (body.length < 200) return nil;

    NSString *css =
        @"html{-webkit-text-size-adjust:100%}"
        "body{margin:0;padding:18px 16px 40px;background:#ece8de;color:#2f2a22;font:17px/1.55 Georgia,serif;word-wrap:break-word}"
        "h1.t{font:bold 25px/1.2 Georgia,serif;margin:0 0 6px;color:#1e1a14;text-shadow:0 1px 0 #fff}"
        ".site{font:12px Helvetica,sans-serif;color:#8a7c68;text-transform:uppercase;letter-spacing:1px;margin:0 0 18px;padding-bottom:12px;border-bottom:1px solid #cfc7b6}"
        "h1,h2,h3,h4,h5,h6{font-family:Georgia,serif;line-height:1.25;margin:1.3em 0 .4em;color:#1e1a14}h2{font-size:21px}h3{font-size:18px}h4,h5,h6{font-size:16px}"
        "p{margin:0 0 1em}a{color:#a8541a}img{max-width:100%;height:auto;border-radius:3px}.pic{text-align:center;margin:1em 0}"
        ".cap{font:italic 13px Georgia,serif;color:#7a6c58;text-align:center}"
        "blockquote{margin:1em 0;padding:2px 0 2px 14px;border-left:3px solid #c9b998;color:#5a4c3c}"
        "pre{background:#e0dacb;border:1px solid #cfc7b6;border-radius:4px;padding:10px;overflow:auto;font:12px/1.4 Courier,monospace}"
        "code{font:14px Courier,monospace;background:#e0dacb;padding:0 3px}ul,ol{padding-left:24px;margin:0 0 1em}li{margin-bottom:.4em}hr{border:0;border-top:1px solid #cfc7b6}"
        ".foot{margin-top:28px;padding-top:14px;border-top:1px solid #cfc7b6;font:13px Helvetica,sans-serif;text-align:center;color:#8a7c68}";
    return [NSString stringWithFormat:
            @"<!DOCTYPE html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><style>%@</style></head><body>"
            "<h1 class=\"t\">%@</h1><div class=\"site\">%@</div>%@<div class=\"foot\">Reader view &middot; <a href=\"%@\">Open the original page</a></div></body></html>",
            css, Escape(title ?: @""), Escape(site ?: @""), body, Escape([base absoluteString])];
}

+ (NSString *)decode:(NSData *)data response:(NSHTTPURLResponse *)resp {
    NSStringEncoding enc = 0;
    NSString *ct = [[resp allHeaderFields] objectForKey:@"Content-Type"] ?: [[resp allHeaderFields] objectForKey:@"content-type"];
    NSString *name = nil;
    NSRange r = [ct rangeOfString:@"charset=" options:NSCaseInsensitiveSearch];
    if (r.location != NSNotFound) name = [[ct substringFromIndex:r.location + r.length] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \"';"]];
    if (!name.length) {   /* look for <meta charset> in the first kilobytes */
        NSString *head = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, MIN((NSUInteger)4096, data.length))] encoding:NSISOLatin1StringEncoding];
        NSRange m = [head rangeOfString:@"charset=" options:NSCaseInsensitiveSearch];
        if (m.location != NSNotFound) {
            NSString *rest = [head substringFromIndex:m.location + m.length];
            NSRange e = [rest rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"' />;"]];
            name = e.location == NSNotFound ? nil : [rest substringToIndex:e.location];
        }
    }
    if (name.length) {
        CFStringEncoding cf = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)name);
        if (cf != kCFStringEncodingInvalidId) enc = CFStringConvertEncodingToNSStringEncoding(cf);
    }
    NSString *s = enc ? [[NSString alloc] initWithData:data encoding:enc] : nil;
    if (!s) s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!s) s = [[NSString alloc] initWithData:data encoding:NSWindowsCP1252StringEncoding];
    if (!s) s = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    return s;
}

+ (NSOperationQueue *)queue {
    static NSOperationQueue *q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ q = [[NSOperationQueue alloc] init]; q.maxConcurrentOperationCount = 2; });
    return q;
}

+ (void)loadURL:(NSURL *)url done:(void (^)(NSString *, NSURL *))done {
    NSMutableURLRequest *rq = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    [rq setValue:@"text/html,application/xhtml+xml;q=0.9,*/*;q=0.5" forHTTPHeaderField:@"Accept"];
    [rq setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_1_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10B329 Safari/8536.25" forHTTPHeaderField:@"User-Agent"];
    [NSURLConnection sendAsynchronousRequest:rq queue:[self queue] completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        NSString *out = nil;
        NSURL *base = resp.URL ?: url;
        @autoreleasepool {
            NSHTTPURLResponse *h = [resp isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)resp : nil;
            NSString *ct = [[[h allHeaderFields] objectForKey:@"Content-Type"] lowercaseString] ?: @"text/html";
            BOOL isHTML = [ct rangeOfString:@"html"].location != NSNotFound || [ct rangeOfString:@"xml"].location != NSNotFound;
            if (!err && data.length && h.statusCode == 200 && isHTML) {
                NSString *html = [self decode:data response:h];
                if (html) out = [self readableHTMLFromHTML:html baseURL:base];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ done(out, base); });
    }];
}
@end
