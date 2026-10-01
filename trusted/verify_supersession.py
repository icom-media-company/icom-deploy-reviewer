#!/usr/bin/env python3
import json,re,sys
if len(sys.argv)!=3: raise SystemExit("usage: verify_supersession.py artifact.json new-control")
control=sys.argv[2]
if not re.fullmatch(r"[0-9a-f]{40}",control) or control=="b589d4d92200ac393a04344f2f203efe7f177e6a": raise SystemExit("invalid superseding control")
d=json.load(open(sys.argv[1],encoding="utf-8"))
expected={"schema_version":1,"legacy_release_id":400681564,"legacy_tag":"manual-db/fulfillment/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/b589d4d92200ac393a04344f2f203efe7f177e6a","legacy_control_sha":"b589d4d92200ac393a04344f2f203efe7f177e6a","candidate_sha":"d0819f7bacf5ee6dedca4345796a8d022ff6a5cc","prior_durable_release_assets_empty_at_supersession":True,"trusted_mint_attempt1_signing_step":"skipped","trusted_mint_attempt1_staging_step":"skipped","earlier_trusted_runs_validation_only":[36816248037,36821338542],"legacy_control_workflow_run_census_sha256":"4b88c868c5bbb6795c313918ae4bacbb2b6a79e4c01952bfd1de9a8933e38efd","legacy_run_evidence_sha256":"3549e491b6ae684b4d4cfec450bcb47ad373e514c95c6ea07f3be840c62acd24","superseded_by_control":control,"reason":"pre-sign draft-discovery 404"}
if d!=expected: raise SystemExit("supersession artifact mismatch")
