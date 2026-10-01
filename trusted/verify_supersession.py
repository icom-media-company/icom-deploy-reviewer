#!/usr/bin/env python3
import json,re,sys
if len(sys.argv)!=3: raise SystemExit("usage: verify_supersession.py artifact.json new-control")
control=sys.argv[2]
if not re.fullmatch(r"[0-9a-f]{40}",control) or control=="b589d4d92200ac393a04344f2f203efe7f177e6a": raise SystemExit("invalid superseding control")
d=json.load(open(sys.argv[1],encoding="utf-8"))
expected={"schema_version":1,"legacy_release_id":400681564,"legacy_tag":"manual-db/fulfillment/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/b589d4d92200ac393a04344f2f203efe7f177e6a","legacy_control_sha":"b589d4d92200ac393a04344f2f203efe7f177e6a","candidate_sha":"d0819f7bacf5ee6dedca4345796a8d022ff6a5cc","prior_durable_release_assets_empty_at_supersession":True,"trusted_mint_attempt1_signing_step":"skipped","trusted_mint_attempt1_staging_step":"skipped","no_trusted_signing_workflow_run_before_release_creation":True,"legacy_run_evidence_sha256":"57b418667e80adf9ef0932308af202d3448342ceae342454f7417cb438ddce47","superseded_by_control":control,"reason":"pre-sign draft-discovery 404"}
if d!=expected: raise SystemExit("supersession artifact mismatch")
