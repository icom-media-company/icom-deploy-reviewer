#!/usr/bin/env bash
set -euo pipefail
die(){ echo "[trusted-db-mint] FAIL: $*" >&2; exit 1; }
[ "$#" -eq 5 ] || die "usage: $0 <candidate-root> <candidate-sha> <control-sha> <ci-key> <out>"
ROOT="$1"; CANDIDATE="$2"; CONTROL="$3"; KEY="$4"; OUT="$5"; HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
[ "$CANDIDATE" = d0819f7bacf5ee6dedca4345796a8d022ff6a5cc ] || die "candidate mismatch"
echo "$CONTROL" | grep -Eq '^[0-9a-f]{40}$' || die "control SHA malformed"
[ -f "$KEY" ] && [ ! -e "$OUT" ] || die "key missing or output exists"
REPORT="$("$HERE/manual_db_validate.py" "$CANDIDATE" "$ROOT")"
mkdir -p "$OUT/docs/deploy-candidates" "$OUT/supabase/migrations" "$OUT/scripts" "$OUT/trust"
printf '%s\n' 20261001-fulfillment-retry-90 20261001-pgsodium-prerequisite-91 20261001-fulfillment-historical-evidence-92 20261001-mto-claim-93 > "$OUT/BUNDLE-ORDER.txt"
printf '%s\n' "$REPORT" > "$OUT/TRUSTED-REVIEW-BINDINGS.json"
cp "$HERE/ci-allowed-signers" "$OUT/trust/"
cp "$ROOT/scripts/run-fulfillment-recovery-db-package.sh" "$OUT/scripts/"
for slug in 20261001-fulfillment-retry-90 20261001-pgsodium-prerequisite-91 20261001-fulfillment-historical-evidence-92 20261001-mto-claim-93; do
 src="$ROOT/docs/deploy-candidates/$slug"; dst="$OUT/docs/deploy-candidates/$slug"; mkdir -p "$dst"
 cp "$src"/{candidate-manifest.json,RUNBOOK.md,PACKAGE.SHA256SUMS,SQL.SHA256SUMS,owner-authorization-request.json} "$dst/"
 ssh-keygen -Y sign -q -f "$KEY" -n icom-db-migration-ci "$dst/candidate-manifest.json"
 mv "$dst/candidate-manifest.json.sig" "$dst/candidate-manifest.json.ci.sig"
 ssh-keygen -Y verify -f "$HERE/ci-allowed-signers" -I icom-deploy-ci -n icom-db-migration-ci -s "$dst/candidate-manifest.json.ci.sig" < "$dst/candidate-manifest.json" >/dev/null
 while IFS= read -r rel; do cp "$ROOT/$rel" "$OUT/supabase/migrations/"; done < <(jq -r '.artifacts[].path' "$src/candidate-manifest.json")
done
read -r INV COUNT < <(python3 - "$OUT" <<'PY'
import hashlib,json,pathlib,sys
r=pathlib.Path(sys.argv[1]); items=[]
for p in sorted(r.rglob("*")):
 if p.is_symlink(): raise SystemExit("symlink forbidden")
 if p.is_file(): items.append({"path":p.relative_to(r).as_posix(),"sha256":hashlib.sha256(p.read_bytes()).hexdigest()})
raw=json.dumps(items,sort_keys=True,separators=(",",":")).encode(); print(hashlib.sha256(raw).hexdigest(),len(items))
PY
)
jq -n --arg candidate "$CANDIDATE" --arg control "$CONTROL" --arg inventory "$INV" --argjson count "$COUNT" \
 '{schema_version:1,candidate_sha:$candidate,trusted_control_sha:$control,package_order:["20261001-fulfillment-retry-90","20261001-pgsodium-prerequisite-91","20261001-fulfillment-historical-evidence-92","20261001-mto-claim-93"],authorized_operations:["forward","verify"],payload_inventory_sha256:$inventory,payload_file_count:$count,sql_executed:false}' > "$OUT/BUNDLE-METADATA.json"
ssh-keygen -Y sign -q -f "$KEY" -n icom-db-migration-ci "$OUT/BUNDLE-METADATA.json"; mv "$OUT/BUNDLE-METADATA.json.sig" "$OUT/BUNDLE-METADATA.json.ci.sig"
(cd "$OUT" && find . -type f ! -name BUNDLE.SHA256SUMS -exec sha256sum {} + | LC_ALL=C sort) > "$OUT/BUNDLE.SHA256SUMS"
