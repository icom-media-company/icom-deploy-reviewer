#!/usr/bin/env python3
import json,sys
if len(sys.argv)!=6: raise SystemExit("usage: select_staging_artifact.py artifacts run name candidate control")
ap,rp,name,candidate,control=sys.argv[1:]
arts=json.load(open(ap)).get("artifacts",[])
matches=[a for a in arts if a.get("name")==name and not a.get("expired",True)]
if len(matches)!=1: raise SystemExit("expected exactly one non-expired staging artifact")
a=matches[0]; wr=a.get("workflow_run") or {}; run=json.load(open(rp))
if wr.get("head_sha")!=control or run.get("id")!=wr.get("id"): raise SystemExit("run identity mismatch")
if run.get("head_sha")!=control or run.get("head_branch")!="main" or run.get("event")!="workflow_dispatch": raise SystemExit("run provenance mismatch")
if run.get("path")!=".github/workflows/manual-db-fulfillment-signer.yml" or run.get("status")!="completed": raise SystemExit("workflow/status mismatch")
if candidate not in name or control not in name: raise SystemExit("artifact name binding mismatch")
print(a["id"])
