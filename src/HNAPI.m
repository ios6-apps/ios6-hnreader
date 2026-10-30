#import "HNAPI.h"
#import "HNStyle.h"

static id nn(id v) { return v == [NSNull null] ? nil : v; }

@implementation HNStory
+ (HNStory *)storyFromDict:(NSDictionary *)d {
    HNStory *s = [[HNStory alloc] init];
    id oid = nn([d objectForKey:@"objectID"]) ?: nn([d objectForKey:@"id"]);
    s.sid = [oid description];
    s.title = nn([d objectForKey:@"title"]);
    s.url = nn([d objectForKey:@"url"]);
    s.author = nn([d objectForKey:@"author"]);
    s.points = [nn([d objectForKey:@"points"]) integerValue];
    s.comments = [nn([d objectForKey:@"num_comments"]) integerValue];
    s.created = [nn([d objectForKey:@"created_at_i"]) doubleValue];
    s.text = HNPlainText(nn([d objectForKey:@"story_text"]) ?: nn([d objectForKey:@"text"]));
    if (s.url.length) {
        NSString *host = [[NSURL URLWithString:s.url] host];
        if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
        s.domain = host;
    }
    return s;
}

- (NSDictionary *)dictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (self.sid) [d setObject:self.sid forKey:@"objectID"];
    if (self.title) [d setObject:self.title forKey:@"title"];
    if (self.url) [d setObject:self.url forKey:@"url"];
    if (self.author) [d setObject:self.author forKey:@"author"];
    if (self.text) [d setObject:self.text forKey:@"story_text"];
    [d setObject:[NSNumber numberWithInteger:self.points] forKey:@"points"];
    [d setObject:[NSNumber numberWithInteger:self.comments] forKey:@"num_comments"];
    [d setObject:[NSNumber numberWithDouble:self.created] forKey:@"created_at_i"];
    return d;
}
@end

@implementation HNComment
@end

static NSString *const kSavedKey = @"hn.saved";

@implementation HNFavorites
+ (NSArray *)stories {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *d in [[NSUserDefaults standardUserDefaults] arrayForKey:kSavedKey]) [out addObject:[HNStory storyFromDict:d]];
    return out;
}
+ (BOOL)contains:(NSString *)sid {
    for (NSDictionary *d in [[NSUserDefaults standardUserDefaults] arrayForKey:kSavedKey])
        if ([[[d objectForKey:@"objectID"] description] isEqualToString:sid]) return YES;
    return NO;
}
+ (void)store:(NSArray *)a {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    [u setObject:a forKey:kSavedKey];
    [u synchronize];
}
+ (BOOL)toggle:(HNStory *)story {
    if ([self contains:story.sid]) { [self remove:story.sid]; return NO; }
    NSMutableArray *a = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:kSavedKey]];
    [a insertObject:[story dictionary] atIndex:0];
    [self store:a];
    return YES;
}
+ (void)remove:(NSString *)sid {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *d in [[NSUserDefaults standardUserDefaults] arrayForKey:kSavedKey])
        if (![[[d objectForKey:@"objectID"] description] isEqualToString:sid]) [a addObject:d];
    [self store:a];
}
@end

static NSString *base(void) {
    static NSString *b;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *o = [NSString stringWithContentsOfFile:@"/var/mobile/hnbase.txt" encoding:NSUTF8StringEncoding error:NULL];
        o = [o stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        b = o.length ? o : @"https://hn.algolia.com/api/v1";
#ifdef HN_PREVIEW   /* simulator: HN_BASE=http://127.0.0.1:18765 talks to tools/mock_hn.py */
        if (getenv("HN_BASE")) b = [NSString stringWithUTF8String:getenv("HN_BASE")];
#endif
    });
    return b;
}

static NSOperationQueue *queue(void) {
    static NSOperationQueue *q;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ q = [[NSOperationQueue alloc] init]; q.maxConcurrentOperationCount = 3; });
    return q;
}

/* fetches JSON, runs parse off the main thread, then calls done on the main thread */
static void fetch(NSString *path, id (^parse)(id json), void (^done)(id result, NSString *error)) {
    NSURL *u = [NSURL URLWithString:[base() stringByAppendingString:path]];
    NSURLRequest *rq = [NSURLRequest requestWithURL:u cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:25];
    [NSURLConnection sendAsynchronousRequest:rq queue:queue() completionHandler:^(NSURLResponse *resp, NSData *data, NSError *e) {
        id result = nil;
        NSString *err = nil;
        if (e) err = [e localizedDescription];
        else if ([resp isKindOfClass:[NSHTTPURLResponse class]] && [(NSHTTPURLResponse *)resp statusCode] != 200)
            err = [NSString stringWithFormat:@"Server returned %ld", (long)[(NSHTTPURLResponse *)resp statusCode]];
        else {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if (!json) err = @"Unreadable response";
            else result = parse(json);
        }
        dispatch_async(dispatch_get_main_queue(), ^{ done(result, err); });
    }];
}

static void flatten(NSArray *children, NSInteger depth, NSMutableArray *out) {
    for (NSDictionary *c in children) {
        if (![c isKindOfClass:[NSDictionary class]] || out.count > 1500) continue;
        NSString *text = nn([c objectForKey:@"text"]);
        NSString *author = nn([c objectForKey:@"author"]);
        if (text.length && author.length) {
            HNComment *k = [[HNComment alloc] init];
            k.author = author;
            k.text = HNPlainText(text);
            k.created = [nn([c objectForKey:@"created_at_i"]) doubleValue];
            k.depth = depth;
            [out addObject:k];
            flatten(nn([c objectForKey:@"children"]), depth + 1, out);
        } else {
            flatten(nn([c objectForKey:@"children"]), depth, out);   /* deleted comment: keep its replies */
        }
    }
}

@implementation HNAPI

+ (void)loadStories:(HNKind)kind done:(HNStoriesBlock)done {
    long since = (long)[[NSDate date] timeIntervalSince1970] - 3 * 86400;
    NSString *path;
    if (kind == HNKindNews) path = @"/search?tags=front_page&hitsPerPage=40";
    else path = [NSString stringWithFormat:@"/search?tags=%@&numericFilters=created_at_i%%3E%ld&hitsPerPage=40",
                 kind == HNKindAsk ? @"ask_hn" : @"show_hn", since];
    fetch(path, ^id(id json) {
        NSMutableArray *out = [NSMutableArray array];
        for (NSDictionary *h in [json objectForKey:@"hits"]) {
            HNStory *s = [HNStory storyFromDict:h];
            if (s.title.length) [out addObject:s];
        }
        return out;
    }, ^(id result, NSString *err) { done(result, err); });
}

+ (void)loadItem:(NSString *)sid done:(HNItemBlock)done {
    fetch([@"/items/" stringByAppendingString:sid], ^id(id json) {
        NSMutableArray *flat = [NSMutableArray array];
        flatten(nn([json objectForKey:@"children"]), 0, flat);
        return [NSArray arrayWithObjects:[HNStory storyFromDict:json], flat, nil];
    }, ^(id result, NSString *err) {
        done(result ? [result objectAtIndex:0] : nil, result ? [result objectAtIndex:1] : nil, err);
    });
}

@end
