#!/usr/bin/env python3
import hashlib,json,pathlib,re,sys,zipfile
from datetime import datetime
from canonical_actions_logs import canonical_digest
if len(sys.argv)!=13: raise SystemExit("usage: verify_legacy_run_evidence.py attempt1-run attempt1-jobs logs.zip attempt2-run release tag-ref prior1-run prior1-jobs prior2-run prior2-jobs paginated-census authorized-actor")
runp,jobsp,logzipp,run2p,releasep,refp,prior1p,prior1jobsp,prior2p,prior2jobsp,censusp,authorized=sys.argv[1:]
def raw(path): return pathlib.Path(path).read_bytes()
def load(path): return json.loads(raw(path))
def sha(path): return hashlib.sha256(raw(path)).hexdigest()
pins={runp:"d5e1d7d2692f23c064e994e8b4d771e09118710366c907025943eb04474a496c",jobsp:"6ee7d03e4c4948474ba8f6727937c1e1f0aacc80a543b2ebe5dcec26dd12d5f2",run2p:"2d5a5561f00211af0b73be530d51bb75e6daf9d2868f431b857366dba22a1ca3",prior1p:"6b491e96ac2d129a9ad48d90df36bc33f995e0bf9cbc6a106e9d8d9e062101e5",prior1jobsp:"87a962c3d3642ac7fd252f385ece3fad01862a6bee7df2ae023a3e77d9f71243",prior2p:"84ad3bc2291031006d3c41376e51b8a8b501adade2da8effd3085728f627e6c9",prior2jobsp:"33d193426feadaaf2092e2ca9561a081c542acf2b17f9f85d6ca227996920277"}
for path,want in pins.items():
 if sha(path)!=want: raise SystemExit(f"pinned evidence hash mismatch: {path}")
run=load(runp); jobs=load(jobsp); run2=load(run2p); release=load(releasep); ref=load(refp)
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
if (ref.get("object") or {}).get("type")!="commit" or (ref.get("object") or {}).get("sha")!=old: raise SystemExit("legacy tag ref mismatch")
if not (dt(fail["started_at"])<=dt(release["updated_at"])<=dt(fail["completed_at"])): raise SystemExit("release update not within failed step")
log_names=["0_mint.txt","1_validate-data.txt","mint/system.txt","validate-data/system.txt"]
try: logs_canonical_sha=canonical_digest(logzipp,log_names)
except (OSError,ValueError,zipfile.BadZipFile) as error: raise SystemExit(str(error))
if logs_canonical_sha!="395b7a31117dac39014614c43a92c6ab99f4553cfbd2b361297b2acce10d247a": raise SystemExit("canonical logs digest mismatch")
with zipfile.ZipFile(logzipp) as archive: text=archive.read("0_mint.txt").decode("utf-8-sig")
emitted=re.findall(r"https://github\.com/icom-media-company/icom-deploy-reviewer/releases/tag/untagged-[A-Za-z0-9]+",text)
if '/releases/tags/$tag' not in text or 'gh: Not Found (HTTP 404)' not in text or emitted!=[release.get("html_url")]: raise SystemExit("exact create URL then lookup 404 evidence mismatch")
if "ssh-keygen" in text or "SIGNING_KEY" in text: raise SystemExit("signing execution found in failed job log")
prior=[]
for run_path,jobs_path,run_id,created in ((prior1p,prior1jobsp,36816248037,"2026-10-01T04:40:57Z"),(prior2p,prior2jobsp,36821338542,"2026-10-01T05:45:44Z")):
 prior_run=load(run_path); prior_jobs=load(jobs_path)
 if prior_run.get("id")!=run_id or prior_run.get("workflow_id")!=371811486 or prior_run.get("path")!=expected_run["path"] or prior_run.get("event")!="workflow_dispatch" or prior_run.get("head_sha")!=old or prior_run.get("status")!="completed" or prior_run.get("conclusion")!="success" or prior_run.get("created_at")!=created or (prior_run.get("actor") or {}).get("login")!=authorized: raise SystemExit("prior validation run mismatch")
 mint=[j for j in prior_jobs.get("jobs",[]) if j.get("name")=="mint"]
 validate=[j for j in prior_jobs.get("jobs",[]) if j.get("name")=="validate-data"]
 if len(mint)!=1 or mint[0].get("conclusion")!="skipped" or mint[0].get("steps")!=[] or len(validate)!=1 or validate[0].get("conclusion")!="success": raise SystemExit("prior run was not validation-only")
 prior.append({"run_id":run_id,"effective_mode":"validation_only","mint_job":"skipped","run_sha256":pins[run_path],"jobs_sha256":pins[jobs_path]})
pages=load(censusp)
if not isinstance(pages,list): raise SystemExit("invalid paginated census")
census_runs=[]
for page in pages:
 if not isinstance(page,dict) or not isinstance(page.get("workflow_runs"),list): raise SystemExit("invalid census page")
 census_runs.extend(r for r in page["workflow_runs"] if r.get("workflow_id")==371811486 and r.get("path")==expected_run["path"] and r.get("head_sha")==old)
if len(census_runs)!=3 or {r.get("id") for r in census_runs}!={36816248037,36821338542,36821369400}: raise SystemExit("legacy control workflow run census mismatch")
by_id={r["id"]:r for r in census_runs}
expected_listed={36816248037:(1,"success"),36821338542:(1,"success"),36821369400:(2,"cancelled")}
for rid,(attempt,conclusion) in expected_listed.items():
 if by_id[rid].get("run_attempt")!=attempt or by_id[rid].get("status")!="completed" or by_id[rid].get("conclusion")!=conclusion: raise SystemExit("legacy census state mismatch")
census=[{"run_id":rid,"listed_run_attempt":expected_listed[rid][0],"verified_attempts":[1,2] if rid==36821369400 else [1]} for rid in sorted(expected_listed)]
census_raw=json.dumps(census,sort_keys=True,separators=(",",":")).encode(); census_sha=hashlib.sha256(census_raw).hexdigest()
selected={"schema_version":1,"repository":"icom-media-company/icom-deploy-reviewer","workflow_id":371811486,"workflow_path":expected_run["path"],"legacy_release_id":400681564,"legacy_release_updated_at":release["updated_at"],"legacy_release_author":"github-actions[bot]","legacy_release_assets_empty_at_supersession":True,"legacy_release_html_url":release["html_url"],"legacy_release_tag":tag,"legacy_tag_target":old,"attempt1_run_id":36821369400,"attempt1_job_id":110237504710,"attempt1_failed_step":"Re-authorize signer and resolve durable state","attempt1_signing_step":"skipped","attempt1_staging_step":"skipped","attempt2_conclusion":"cancelled","post_create_lookup_http_status":404,"earlier_trusted_runs":prior,"legacy_control_workflow_run_census":census,"legacy_control_workflow_run_census_sha256":census_sha,"raw_sha256":{"attempt1_run":pins[runp],"attempt1_jobs":pins[jobsp],"attempt2_run":pins[run2p]},"canonical_content_sha256":{"attempt1_logs":logs_canonical_sha}}
encoded=json.dumps(selected,sort_keys=True,separators=(",",":"))
print(encoded)
