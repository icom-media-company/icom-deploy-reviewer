#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; WF="$ROOT/.github/workflows/manual-db-fulfillment-signer.yml"; V="$ROOT/trusted/manual_db_validate.py"; M="$ROOT/trusted/mint_manual_db_bundle.sh"
ARCHIVE="$ROOT/trusted/archive_validate.py"; SELECT="$ROOT/trusted/select_staging_artifact.py"
DECIDE="$ROOT/trusted/decide_mint_state.py"; ASSETS="$ROOT/trusted/verify_release_assets.py"
RESERVATION="$ROOT/trusted/verify_reservation.py"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "PASS $1"; }; bad(){ FAIL=$((FAIL+1)); echo "FAIL $1" >&2; }
has(){ grep -Fq "$2" "$1"; }
has "$WF" '[ "$GITHUB_REPOSITORY" = icom-media-company/icom-deploy-reviewer ]' && has "$WF" '[ "$GITHUB_REF" = refs/heads/main ]' && ok A_protected_repo_ref || bad A_protected_repo_ref
has "$WF" 'GITHUB_TRIGGERING_ACTOR' && has "$WF" 'ICOM_MANUAL_DB_AUTHORIZED_ACTOR' && ok B_unauthorized_caller_rejected || bad B_unauthorized_caller_rejected
has "$WF" 'environment: read-business' && has "$WF" 'ICOM_BUSINESS_READ_TOKEN' && ok C_read_only_business_boundary || bad C_read_only_business_boundary
! grep -Eq '(bash|source|chmod \+x).*candidate' "$WF" && has "$WF" 'as data only' && ok D_candidate_never_executed || bad D_candidate_never_executed
validate_block="$(sed -n '/^  validate-data:/,/^  mint:/p' "$WF")"; ! grep -q 'ICOM_DEPLOY_CI_SIGNING_KEY\|manual-db-sign' <<<"$validate_block" && ok E_validation_has_no_signing_secret || bad E_validation_has_no_signing_secret
mint_block="$(sed -n '/^  mint:/,$p' "$WF")"; grep -q 'environment: manual-db-sign' <<<"$mint_block" && grep -q 'ICOM_DEPLOY_CI_SIGNING_KEY' <<<"$mint_block" && ok F_mint_secret_isolated || bad F_mint_secret_isolated
fetch_block="$(sed -n '/name: Fetch exact business candidate/,/uses: actions\/upload-artifact/p' "$WF")"; [ "$(grep -c 'ICOM_BUSINESS_READ_TOKEN' "$WF")" -eq 1 ] && grep -q 'ICOM_BUSINESS_READ_TOKEN' <<<"$fetch_block" && ok F2_business_token_fetch_step_only || bad F2_business_token_fetch_step_only
has "$V" 'd0819f7bacf5ee6dedca4345796a8d022ff6a5cc' && [ "$(grep -c '20261001-.*-[0-9][0-9]' "$V")" -ge 4 ] && ok G_exact_candidate_and_order || bad G_exact_candidate_and_order
has "$V" 'd["authorization"]["operations"] != ["forward","verify"]' && ok H_rollback_not_authorized || bad H_rollback_not_authorized
has "$V" 'pinned package mismatch' && has "$V" 'SQL hash mismatch' && has "$V" 'document hash mismatch' && ok I_hash_mutations_fail_closed || bad I_hash_mutations_fail_closed
has "$WF" 'gh release view' && has "$WF" 'gh release create' && has "$WF" 'concurrency:' && ok J_durable_exactly_once_gate || bad J_durable_exactly_once_gate
! rg -n 'psql|supabase db push|apply_migration' "$WF" "$V" "$M" && ok K_no_database_execution || bad K_no_database_execution
[ "$(sha256sum "$ROOT/trusted/ci-allowed-signers"|awk '{print $1}')" = 704dc47b50f2ebbb8515b400bde88a943d967f313255a85a5bd4b1534177acd9 ] && ok L_existing_ci_trust_compatible || bad L_existing_ci_trust_compatible
! grep -n "run:.*\${{ inputs\.\|^[[:space:]]*.*'\${{ inputs\." "$WF" >/dev/null && ok M_inputs_not_interpolated_in_shell || bad M_inputs_not_interpolated_in_shell
has "$WF" 'select_staging_artifact.py' && has "$SELECT" 'run.get("status")!="completed"' && has "$WF" 'manual-db-bundle.tar.gz.sha256' && ok N_crash_safe_recovery || bad N_crash_safe_recovery
has "$WF" 'verify_release_ref.py' && has "$WF" 'Verify permanent release bytes' && has "$WF" 'repeat mint denied' && ok O_durable_release_verified || bad O_durable_release_verified
has "$M" 'PROTECTED-REVIEW-EVIDENCE.json' && has "$V" 'protected review evidence hash mismatch' && has "$V" 'review evidence subject mismatch' && ok P_review_artifact_bound || bad P_review_artifact_bound
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
python3 - "$tmp" <<'PY'
import io,tarfile,zipfile,pathlib,sys
r=pathlib.Path(sys.argv[1])
with tarfile.open(r/'bad.tar.gz','w:gz') as t:
 x=tarfile.TarInfo('../escape'); x.size=1; t.addfile(x,io.BytesIO(b'x'))
with zipfile.ZipFile(r/'dup.zip','w') as z:
 z.writestr('a/../x','x'); z.writestr('x','y')
with tarfile.open(r/'special.tar.gz','w:gz') as t:
 for name,kind in [('link',tarfile.SYMTYPE),('pipe',tarfile.FIFOTYPE),('device',tarfile.CHRTYPE)]:
  x=tarfile.TarInfo(name); x.type=kind; x.linkname='target'; t.addfile(x)
PY
! "$ARCHIVE" tar "$tmp/bad.tar.gz" >/dev/null 2>&1 && ! "$ARCHIVE" zip "$tmp/dup.zip" >/dev/null 2>&1 && ! "$ARCHIVE" tar "$tmp/special.tar.gz" >/dev/null 2>&1 && ok Q_archive_mutations_rejected || bad Q_archive_mutations_rejected
cat > "$tmp/artifacts.json" <<JSON
{"artifacts":[{"id":7,"name":"manual-db-stage-d0819f7bacf5ee6dedca4345796a8d022ff6a5cc-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","expired":false,"workflow_run":{"id":9,"head_sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}]}
JSON
cat > "$tmp/run.json" <<JSON
{"id":9,"head_sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","head_branch":"main","event":"workflow_dispatch","path":".github/workflows/manual-db-fulfillment-signer.yml","status":"in_progress"}
JSON
! "$SELECT" "$tmp/artifacts.json" "$tmp/run.json" manual-db-stage-d0819f7bacf5ee6dedca4345796a8d022ff6a5cc-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa d0819f7bacf5ee6dedca4345796a8d022ff6a5cc aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa >/dev/null 2>&1 && ok R_incomplete_run_rejected || bad R_incomplete_run_rejected
mkdir "$tmp/trusted"; cp "$V" "$tmp/trusted/"; cp "$ROOT/trusted/manual-db-review-bindings.json" "$tmp/trusted/"
sed -i.bak 's/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/' "$tmp/trusted/manual-db-review-bindings.json"
! "$tmp/trusted/manual_db_validate.py" d0819f7bacf5ee6dedca4345796a8d022ff6a5cc /tmp/icom-db-package >/dev/null 2>&1 && ok S_swapped_review_candidate_rejected || bad S_swapped_review_candidate_rejected
mkdir "$tmp/empty"; printf 'attacker ssh-ed25519 AAAA\n' > "$tmp/attacker-trust"
! "$ROOT/trusted/verify_manual_db_bundle.py" "$tmp/empty" d0819f7bacf5ee6dedca4345796a8d022ff6a5cc aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa "$tmp/attacker-trust" >/dev/null 2>&1 && ok T_external_trust_precedes_bundle_signature || bad T_external_trust_precedes_bundle_signature
[ "$("$DECIDE" true true true absent)" = new ] && [ "$("$DECIDE" false true true absent)" = resume_idempotent ] && [ "$("$DECIDE" false true true absent)" != new ] && [ "$("$DECIDE" false true true verified)" = recover ] && ok U_reservation_crashes_resume_same_identity || bad U_reservation_crashes_resume_same_identity
cat > "$tmp/release-good.json" <<'JSON'
{"draft":false,"assets":[{"name":"manual-db-bundle.tar.gz.sha256"},{"name":"manual-db-bundle.tar.gz"}]}
JSON
cat > "$tmp/release-extra.json" <<'JSON'
{"draft":false,"assets":[{"name":"manual-db-bundle.tar.gz.sha256"},{"name":"manual-db-bundle.tar.gz"},{"name":"evil"}]}
JSON
"$ASSETS" "$tmp/release-good.json" && ! "$ASSETS" "$tmp/release-extra.json" >/dev/null 2>&1 && ok V_release_asset_exact_census || bad V_release_asset_exact_census
cp -R "$ROOT/trusted" "$tmp/repro-control"
ssh-keygen -q -t ed25519 -N '' -C '' -f "$tmp/repro-key"
pub="$(ssh-keygen -y -f "$tmp/repro-key" | awk '{print $1" "$2}')"
printf 'icom-deploy-ci %s\n' "$pub" > "$tmp/repro-control/ci-allowed-signers"
"$tmp/repro-control/mint_manual_db_bundle.sh" /tmp/icom-db-package d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 "$tmp/repro-key" "$tmp/build-one" >/dev/null
"$tmp/repro-control/mint_manual_db_bundle.sh" /tmp/icom-db-package d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 "$tmp/repro-key" "$tmp/build-two" >/dev/null
"$ROOT/trusted/create_reproducible_tar.py" "$tmp/build-one" "$tmp/one.tar.gz"
"$ROOT/trusted/create_reproducible_tar.py" "$tmp/build-two" "$tmp/two.tar.gz"
diff -qr "$tmp/build-one" "$tmp/build-two" >/dev/null && cmp "$tmp/one.tar.gz" "$tmp/two.tar.gz" >/dev/null && ok W_ed25519_signatures_and_archive_reproducible || bad W_ed25519_signatures_and_archive_reproducible
ssh-keygen -q -t ed25519 -N '' -C '' -f "$tmp/wrong-key"
ssh-keygen -q -t rsa -b 2048 -N '' -C '' -f "$tmp/rsa-key"
! "$tmp/repro-control/mint_manual_db_bundle.sh" /tmp/icom-db-package d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 "$tmp/wrong-key" "$tmp/wrong-build" >/dev/null 2>&1 \
 && ! "$tmp/repro-control/mint_manual_db_bundle.sh" /tmp/icom-db-package d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 "$tmp/rsa-key" "$tmp/rsa-build" >/dev/null 2>&1 \
 && ok X_wrong_and_non_ed25519_keys_rejected || bad X_wrong_and_non_ed25519_keys_rejected
cat > "$tmp/reservation.json" <<'JSON'
{"draft":true,"tag_name":"manual-db/fulfillment/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/1111111111111111111111111111111111111111","name":"RESERVED trusted manual DB package","body":"candidate=d0819f7bacf5ee6dedca4345796a8d022ff6a5cc control=1111111111111111111111111111111111111111; absent staging may resume only with byte-identical deterministic mint"}
JSON
"$RESERVATION" "$tmp/reservation.json" d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111
sed 's/byte-identical/different/' "$tmp/reservation.json" > "$tmp/reservation-bad.json"
! "$RESERVATION" "$tmp/reservation-bad.json" d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 >/dev/null 2>&1 && ok Y_exact_reservation_identity || bad Y_exact_reservation_identity
echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
