#!/usr/bin/env python3
import hashlib,json,pathlib,re,subprocess,sys

CANDIDATE="d0819f7bacf5ee6dedca4345796a8d022ff6a5cc"
TRUST_SHA="704dc47b50f2ebbb8515b400bde88a943d967f313255a85a5bd4b1534177acd9"
REVIEWS_SHA="8144533067199f1df88b7ec2a7623275d9934feeaebd48f14b4dfa329dc12bc9"
ORDER=["20261001-fulfillment-retry-90","20261001-pgsodium-prerequisite-91","20261001-fulfillment-historical-evidence-92","20261001-mto-claim-93"]
MANIFESTS=["2dff21f4ddb83ea52905420994c238eaf517e9bbbb6009b6086db87356612f44","0cb36140d395a8c3b8468485e13ab91e25d75a966cef93300b90e5009c5da6fa","f4a4f6e4ae1a5bfa0d441829cf7bb68dd8d6c81ce1a8c28a6e653bba70b8873e","24882dc7d6d450c1b2c86638ca9084dbd7e67302684518fd9c2f352dacfa3b65"]
EXCLUDED=["BUNDLE-METADATA.json","BUNDLE-METADATA.json.ci.sig","BUNDLE.SHA256SUMS"]
def die(s): raise SystemExit(s)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def regular(p):
 if p.is_symlink() or not p.is_file(): die(f"unsafe/missing file: {p}")
def main():
 if len(sys.argv)!=5: die("usage: verify_manual_db_bundle.py ROOT CANDIDATE CONTROL EXTERNAL_TRUST")
 root=pathlib.Path(sys.argv[1]).resolve(); candidate,control=sys.argv[2:4]; external=pathlib.Path(sys.argv[4])
 if candidate!=CANDIDATE or len(control)!=40 or any(c not in "0123456789abcdef" for c in control): die("SHA binding mismatch")
 regular(external)
 if sha(external)!=TRUST_SHA: die("external trust is not canonical")
 meta=root/"BUNDLE-METADATA.json"; sig=root/"BUNDLE-METADATA.json.ci.sig"; regular(meta); regular(sig)
 # Authenticate authority and signed inventory before parsing any attacker-controlled sums.
 with meta.open("rb") as source:
  subprocess.run(["ssh-keygen","-Y","verify","-f",str(external),"-I","icom-deploy-ci","-n","icom-db-migration-ci","-s",str(sig)],stdin=source,check=True,stdout=subprocess.DEVNULL)
 doc=json.loads(meta.read_text())
 if doc.get("candidate_sha")!=candidate or doc.get("trusted_control_sha")!=control or doc.get("execution_control_sha")!="96722ad7c5c285deb4c636dfff76e6cefa7e5c04": die("metadata provenance mismatch")
 if doc.get("review_evidence_sha256")!=REVIEWS_SHA or doc.get("package_order")!=ORDER or doc.get("authorized_operations")!=["forward","verify"] or doc.get("sql_executed") is not False: die("metadata scope mismatch")
 if doc.get("payload_inventory_exclusions")!=EXCLUDED: die("inventory exclusion mismatch")
 items=[]
 for p in sorted(root.rglob("*")):
  if p.is_symlink(): die("symlink forbidden")
  if p.is_dir(): continue
  if not p.is_file(): die("non-regular payload")
  rel=p.relative_to(root).as_posix()
  if rel not in EXCLUDED: items.append({"path":rel,"sha256":sha(p)})
 raw=json.dumps(items,sort_keys=True,separators=(",",":")).encode()
 if len(items)!=doc.get("payload_file_count") or hashlib.sha256(raw).hexdigest()!=doc.get("payload_inventory_sha256"): die("signed payload census mismatch")
 bundled=root/"trust/ci-allowed-signers"; regular(bundled)
 if sha(bundled)!=TRUST_SHA or bundled.read_bytes()!=external.read_bytes(): die("bundled trust mismatch")
 sums=root/"BUNDLE.SHA256SUMS"; regular(sums)
 expected={p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file() and not p.is_symlink() and p!=sums}
 declared={}
 for line in sums.read_text(encoding="utf-8").splitlines():
  match=re.fullmatch(r"([0-9a-f]{64})  (\./[^\n]+)",line)
  if not match: die("non-canonical checksum line")
  digest,raw_path=match.groups(); rel=raw_path[2:]; path=pathlib.PurePosixPath(rel)
  if path.is_absolute() or not rel or ".." in path.parts or "." in path.parts or path.as_posix()!=rel or rel in declared: die("unsafe/duplicate checksum path")
  declared[rel]=digest
 if set(declared)!=expected: die("checksum census mismatch")
 for rel,digest in declared.items():
  path=root/rel; regular(path)
  if sha(path)!=digest: die("bundle checksum mismatch")
 supersession=root/"LEGACY-RESERVATION-SUPERSESSION.json"; supersession_sig=root/"LEGACY-RESERVATION-SUPERSESSION.json.ci.sig"
 regular(supersession); regular(supersession_sig)
 if doc.get("legacy_reservation_supersession_sha256")!=sha(supersession): die("supersession metadata mismatch")
 with supersession.open("rb") as source:
  subprocess.run(["ssh-keygen","-Y","verify","-f",str(external),"-I","icom-deploy-ci","-n","icom-db-migration-ci","-s",str(supersession_sig)],stdin=source,check=True,stdout=subprocess.DEVNULL)
 sup=json.loads(supersession.read_text())
 expected={"schema_version":1,"legacy_release_id":400681564,"legacy_tag":"manual-db/fulfillment/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/b589d4d92200ac393a04344f2f203efe7f177e6a","legacy_control_sha":"b589d4d92200ac393a04344f2f203efe7f177e6a","candidate_sha":CANDIDATE,"prior_durable_release_assets_empty_at_supersession":True,"trusted_mint_attempt1_signing_step":"skipped","trusted_mint_attempt1_staging_step":"skipped","earlier_trusted_runs_validation_only":[36816248037,36821338542],"legacy_run_evidence_sha256":"3348b663365841c3f0fc9e8c94eebc507ffc40c210ba9e661021f976ea043b2f","superseded_by_control":control,"reason":"pre-sign draft-discovery 404"}
 if sup!=expected: die("legacy supersession binding mismatch")
 run_evidence=root/"LEGACY-RUN-EVIDENCE.json"; run_evidence_sig=root/"LEGACY-RUN-EVIDENCE.json.ci.sig"
 regular(run_evidence); regular(run_evidence_sig)
 if sha(run_evidence)!="3348b663365841c3f0fc9e8c94eebc507ffc40c210ba9e661021f976ea043b2f" or doc.get("legacy_run_evidence_sha256")!=sha(run_evidence): die("legacy run evidence mismatch")
 with run_evidence.open("rb") as source:
  subprocess.run(["ssh-keygen","-Y","verify","-f",str(external),"-I","icom-deploy-ci","-n","icom-db-migration-ci","-s",str(run_evidence_sig)],stdin=source,check=True,stdout=subprocess.DEVNULL)
 evidence=root/"PROTECTED-REVIEW-EVIDENCE.json"; regular(evidence)
 if sha(evidence)!=REVIEWS_SHA: die("review evidence mismatch")
 for slug,want in zip(ORDER,MANIFESTS):
  manifest=root/"docs/deploy-candidates"/slug/"candidate-manifest.json"; msig=pathlib.Path(str(manifest)+".ci.sig")
  regular(manifest); regular(msig)
  if sha(manifest)!=want: die("manifest mismatch")
  with manifest.open("rb") as source:
   subprocess.run(["ssh-keygen","-Y","verify","-f",str(external),"-I","icom-deploy-ci","-n","icom-db-migration-ci","-s",str(msig)],stdin=source,check=True,stdout=subprocess.DEVNULL)
 print("MANUAL_DB_BUNDLE_VERIFY=PASS")
if __name__=="__main__": main()
