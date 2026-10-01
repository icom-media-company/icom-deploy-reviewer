#!/usr/bin/env python3
import hashlib,json,pathlib,stat,sys,zipfile
from datetime import datetime
if len(sys.argv)!=8: raise SystemExit("usage: verify_legacy_run_evidence.py run1 job log run2 release history authorized-actor")
runp,jobsp,logzipp,run2p,releasep,historyp,authorized=sys.argv[1:]
def raw(path): return pathlib.Path(path).read_bytes()
def load(path): return json.loads(raw(path))
def sha(path): return hashlib.sha256(raw(path)).hexdigest()
pins={runp:"d5e1d7d2692f23c064e994e8b4d771e09118710366c907025943eb04474a496c",jobsp:"6ee7d03e4c4948474ba8f6727937c1e1f0aacc80a543b2ebe5dcec26dd12d5f2",logzipp:"51c304d815452b48aad45337dcfcd9a60f4542f1100363f181e694370bb54c74",run2p:"2d5a5561f00211af0b73be530d51bb75e6daf9d2868f431b857366dba22a1ca3"}
for path,want in pins.items():
 if sha(path)!=want: raise SystemExit(f"pinned evidence hash mismatch: {path}")
run=load(runp); jobs=load(jobsp); run2=load(run2p); release=load(releasep); history=load(historyp)
old="b589d4d92200ac393a04344f2f203efe7f177e6a"; candidate="d0819f7bacf5ee6dedca4345796a8d022ff6a5cc"
if not authorized or authorized!="icom-media": raise SystemExit("authorized actor mismatch")
expected_run={"id":36821369400,"workflow_id":371811486,"path":".github/workflows/manual-db-fulfillment-signer.yml","event":"workflow_dispatch","head_sha":old,"status":"completed","conclusion":"failure","run_attempt":1}
for key,value in expected_run.items():
 if run.get(key)!=value: raise SystemExit(f"attempt1 run mismatch: {key}")
if (run.get("actor") or {}).get("login")!=authorized or (run.get("triggering_actor") or {}).get("login")!=authorized: raise SystemExit("run actor mismatch")
if run2.get("id")!=36821369400 or run2.get("run_attempt")!=2 or run2.get("head_sha")!=old or run2.get("status")!="completed" or run2.get("conclusion")!="cancelled": raise SystemExit("attempt2 mismatch")
matches=[j for j in jobs.get("jobs",[]) if j.get("id")==110237504710]
if len(matches)!=1: raise SystemExit("exact mint job missing/duplicate")
job=matches[0]
if job.get("name")!="mint" or job.get("run_attempt")!=1 or job.get("status")!="completed" or job.get("conclusion")!="failure": raise SystemExit("mint job mismatch")
steps={s.get("name"):s for s in job.get("steps",[])}
required={"Re-authorize signer and resolve durable state":"failure","Revalidate data and sign exact manifests":"skipped","Upload crash-recovery staging bytes":"skipped"}
for name,conclusion in required.items():
 if steps.get(name,{}).get("status")!="completed" or steps[name].get("conclusion")!=conclusion: raise SystemExit(f"step mismatch: {name}")
def dt(value): return datetime.fromisoformat(value.replace("Z","+00:00"))
fail=steps["Re-authorize signer and resolve durable state"]
if not (dt(job["started_at"])<=dt(fail["started_at"])<=dt(fail["completed_at"])<=dt(job["completed_at"])): raise SystemExit("job/step timestamp order mismatch")
tag=f"manual-db/fulfillment/{candidate}/{old}"
body=f"candidate={candidate} control={old}; absent staging may resume only with byte-identical deterministic mint"
if release.get("id")!=400681564 or release.get("created_at")!="2026-10-01T04:39:32Z" or (release.get("author") or {}).get("login")!="github-actions[bot]" or release.get("draft") is not True or release.get("assets")!=[] or release.get("tag_name")!=tag or release.get("name")!="RESERVED trusted manual DB package" or release.get("body")!=body: raise SystemExit("legacy release evidence mismatch")
if not (dt(fail["started_at"])<=dt(release["updated_at"])<=dt(fail["completed_at"])): raise SystemExit("release update not within failed step")
with zipfile.ZipFile(logzipp) as archive:
 names=[]
 for item in archive.infolist():
  path=pathlib.PurePosixPath(item.filename); mode=item.external_attr>>16
  if path.is_absolute() or ".." in path.parts or "\\" in item.filename or item.filename in names or stat.S_ISLNK(mode): raise SystemExit("unsafe logs archive")
  names.append(item.filename)
 if "0_mint.txt" not in names: raise SystemExit("mint log missing")
 text=archive.read("0_mint.txt").decode("utf-8-sig")
if '/releases/tags/$tag' not in text or 'gh: Not Found (HTTP 404)' not in text or 'releases/tag/untagged-' not in text: raise SystemExit("expected create then lookup 404 absent")
if "ssh-keygen" in text or "SIGNING_KEY" in text: raise SystemExit("signing execution found in failed job log")
pages=history if isinstance(history,list) else []
runs=[]
for page in pages:
 if not isinstance(page,dict) or not isinstance(page.get("workflow_runs"),list): raise SystemExit("invalid workflow history")
 runs.extend(page["workflow_runs"])
if any(r.get("created_at") and dt(r["created_at"])<dt(release["created_at"]) for r in runs): raise SystemExit("trusted signing workflow existed before legacy release creation")
near=[r for r in runs if r.get("id")==36816248037]
if len(near)!=1 or near[0].get("created_at")!="2026-10-01T04:40:57Z" or near[0].get("head_sha")!=old: raise SystemExit("first nearby validation-only run evidence missing")
selected={"schema_version":1,"repository":"icom-media-company/icom-deploy-reviewer","workflow_id":371811486,"workflow_path":expected_run["path"],"legacy_release_id":400681564,"legacy_release_created_at_commit_timestamp":release["created_at"],"legacy_release_updated_at":release["updated_at"],"legacy_release_author":"github-actions[bot]","legacy_release_assets_empty_at_supersession":True,"attempt1_run_id":36821369400,"attempt1_job_id":110237504710,"attempt1_failed_step":"Re-authorize signer and resolve durable state","attempt1_signing_step":"skipped","attempt1_staging_step":"skipped","attempt2_conclusion":"cancelled","post_create_lookup_http_status":404,"no_trusted_signing_workflow_run_before_release_creation":True,"raw_sha256":{"attempt1_run":pins[runp],"attempt1_jobs":pins[jobsp],"attempt1_logs_zip":pins[logzipp],"attempt2_run":pins[run2p]}}
encoded=json.dumps(selected,sort_keys=True,separators=(",",":"))
print(encoded)
