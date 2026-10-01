#!/usr/bin/env python3
import json,sys
if len(sys.argv)!=3 or sys.argv[2] not in {"draft","published"}: raise SystemExit("usage: verify_release_assets.py release.json draft|published")
doc=json.load(open(sys.argv[1],encoding="utf-8"))
names=sorted(a.get("name") for a in doc.get("assets",[]))
expected=["manual-db-bundle.tar.gz","manual-db-bundle.tar.gz.sha256"]
if names!=expected: raise SystemExit(f"release asset census mismatch: {names}")
if doc.get("draft") is not (sys.argv[2]=="draft"): raise SystemExit("release publication state mismatch")
