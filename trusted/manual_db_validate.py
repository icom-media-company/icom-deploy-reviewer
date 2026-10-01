#!/usr/bin/env python3
import hashlib, json, pathlib, re, sys

CANDIDATE = "d0819f7bacf5ee6dedca4345796a8d022ff6a5cc"
PACKAGES = [
 ("20261001-fulfillment-retry-90","2dff21f4ddb83ea52905420994c238eaf517e9bbbb6009b6086db87356612f44","1290240924dd8784688b75241f1c597351588e713417a00a75d2cbc0aa8047c9"),
 ("20261001-pgsodium-prerequisite-91","0cb36140d395a8c3b8468485e13ab91e25d75a966cef93300b90e5009c5da6fa","ae4f3dbfff64ebdd985146f30fc8961a34056ffbc736ddf752b4f00b5843285e"),
 ("20261001-fulfillment-historical-evidence-92","f4a4f6e4ae1a5bfa0d441829cf7bb68dd8d6c81ce1a8c28a6e653bba70b8873e","bb16069c14dbc6897550cf6a7cc16955de4037972358211fe1cd52bf3bf295e5"),
 ("20261001-mto-claim-93","24882dc7d6d450c1b2c86638ca9084dbd7e67302684518fd9c2f352dacfa3b65","c2999fc1b1a3bf0c8b27e63d6a931b8012ccd48e56e08a56d16e7ce17c3ec3da"),
]
FINAL = [
 ("d9bd400da322eacf97b33c5971523495948822e0","474f6897742663525ce8ea80cba92381887811c8f6c3afa4191205e8f546a57f","f0717a75f6aef108c40ee1ae4a9cece1baeee1a9","fbf7414c41751e10f4056d3d658f660a2074d36c20a49434bf5da4dc76fee2fb"),
 ("97cd036151b4b7db38b22b1bc0617a4ed66e91a1","91bbce7c3be7b1246c76e2c0602d4748d3490bc447109659cc1a2587871a7186","7e632b04b3006ffccd093de2199777ee9ec1f043","71ebfce96e1df044400c8efdcc0b4328c19306d812e1e5fcbcb6e0fa4042e34a"),
 ("6e5927af5597eaa748998e5ff3b4f0ea8bcb6005","a4d6049ed6fead7e6da17aac87d84b6dc32f0cd0c49ae91347b4c25f15d4b96d","ac2516879241cf97c24c5ec45c3759dab4fbf493","b4b6cd28a8ea5070069fbee021f35e7fcf2d22a0f20746c1220e7cf48ba0593e"),
 ("2c0ecb3c600f2e8282f374420ded00dbecf6f78d","2dd91dd9e390e2f677fe4b6e3cef3b43120fd42896deeaae38aa78fb477d009f","35a73b60e630c7a9623c4a9f215b43b1db67f746","e2bae2d9fa9324cc01b4ab3bca2f7e618ce320e3bceddd5bceaf5325f13b5d11"),
]
ROOT_KEYS={"manifest_schema_version","candidate_id","candidate_type","status","created_at","scope","repository_lineage","production_database_lineage","artifacts","documents","execution_contract","execution_notes","review_evidence","authorization","production_mutation_count"}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p): return json.loads(p.read_text(), object_pairs_hook=lambda x: unique(x,p))
def unique(pairs,p):
 d={}
 for k,v in pairs:
  if k in d: raise SystemExit(f"duplicate JSON key in {p}: {k}")
  d[k]=v
 return d
def safe(root, rel):
 p=(root/rel).resolve(); p.relative_to(root.resolve())
 if not p.is_file() or p.is_symlink(): raise SystemExit(f"unsafe/missing file {rel}")
 return p
def main():
 if len(sys.argv)!=3 or sys.argv[1]!=CANDIDATE: raise SystemExit("exact candidate SHA required")
 root=pathlib.Path(sys.argv[2]); report=[]
 evidence_path=pathlib.Path(__file__).with_name("manual-db-review-bindings.json")
 if sha(evidence_path)!="8144533067199f1df88b7ec2a7623275d9934feeaebd48f14b4dfa329dc12bc9": raise SystemExit("protected review evidence hash mismatch")
 evidence=load(evidence_path)
 if evidence.get("candidate_sha")!=CANDIDATE or len(evidence.get("packages",[]))!=4: raise SystemExit("review evidence candidate mismatch")
 for idx,(slug,mhash,phash) in enumerate(PACKAGES):
  package=root/"docs/deploy-candidates"/slug; manifest=package/"candidate-manifest.json"
  if sha(manifest)!=mhash or sha(package/"PACKAGE.SHA256SUMS")!=phash: raise SystemExit(f"pinned package mismatch: {slug}")
  d=load(manifest)
  if set(d)!=ROOT_KEYS or d["manifest_schema_version"]!=2 or d["candidate_type"]!="manual_database_migration": raise SystemExit("schema-v2 mismatch")
  if d["authorization"]["operations"] != ["forward","verify"] or d["authorization"].get("signature_present") is not False: raise SystemExit("operations mismatch")
  if d["production_mutation_count"] != 0: raise SystemExit("mutation count mismatch")
  if d["production_database_lineage"]["latest_schema_migration_version"]!="20260928110089": raise SystemExit("lineage mismatch")
  roles={x["role"]:x for x in d["artifacts"]}
  if set(roles)!={"forward","verify","rollback"}: raise SystemExit("artifact roles mismatch")
  for item in d["artifacts"]:
   if sha(safe(root,item["path"]))!=item["sha256"]: raise SystemExit("SQL hash mismatch")
  docs={x["role"]:x for x in d["documents"]}
  if set(docs)!={"runbook","package_checksums","sql_checksums","owner_request"}: raise SystemExit("document roles mismatch")
  for item in d["documents"]:
   if sha(safe(root,item["path"]))!=item["sha256"]: raise SystemExit("document hash mismatch")
  review=d["review_evidence"]
  for role in ("general_review","critical_review"):
   if review[role]["verdict"]!="PASS" or not re.fullmatch(r"[0-9a-f]{40}",review[role]["review_id"]): raise SystemExit("substantive review mismatch")
  fg,fe,cg,ce=FINAL[idx]
  bound=evidence["packages"][idx]
  if bound.get("path")!=f"docs/deploy-candidates/{slug}" or bound.get("manifest_sha256")!=mhash or bound.get("subject_commit")!=CANDIDATE: raise SystemExit("review evidence subject mismatch")
  if (bound["final_general"]["review_id"],bound["final_general"]["evidence_sha256"],bound["final_critical"]["review_id"],bound["final_critical"]["evidence_sha256"])!=(fg,fe,cg,ce): raise SystemExit("review evidence binding mismatch")
  for name in ("substantive_general","substantive_critical","final_general","final_critical"):
   item=bound[name]; expected_role="general" if name.endswith("general") else "critical"
   if item.get("role")!=expected_role or item.get("verdict")!="PASS": raise SystemExit("review evidence role/verdict mismatch")
  report.append({"path":f"docs/deploy-candidates/{slug}","manifest_sha256":mhash,"final_general":{"review_id":fg,"evidence_sha256":fe,"verdict":"PASS"},"final_critical":{"review_id":cg,"evidence_sha256":ce,"verdict":"PASS"}})
 print(json.dumps({"candidate_sha":CANDIDATE,"order":[x[0] for x in PACKAGES],"packages":report},sort_keys=True,separators=(",",":")))
if __name__=="__main__": main()
