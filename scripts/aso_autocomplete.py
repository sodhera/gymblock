#!/usr/bin/env python3
"""US App Store autocomplete depth per search. Usage: python3 scripts/aso_autocomplete.py "workout tracker" "app blocker"
Fewer letters before a phrase appears, and a higher position, mean more searches."""
import urllib.request, urllib.parse, plistlib, sys, json, concurrent.futures as cf
def hints(prefix):
    u="https://search.itunes.apple.com/WebObjects/MZSearchHints.woa/wa/hints?clientApplication=Software&term="+urllib.parse.quote(prefix)
    r=urllib.request.Request(u,headers={"X-Apple-Store-Front":"143441-1,29","User-Agent":"Mozilla/5.0"})
    for _ in range(3):
        try: return [h['term'] for h in plistlib.loads(urllib.request.urlopen(r,timeout=15).read()).get('hints',[])]
        except Exception: pass
    return []
def score(term):
    # shortest prefix where the exact term shows in Apple's autocomplete, and its position
    for n in range(1,len(term)+1):
        p=term[:n]
        if p.endswith(' '): continue
        h=hints(p)
        if term in h: return term,n,h.index(term)+1,len(term)
    return term,None,None,len(term)
terms=sys.argv[1:]
with cf.ThreadPoolExecutor(6) as ex:
    res=list(ex.map(score,terms))
for t,n,pos,L in sorted(res,key=lambda x:(x[1] or 99, x[2] or 99)):
    print(f"{t:32} prefix={n if n else '-':>3} of {L:<3} pos={pos if pos else '-'}")
