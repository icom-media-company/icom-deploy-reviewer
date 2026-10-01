#!/usr/bin/env bash
set -euo pipefail
die(){ echo "[trusted-db-mint] FAIL: $*" >&2; exit 1; }
[ "$#" -eq 6 ] || die "usage: $0 <candidate-root> <candidate-sha> <control-sha> <ci-key> <out> <legacy-run-evidence>"
ROOT="$1"; CANDIDATE="$2"; CONTROL="$3"; KEY="$4"; OUT="$5"; LEGACY_EVIDENCE="$6"; HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
[ "$CANDIDATE" = d0819f7bacf5ee6dedca4345796a8d022ff6a5cc ] || die "candidate mismatch"
echo "$CONTROL" | grep -Eq '^[0-9a-f]{40}$' || die "control SHA malformed"
[ -f "$KEY" ] && [ ! -e "$OUT" ] || die "key missing or output exists"
EXPECTED_KEY="$(awk 'NF==3 && $1=="icom-deploy-ci" && $2=="ssh-ed25519" {print $2" "$3}' "$HERE/ci-allowed-signers")"
[ -n "$EXPECTED_KEY" ] || die "canonical allowed signer is not exactly one ssh-ed25519 key"
ACTUAL_KEY="$(ssh-keygen -y -f "$KEY" 2>/dev/null | awk 'NR==1 && NF>=2 {print $1" "$2}')" || die "cannot derive signing public key"
case "$ACTUAL_KEY" in ssh-ed25519\ *) ;; *) die "signing key is not ssh-ed25519" ;; esac
[ "$ACTUAL_KEY" = "$EXPECTED_KEY" ] || die "signing key does not match canonical allowed signer"
[ -f "$LEGACY_EVIDENCE" ] && [ ! -L "$LEGACY_EVIDENCE" ] || die "legacy run evidence missing/unsafe"
[ "$(sha256sum "$LEGACY_EVIDENCE" | awk '{print $1}')" = 57b418667e80adf9ef0932308af202d3448342ceae342454f7417cb438ddce47 ] || die "legacy run evidence mismatch"
REPORT="$("$HERE/manual_db_validate.py" "$CANDIDATE" "$ROOT")"
mkdir -p "$OUT/docs/deploy-candidates" "$OUT/supabase/migrations" "$OUT/scripts" "$OUT/trust"
printf '%s\n' 20261001-fulfillment-retry-90 20261001-pgsodium-prerequisite-91 20261001-fulfillment-historical-evidence-92 20261001-mto-claim-93 > "$OUT/BUNDLE-ORDER.txt"
printf '%s\n' "$REPORT" > "$OUT/TRUSTED-REVIEW-BINDINGS.json"
cp "$HERE/manual-db-review-bindings.json" "$OUT/PROTECTED-REVIEW-EVIDENCE.json"
cp "$HERE/REVIEW-REGISTRY.md" "$OUT/"
cp "$HERE/MINT-IDEMPOTENCY.md" "$OUT/"
cp "$HERE/ci-allowed-signers" "$OUT/trust/"
cp "$ROOT/scripts/run-fulfillment-recovery-db-package.sh" "$OUT/scripts/"
cp "$HERE/OWNER-CEREMONY.md" "$OUT/"
cp "$LEGACY_EVIDENCE" "$OUT/LEGACY-RUN-EVIDENCE.json"
ssh-keygen -Y sign -q -f "$KEY" -n icom-db-migration-ci "$OUT/LEGACY-RUN-EVIDENCE.json"
mv "$OUT/LEGACY-RUN-EVIDENCE.json.sig" "$OUT/LEGACY-RUN-EVIDENCE.json.ci.sig"
ssh-keygen -Y verify -f "$HERE/ci-allowed-signers" -I icom-deploy-ci -n icom-db-migration-ci -s "$OUT/LEGACY-RUN-EVIDENCE.json.ci.sig" < "$OUT/LEGACY-RUN-EVIDENCE.json" >/dev/null
jq -n --arg new_control "$CONTROL" '{schema_version:1,legacy_release_id:400681564,legacy_tag:"manual-db/fulfillment/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/b589d4d92200ac393a04344f2f203efe7f177e6a",legacy_control_sha:"b589d4d92200ac393a04344f2f203efe7f177e6a",candidate_sha:"d0819f7bacf5ee6dedca4345796a8d022ff6a5cc",prior_durable_release_assets_empty_at_supersession:true,trusted_mint_attempt1_signing_step:"skipped",trusted_mint_attempt1_staging_step:"skipped",no_trusted_signing_workflow_run_before_release_creation:true,legacy_run_evidence_sha256:"57b418667e80adf9ef0932308af202d3448342ceae342454f7417cb438ddce47",superseded_by_control:$new_control,reason:"pre-sign draft-discovery 404"}' > "$OUT/LEGACY-RESERVATION-SUPERSESSION.json"
"$HERE/verify_supersession.py" "$OUT/LEGACY-RESERVATION-SUPERSESSION.json" "$CONTROL"
ssh-keygen -Y sign -q -f "$KEY" -n icom-db-migration-ci "$OUT/LEGACY-RESERVATION-SUPERSESSION.json"
mv "$OUT/LEGACY-RESERVATION-SUPERSESSION.json.sig" "$OUT/LEGACY-RESERVATION-SUPERSESSION.json.ci.sig"
ssh-keygen -Y verify -f "$HERE/ci-allowed-signers" -I icom-deploy-ci -n icom-db-migration-ci -s "$OUT/LEGACY-RESERVATION-SUPERSESSION.json.ci.sig" < "$OUT/LEGACY-RESERVATION-SUPERSESSION.json" >/dev/null
for slug in 20261001-fulfillment-retry-90 20261001-pgsodium-prerequisite-91 20261001-fulfillment-historical-evidence-92 20261001-mto-claim-93; do
 src="$ROOT/docs/deploy-candidates/$slug"; dst="$OUT/docs/deploy-candidates/$slug"; mkdir -p "$dst"
 cp "$src"/{candidate-manifest.json,RUNBOOK.md,PACKAGE.SHA256SUMS,SQL.SHA256SUMS,owner-authorization-request.json} "$dst/"
 ssh-keygen -Y sign -q -f "$KEY" -n icom-db-migration-ci "$dst/candidate-manifest.json"
 mv "$dst/candidate-manifest.json.sig" "$dst/candidate-manifest.json.ci.sig"
 ssh-keygen -Y verify -f "$HERE/ci-allowed-signers" -I icom-deploy-ci -n icom-db-migration-ci -s "$dst/candidate-manifest.json.ci.sig" < "$dst/candidate-manifest.json" >/dev/null
 while IFS= read -r rel; do cp "$ROOT/$rel" "$OUT/supabase/migrations/"; done < <(jq -r '.artifacts[].path' "$src/candidate-manifest.json")
done
SUPERSESSION_SHA="$(sha256sum "$OUT/LEGACY-RESERVATION-SUPERSESSION.json" | awk '{print $1}')"
read -r INV COUNT < <(python3 - "$OUT" <<'PY'
import hashlib,json,pathlib,sys
r=pathlib.Path(sys.argv[1]); items=[]
for p in sorted(r.rglob("*")):
 if p.is_symlink(): raise SystemExit("symlink forbidden")
 if p.is_file(): items.append({"path":p.relative_to(r).as_posix(),"sha256":hashlib.sha256(p.read_bytes()).hexdigest()})
raw=json.dumps(items,sort_keys=True,separators=(",",":")).encode(); print(hashlib.sha256(raw).hexdigest(),len(items))
PY
)
jq -n --arg candidate "$CANDIDATE" --arg control "$CONTROL" --arg inventory "$INV" --arg supersession "$SUPERSESSION_SHA" --argjson count "$COUNT" \
 '{schema_version:1,candidate_sha:$candidate,trusted_control_sha:$control,execution_control_sha:"96722ad7c5c285deb4c636dfff76e6cefa7e5c04",review_evidence_sha256:"8144533067199f1df88b7ec2a7623275d9934feeaebd48f14b4dfa329dc12bc9",legacy_run_evidence_sha256:"57b418667e80adf9ef0932308af202d3448342ceae342454f7417cb438ddce47",legacy_reservation_supersession_sha256:$supersession,package_order:["20261001-fulfillment-retry-90","20261001-pgsodium-prerequisite-91","20261001-fulfillment-historical-evidence-92","20261001-mto-claim-93"],authorized_operations:["forward","verify"],payload_inventory_exclusions:["BUNDLE-METADATA.json","BUNDLE-METADATA.json.ci.sig","BUNDLE.SHA256SUMS"],payload_inventory_sha256:$inventory,payload_file_count:$count,sql_executed:false}' > "$OUT/BUNDLE-METADATA.json"
ssh-keygen -Y sign -q -f "$KEY" -n icom-db-migration-ci "$OUT/BUNDLE-METADATA.json"; mv "$OUT/BUNDLE-METADATA.json.sig" "$OUT/BUNDLE-METADATA.json.ci.sig"
(cd "$OUT" && find . -type f ! -name BUNDLE.SHA256SUMS -exec sha256sum {} + | LC_ALL=C sort) > "$OUT/BUNDLE.SHA256SUMS"
