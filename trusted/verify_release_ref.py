#!/usr/bin/env python3
import json,re,sys
if len(sys.argv)!=3 or not re.fullmatch(r"[0-9a-f]{40}",sys.argv[2]): raise SystemExit("usage: verify_release_ref.py ref.json control-sha")
d=json.load(open(sys.argv[1])); obj=d.get("object") or {}
if obj.get("type")!="commit" or obj.get("sha")!=sys.argv[2]: raise SystemExit("release tag target mismatch")
