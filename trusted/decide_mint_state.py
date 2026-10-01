#!/usr/bin/env python3
import sys
if len(sys.argv)!=5: raise SystemExit("usage: decide_mint_state.py created-this-run tag-exists exact-draft-reservation staging-state")
created,tag,reservation,staging=sys.argv[1:]
if {created,tag,reservation}-{ "true","false" }: raise SystemExit("invalid boolean")
if staging not in {"absent","verified"}: raise SystemExit("invalid staging state")
if staging=="verified":
 if tag!="true" or reservation!="true": raise SystemExit("verified staging lacks exact reservation")
 print("recover")
elif tag=="true" and reservation=="true": print("new" if created=="true" else "resume_idempotent")
else: raise SystemExit("absent staging lacks exact reservation")
