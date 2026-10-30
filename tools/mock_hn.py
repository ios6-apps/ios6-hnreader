#!/usr/bin/env python3
"""A stand-in for the HN Algolia API with made-up stories, comments and articles, for the simulator and for working offline.

    tools/mock_hn.py [port]                      # default port 18765, listens on 127.0.0.1
    HN_BASE=http://127.0.0.1:18765 ...           # simulator build: point the app at it (see the README)

It serves the three endpoints the app uses (/search, /items/<id>) plus /articles/<id>.html, so the reader view has a page to extract.
"""
import json, struct, sys, time, zlib
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 18765
NOW = int(time.time())

# (id, title, has article, author, points, comments, age in minutes)
FRONT = [
    (1, "A field guide to old phones and new protocols", True, "alice", 612, 148, 190),
    (2, "Show HN: Pocket synthesizer in 4 KB of C", True, "bob", 431, 87, 320),
    (3, "Why we moved our build farm back to bare metal", True, "carol", 389, 203, 410),
    (4, "The quiet joy of a well-made hash table", True, "dave", 287, 64, 530),
    (5, "Ask HN: What do you do with an old phone?", False, "erin", 254, 311, 660),
    (6, "Notes on writing a tiny TLS client", True, "frank", 198, 41, 800),
    (7, "Fifty years of the spreadsheet", True, "grace", 176, 95, 950),
    (8, "Show HN: A pocket-sized weather station", True, "heidi", 143, 38, 1100),
]
ASK = [(11, "Ask HN: Which book changed how you write code?", False, "ivan", 320, 410, 400),
       (12, "Ask HN: How do you keep a long-running side project alive?", False, "judy", 210, 180, 700),
       (13, "Ask HN: What is your favourite small tool?", False, "mallory", 150, 120, 900)]
SHOW = [(21, "Show HN: Tiny static site generator in 200 lines", True, "niaj", 250, 60, 300),
        (22, "Show HN: A skeuomorphic calculator for old iPhones", True, "olivia", 180, 44, 600),
        (23, "Show HN: Plain-text budgeting", True, "peggy", 120, 30, 1000)]
BY_ID = {s[0]: s for s in FRONT + ASK + SHOW}
AUTHORS = ["alice", "bob", "carol", "dave", "erin", "frank", "grace", "heidi"]
BODIES = [
    "I ran into the same problem last year. The boring answer turned out to be the right one: measure first, then change one thing at a time.",
    "<p>This matches my experience.</p><p>The part that surprised me was how much simpler the code got once the data structure was right.</p>",
    "Has anyone tried this on really old hardware? I would expect the memory limits to bite long before the CPU does.",
    "Good write-up. I would add that <i>documentation</i> is the feature people notice last and miss first.",
    "Counterpoint: it depends on the team. For two people this is overkill, for twenty it is the only thing that works.",
    "Thanks for sharing. Bookmarked for the weekend.",
]

def hit(s):
    i, title, art, author, pts, com, age = s
    d = {"objectID": str(i), "title": title, "author": author, "points": pts, "num_comments": com, "created_at_i": NOW - age * 60}
    if art: d["url"] = "http://127.0.0.1:%d/articles/%d.html" % (PORT, i)
    else: d["story_text"] = "<p>Curious what everyone here does. Short answers welcome.</p>"
    return d

def item(s):
    d = hit(s)
    d["id"] = s[0]
    if "story_text" in d: d["text"] = d.pop("story_text")
    kids = []
    for k in range(5):
        top = {"author": AUTHORS[(s[0] + k) % len(AUTHORS)], "text": BODIES[(s[0] + k) % len(BODIES)], "created_at_i": NOW - (s[6] - 10 * (k + 1)) * 60, "children": []}
        for j in range(k % 3):
            top["children"].append({"author": AUTHORS[(s[0] + k + j + 1) % len(AUTHORS)], "text": BODIES[(s[0] + k + j + 2) % len(BODIES)],
                                    "created_at_i": NOW - (s[6] - 10 * (k + 1) - 5 * (j + 1)) * 60,
                                    "children": [{"author": AUTHORS[(s[0] + j) % len(AUTHORS)], "text": "Agreed.", "created_at_i": NOW - 60, "children": []}] if j == 1 else []})
        kids.append(top)
    d["children"] = kids
    return d

def png(w=640, h=240):
    rows = b"".join(b"\x00" + b"".join(struct.pack("BBB", 200 - 90 * x // w, 120 + 60 * y // h, 60 + 120 * x // w) for x in range(w)) for y in range(h))
    def chunk(t, data): return struct.pack(">I", len(data)) + t + data + struct.pack(">I", zlib.crc32(t + data) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b"")

LOREM = ["Old phones are not useless, they are just stuck on old protocols. The hardware that rendered a smooth interface in 2012 still does so today; "
         "what changed is the world around it, and mostly its encryption.",
         "A TLS client is smaller than most people expect. The handshake is a few messages, certificate checking is a loop, and the rest is careful bookkeeping "
         "about buffers, timeouts and what to do when the other side simply stops talking.",
         "None of this needs a framework. A few hundred lines of C, a bundle of root certificates and a patient afternoon go a long way, "
         "and the result keeps working long after the platform stopped receiving updates.",
         "The lesson, as usual, is to write down what the code is supposed to do before reading what it does."]

def article(i):
    s = BY_ID[i]
    ps = "".join("<p>%s</p>" % LOREM[(i + k) % len(LOREM)] for k in range(4))
    return ("<html><head><title>%s</title><meta property=\"og:site_name\" content=\"Example Notes\"><script>var x=1;</script></head><body>"
            "<nav><a href=\"/\">Home</a> <a href=\"/archive\">Archive</a></nav><article><h1>%s</h1>%s<img src=\"/img/hero.png\">%s</article>"
            "<div class=\"sidebar\">Subscribe to our newsletter</div><footer>Copyright Example Notes</footer></body></html>" % (s[1], s[1], ps, ps)).encode()

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send(self, code, ctype, body):
        self.send_response(code); self.send_header("Content-Type", ctype); self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_GET(self):
        u = urlparse(self.path); q = parse_qs(u.query)
        if u.path == "/search":
            tag = (q.get("tags") or ["front_page"])[0]
            rows = {"front_page": FRONT, "ask_hn": ASK, "show_hn": SHOW}.get(tag, [])
            self.send(200, "application/json", json.dumps({"hits": [hit(s) for s in rows]}).encode())
        elif u.path.startswith("/items/") and u.path[7:].isdigit() and int(u.path[7:]) in BY_ID:
            self.send(200, "application/json", json.dumps(item(BY_ID[int(u.path[7:])])).encode())
        elif u.path.startswith("/articles/") and u.path.endswith(".html") and u.path[10:-5].isdigit() and int(u.path[10:-5]) in BY_ID:
            self.send(200, "text/html; charset=utf-8", article(int(u.path[10:-5])))
        elif u.path == "/img/hero.png":
            self.send(200, "image/png", png())
        else:
            self.send(404, "text/plain", b"not found")

if __name__ == "__main__":
    print("mock HN on http://127.0.0.1:%d" % PORT)
    HTTPServer(("127.0.0.1", PORT), H).serve_forever()
