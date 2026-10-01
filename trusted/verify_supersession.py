#!/usr/bin/env python3
import json,re,sys
if len(sys.argv)!=3: raise SystemExit("usage: verify_supersession.py artifact.json new-control")
control=sys.argv[2]
if not re.fullmatch(r"[0-9a-f]{40}",control) or control=="b589d4d92200ac393a04344f2f203efe7f177e6a": raise SystemExit("invalid superseding control")
d=json.load(open(sys.argv[1],encoding="utf-8"))
expected={"schema_version":1,"legacy_release_id":400681564,"legacy_tag":"manual-db/fulfillment/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/b589d4d92200ac393a04344f2f203efe7f177e6a","legacy_control_sha":"b589d4d92200ac393a04344f2f203efe7f177e6a","candidate_sha":"d0819f7bacf5ee6dedca4345796a8d022ff6a5cc","observed_empty":True,"superseded_by_control":control,"reason":"pre-sign draft-discovery 404","prior_signing":False}
if d!=expected: raise SystemExit("supersession artifact mismatch")
