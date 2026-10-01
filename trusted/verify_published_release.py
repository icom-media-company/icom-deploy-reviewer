#!/usr/bin/env python3
import json,re,sys
if len(sys.argv)!=4: raise SystemExit("usage: verify_published_release.py release.json candidate control")
d=json.load(open(sys.argv[1],encoding="utf-8")); candidate,control=sys.argv[2:]
if not re.fullmatch(r"[0-9a-f]{40}",candidate) or not re.fullmatch(r"[0-9a-f]{40}",control): raise SystemExit("invalid SHA")
old="b589d4d92200ac393a04344f2f203efe7f177e6a"; tag=f"manual-db/fulfillment/{candidate}/{control}"
body=f"candidate={candidate} control={control} order=90,91,92,93 supersedes_legacy_release=400681564 old_control={old}"
if d.get("draft") is not False or d.get("tag_name")!=tag or d.get("name")!="Trusted manual DB fulfillment package" or d.get("body")!=body:
 raise SystemExit("published release binding mismatch")
