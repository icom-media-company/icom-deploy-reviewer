#!/usr/bin/env python3
import json,sys
if len(sys.argv)!=3: raise SystemExit("usage: select_release.py paginated-releases.json exact-tag")
doc=json.load(open(sys.argv[1],encoding="utf-8")); tag=sys.argv[2]
if not isinstance(doc,list): raise SystemExit("releases response is not an array")
items=[]
for entry in doc:
 if isinstance(entry,list): items.extend(entry)
 elif isinstance(entry,dict): items.append(entry)
 else: raise SystemExit("invalid releases page")
matches=[r for r in items if r.get("tag_name")==tag]
if not matches: sys.exit(3)
if len(matches)!=1: raise SystemExit("duplicate exact-tag releases")
release=matches[0]
if not isinstance(release.get("id"),int) or release["id"]<=0: raise SystemExit("invalid release id")
print(json.dumps(release,sort_keys=True,separators=(",",":")))
