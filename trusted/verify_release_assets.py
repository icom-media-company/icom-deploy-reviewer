#!/usr/bin/env python3
import json,sys
if len(sys.argv)!=2: raise SystemExit("usage: verify_release_assets.py release.json")
doc=json.load(open(sys.argv[1],encoding="utf-8"))
names=sorted(a.get("name") for a in doc.get("assets",[]))
expected=["manual-db-bundle.tar.gz","manual-db-bundle.tar.gz.sha256"]
if names!=expected: raise SystemExit(f"release asset census mismatch: {names}")
if doc.get("draft") is not False: raise SystemExit("release is not published")
