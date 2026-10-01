#!/usr/bin/env python3
import json,re,sys
if len(sys.argv)!=4: raise SystemExit("usage: verify_reservation.py release.json candidate control")
doc=json.load(open(sys.argv[1],encoding="utf-8")); candidate,control=sys.argv[2:]
if not re.fullmatch(r"[0-9a-f]{40}",candidate) or not re.fullmatch(r"[0-9a-f]{40}",control): raise SystemExit("invalid SHA")
tag=f"manual-db/fulfillment/{candidate}/{control}"
old="b589d4d92200ac393a04344f2f203efe7f177e6a"
if control==old: raise SystemExit("legacy reservation cannot be active")
body=f"candidate={candidate} control={control}; supersedes_legacy_release=400681564 old_control={old} reason=pre-sign draft-discovery 404"
if doc.get("draft") is not True or doc.get("tag_name")!=tag or doc.get("name")!="RESERVED trusted manual DB package" or doc.get("body")!=body:
 raise SystemExit("reservation identity mismatch")
