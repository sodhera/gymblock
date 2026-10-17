#!/usr/bin/env python3
"""Who ranks for a US App Store search, and how many ratings they have. Usage: python3 scripts/aso_competition.py "workout tracker" "app blocker"
Uses Apple's public search API (close to, not identical to, App Store search). Fewer ratings in the top 10 means an easier search to rank for.
Add -v to list the top 10 for each search."""
import urllib.request, urllib.parse, json, sys, statistics, concurrent.futures as cf
def top(term, n=10):
    u = "https://itunes.apple.com/search?" + urllib.parse.urlencode({"term": term, "country": "us", "entity": "software", "limit": n})
    for _ in range(3):
        try: return json.load(urllib.request.urlopen(u, timeout=15))["results"]
        except Exception: pass
    return []
verbose = "-v" in sys.argv
terms = [t for t in sys.argv[1:] if t != "-v"]
with cf.ThreadPoolExecutor(4) as ex:
    res = list(ex.map(top, terms))
print(f"{'search':28} {'median':>8} {'weakest':>8} {'<1k':>4}  top 3")
for t, r in zip(terms, res):
    counts = [a.get("userRatingCount", 0) for a in r]
    if not counts: print(f"{t:28} no results"); continue
    names = ", ".join(a["trackName"][:22] for a in r[:3])
    print(f"{t:28} {int(statistics.median(counts)):>8} {min(counts):>8} {sum(c < 1000 for c in counts):>4}  {names}")
    if verbose:
        for i, a in enumerate(r, 1): print(f"    {i:2}. {a['trackName'][:48]:48} {a.get('userRatingCount', 0):>8}")
