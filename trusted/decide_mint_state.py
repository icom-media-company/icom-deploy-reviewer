#!/usr/bin/env python3
import sys
if len(sys.argv)!=5: raise SystemExit("usage: decide_mint_state.py created-this-run tag-exists release-exists staging-state")
created,tag,release,staging=sys.argv[1:]
if {created,tag,release}-{ "true","false" }: raise SystemExit("invalid boolean")
if staging not in {"absent","verified"}: raise SystemExit("invalid staging state")
if staging=="verified":
 if tag!="true" or release!="true": raise SystemExit("verified staging lacks complete reservation")
 print("recover")
elif created=="true" and tag=="true" and release=="true": print("new")
else: raise SystemExit("reservation exists without verified staging; re-sign forbidden")
