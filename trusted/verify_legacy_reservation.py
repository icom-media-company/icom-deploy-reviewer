#!/usr/bin/env python3
import json,sys
OLD="b589d4d92200ac393a04344f2f203efe7f177e6a"
CANDIDATE="d0819f7bacf5ee6dedca4345796a8d022ff6a5cc"
TAG=f"manual-db/fulfillment/{CANDIDATE}/{OLD}"
if len(sys.argv)!=2: raise SystemExit("usage: verify_legacy_reservation.py release.json")
d=json.load(open(sys.argv[1],encoding="utf-8"))
body=f"candidate={CANDIDATE} control={OLD}; absent staging may resume only with byte-identical deterministic mint"
if d.get("id")!=400681564 or d.get("tag_name")!=TAG or d.get("draft") is not True or d.get("name")!="RESERVED trusted manual DB package" or d.get("body")!=body or d.get("assets")!=[]:
 raise SystemExit("legacy reservation mismatch")
print("LEGACY_RESERVATION_VERIFY=PASS")
