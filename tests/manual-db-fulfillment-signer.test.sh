#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; WF="$ROOT/.github/workflows/manual-db-fulfillment-signer.yml"; V="$ROOT/trusted/manual_db_validate.py"; M="$ROOT/trusted/mint_manual_db_bundle.sh"
ARCHIVE="$ROOT/trusted/archive_validate.py"; SELECT="$ROOT/trusted/select_staging_artifact.py"
DECIDE="$ROOT/trusted/decide_mint_state.py"; ASSETS="$ROOT/trusted/verify_release_assets.py"
RESERVATION="$ROOT/trusted/verify_reservation.py"
SELECT_RELEASE="$ROOT/trusted/select_release.py"
LEGACY="$ROOT/trusted/verify_legacy_reservation.py"; REF="$ROOT/trusted/verify_release_ref.py"
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
has "$WF" 'select_release.py' && has "$WF" 'releases/$RELEASE_ID' && has "$WF" 'concurrency:' && ! has "$WF" 'releases/tags/' && ok J_durable_exactly_once_gate || bad J_durable_exactly_once_gate
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
"$ASSETS" "$tmp/release-good.json" published && ! "$ASSETS" "$tmp/release-extra.json" published >/dev/null 2>&1 && ok V_release_asset_exact_census || bad V_release_asset_exact_census
cp -R "$ROOT/trusted" "$tmp/repro-control"
ssh-keygen -q -t ed25519 -N '' -C '' -f "$tmp/repro-key"
pub="$(ssh-keygen -y -f "$tmp/repro-key" | awk '{print $1" "$2}')"
printf 'icom-deploy-ci %s\n' "$pub" > "$tmp/repro-control/ci-allowed-signers"
cat > "$tmp/legacy-run-evidence.json" <<'JSON'
{"attempt1_failed_step":"Re-authorize signer and resolve durable state","attempt1_job_id":110237504710,"attempt1_run_id":36821369400,"attempt1_signing_step":"skipped","attempt1_staging_step":"skipped","attempt2_conclusion":"cancelled","earlier_trusted_runs":[{"effective_mode":"validation_only","jobs_sha256":"87a962c3d3642ac7fd252f385ece3fad01862a6bee7df2ae023a3e77d9f71243","mint_job":"skipped","run_id":36816248037,"run_sha256":"6b491e96ac2d129a9ad48d90df36bc33f995e0bf9cbc6a106e9d8d9e062101e5"},{"effective_mode":"validation_only","jobs_sha256":"33d193426feadaaf2092e2ca9561a081c542acf2b17f9f85d6ca227996920277","mint_job":"skipped","run_id":36821338542,"run_sha256":"84ad3bc2291031006d3c41376e51b8a8b501adade2da8effd3085728f627e6c9"}],"legacy_control_workflow_run_census":[{"listed_run_attempt":1,"run_id":36816248037,"verified_attempts":[1]},{"listed_run_attempt":1,"run_id":36821338542,"verified_attempts":[1]},{"listed_run_attempt":2,"run_id":36821369400,"verified_attempts":[1,2]}],"legacy_control_workflow_run_census_sha256":"4b88c868c5bbb6795c313918ae4bacbb2b6a79e4c01952bfd1de9a8933e38efd","legacy_release_assets_empty_at_supersession":true,"legacy_release_author":"github-actions[bot]","legacy_release_html_url":"https://github.com/icom-media-company/icom-deploy-reviewer/releases/tag/untagged-f9eb7bff73f2e9e57c0b","legacy_release_id":400681564,"legacy_release_tag":"manual-db/fulfillment/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/b589d4d92200ac393a04344f2f203efe7f177e6a","legacy_release_updated_at":"2026-10-01T05:47:07Z","legacy_tag_target":"b589d4d92200ac393a04344f2f203efe7f177e6a","post_create_lookup_http_status":404,"raw_sha256":{"attempt1_jobs":"6ee7d03e4c4948474ba8f6727937c1e1f0aacc80a543b2ebe5dcec26dd12d5f2","attempt1_logs_zip":"51c304d815452b48aad45337dcfcd9a60f4542f1100363f181e694370bb54c74","attempt1_run":"d5e1d7d2692f23c064e994e8b4d771e09118710366c907025943eb04474a496c","attempt2_run":"2d5a5561f00211af0b73be530d51bb75e6daf9d2868f431b857366dba22a1ca3"},"repository":"icom-media-company/icom-deploy-reviewer","schema_version":1,"workflow_id":371811486,"workflow_path":".github/workflows/manual-db-fulfillment-signer.yml"}
JSON
"$tmp/repro-control/mint_manual_db_bundle.sh" /tmp/icom-db-package d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 "$tmp/repro-key" "$tmp/build-one" "$tmp/legacy-run-evidence.json" >/dev/null
"$tmp/repro-control/mint_manual_db_bundle.sh" /tmp/icom-db-package d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 "$tmp/repro-key" "$tmp/build-two" "$tmp/legacy-run-evidence.json" >/dev/null
"$ROOT/trusted/create_reproducible_tar.py" "$tmp/build-one" "$tmp/one.tar.gz"
"$ROOT/trusted/create_reproducible_tar.py" "$tmp/build-two" "$tmp/two.tar.gz"
diff -qr "$tmp/build-one" "$tmp/build-two" >/dev/null && cmp "$tmp/one.tar.gz" "$tmp/two.tar.gz" >/dev/null \
 && test -f "$tmp/build-one/LEGACY-RESERVATION-SUPERSESSION.json.ci.sig" \
 && jq -e '.legacy_release_id==400681564 and .prior_durable_release_assets_empty_at_supersession==true and .trusted_mint_attempt1_signing_step=="skipped" and (has("prior_signing")|not) and .superseded_by_control=="1111111111111111111111111111111111111111"' "$tmp/build-one/LEGACY-RESERVATION-SUPERSESSION.json" >/dev/null \
 && ok W_ed25519_signatures_and_archive_reproducible || bad W_ed25519_signatures_and_archive_reproducible
ssh-keygen -q -t ed25519 -N '' -C '' -f "$tmp/wrong-key"
ssh-keygen -q -t rsa -b 2048 -N '' -C '' -f "$tmp/rsa-key"
! "$tmp/repro-control/mint_manual_db_bundle.sh" /tmp/icom-db-package d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 "$tmp/wrong-key" "$tmp/wrong-build" "$tmp/legacy-run-evidence.json" >/dev/null 2>&1 \
 && ! "$tmp/repro-control/mint_manual_db_bundle.sh" /tmp/icom-db-package d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 "$tmp/rsa-key" "$tmp/rsa-build" "$tmp/legacy-run-evidence.json" >/dev/null 2>&1 \
 && ok X_wrong_and_non_ed25519_keys_rejected || bad X_wrong_and_non_ed25519_keys_rejected
legacy_mutations_pass=true
for spec in \
  '.attempt1_run_id=1' \
  '.attempt1_job_id=1' \
  '.attempt1_signing_step="success"' \
  '.raw_sha256.attempt1_logs_zip="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
  '.legacy_release_updated_at="2026-10-01T00:00:00Z"' \
  '.earlier_trusted_runs=[]' \
  '.earlier_trusted_runs[1].mint_job="success"' \
  '.legacy_control_workflow_run_census += [{"listed_run_attempt":1,"run_id":999,"verified_attempts":[1]}]' \
  '.legacy_release_html_url="https://github.com/wrong/release"' \
  '.legacy_release_id=1'; do
  index="$(printf '%s' "$spec" | shasum -a 256 | cut -c1-8)"
  jq -c "$spec" "$tmp/legacy-run-evidence.json" > "$tmp/legacy-mutated-$index.json"
  if "$tmp/repro-control/mint_manual_db_bundle.sh" /tmp/icom-db-package d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 "$tmp/repro-key" "$tmp/mutated-build-$index" "$tmp/legacy-mutated-$index.json" >/dev/null 2>&1; then legacy_mutations_pass=false; fi
done
[ "$legacy_mutations_pass" = true ] && ok X2_run_job_step_log_timestamp_mutations_rejected || bad X2_run_job_step_log_timestamp_mutations_rejected
jq -e 'has("legacy_release_created_at_commit_timestamp")|not' "$tmp/legacy-run-evidence.json" >/dev/null \
 && ! rg -n 'dt\(release\["created_at"\]\)|created_at.*failed step|created_at.*job' "$ROOT/trusted/verify_legacy_run_evidence.py" >/dev/null \
 && ok X3_created_at_not_used_as_creation_cutoff || bad X3_created_at_not_used_as_creation_cutoff
jq -c '.legacy_control_workflow_run_census += [{"listed_run_attempt":1,"run_id":999,"verified_attempts":[1]}]' "$tmp/legacy-run-evidence.json" > "$tmp/legacy-extra-run.json"
! "$tmp/repro-control/mint_manual_db_bundle.sh" /tmp/icom-db-package d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 "$tmp/repro-key" "$tmp/extra-run-build" "$tmp/legacy-extra-run.json" >/dev/null 2>&1 \
 && has "$ROOT/trusted/verify_legacy_run_evidence.py" 'len(census_runs)!=3' \
 && ok X4_extra_legacy_run_fails_closed || bad X4_extra_legacy_run_fails_closed
cat > "$tmp/reservation.json" <<'JSON'
{"draft":true,"tag_name":"manual-db/fulfillment/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/1111111111111111111111111111111111111111","name":"RESERVED trusted manual DB package","body":"candidate=d0819f7bacf5ee6dedca4345796a8d022ff6a5cc control=1111111111111111111111111111111111111111; supersedes_legacy_release=400681564 old_control=b589d4d92200ac393a04344f2f203efe7f177e6a reason=pre-sign draft-discovery 404"}
JSON
"$RESERVATION" "$tmp/reservation.json" d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111
sed 's/supersedes_legacy_release=400681564/supersedes_legacy_release=5/' "$tmp/reservation.json" > "$tmp/reservation-bad.json"
! "$RESERVATION" "$tmp/reservation-bad.json" d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 >/dev/null 2>&1 && ok Y_exact_reservation_identity || bad Y_exact_reservation_identity
cat > "$tmp/draft-empty.json" <<'JSON'
{"draft":true,"tag_name":"manual-db/fulfillment/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/1111111111111111111111111111111111111111","name":"RESERVED trusted manual DB package","body":"candidate=d0819f7bacf5ee6dedca4345796a8d022ff6a5cc control=1111111111111111111111111111111111111111; supersedes_legacy_release=400681564 old_control=b589d4d92200ac393a04344f2f203efe7f177e6a reason=pre-sign draft-discovery 404","assets":[]}
JSON
cat > "$tmp/draft-exact.json" <<'JSON'
{"draft":true,"tag_name":"manual-db/fulfillment/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/1111111111111111111111111111111111111111","name":"RESERVED trusted manual DB package","body":"candidate=d0819f7bacf5ee6dedca4345796a8d022ff6a5cc control=1111111111111111111111111111111111111111; supersedes_legacy_release=400681564 old_control=b589d4d92200ac393a04344f2f203efe7f177e6a reason=pre-sign draft-discovery 404","assets":[{"name":"manual-db-bundle.tar.gz.sha256"},{"name":"manual-db-bundle.tar.gz"}]}
JSON
"$RESERVATION" "$tmp/draft-empty.json" d0819f7bacf5ee6dedca4345796a8d022ff6a5cc 1111111111111111111111111111111111111111 \
 && [ "$("$DECIDE" false true true absent)" = resume_idempotent ] \
 && "$ASSETS" "$tmp/draft-exact.json" draft \
 && ! "$ASSETS" "$tmp/release-extra.json" draft >/dev/null 2>&1 \
 && has "$WF" 'if [ "$release_exists" = false ]; then' \
 && has "$WF" 'state=release_staged' \
 && has "$WF" 'Verify draft assets before publication' \
 && ok Z_partial_state_matrix || bad Z_partial_state_matrix
live_tag='manual-db/fulfillment/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/b589d4d92200ac393a04344f2f203efe7f177e6a'
cat > "$tmp/live-releases.json" <<'JSON'
[[{"id":400681564,"tag_name":"manual-db/fulfillment/d0819f7bacf5ee6dedca4345796a8d022ff6a5cc/b589d4d92200ac393a04344f2f203efe7f177e6a","draft":true,"name":"RESERVED trusted manual DB package","body":"candidate=d0819f7bacf5ee6dedca4345796a8d022ff6a5cc control=b589d4d92200ac393a04344f2f203efe7f177e6a; absent staging may resume only with byte-identical deterministic mint","assets":[]},{"id":9,"tag_name":"unrelated","draft":false,"assets":[]}],[]]
JSON
"$SELECT_RELEASE" "$tmp/live-releases.json" "$live_tag" > "$tmp/live-selected.json"
"$LEGACY" "$tmp/live-selected.json" >/dev/null
[ "$(jq -r .id "$tmp/live-selected.json")" = 400681564 ] && ok AA_live_legacy_reservation_verified || bad AA_live_legacy_reservation_verified
jq '.[0] += [.[0][0]]' "$tmp/live-releases.json" > "$tmp/duplicate-releases.json"
! "$SELECT_RELEASE" "$tmp/duplicate-releases.json" "$live_tag" >/dev/null 2>&1 && ok AB_duplicate_exact_tag_fails || bad AB_duplicate_exact_tag_fails
jq '.[0][0].draft=false | .[0][0].assets=[{"id":1,"name":"manual-db-bundle.tar.gz"},{"id":2,"name":"manual-db-bundle.tar.gz.sha256"}]' "$tmp/live-releases.json" > "$tmp/published-releases.json"
"$SELECT_RELEASE" "$tmp/published-releases.json" "$live_tag" > "$tmp/published-selected.json" && [ "$(jq -r .draft "$tmp/published-selected.json")" = false ] && ok AC_published_exact_discovered || bad AC_published_exact_discovered
set +e; "$SELECT_RELEASE" "$tmp/live-releases.json" manual-db/fulfillment/wrong/tag >/dev/null 2>&1; wrong_rc=$?; set -e
[ "$wrong_rc" = 3 ] && ok AD_wrong_tag_ignored || bad AD_wrong_tag_ignored
has "$WF" 'if [ "$release_exists" = false ]; then' && has "$WF" 'POST "/repos/$GITHUB_REPOSITORY/releases"' && ok AE_tag_only_creates_release_by_rest || bad AE_tag_only_creates_release_by_rest
jq '.assets=[{"id":1,"name":"unexpected"}]' "$tmp/live-selected.json" > "$tmp/legacy-assets.json"
jq '.draft=false' "$tmp/live-selected.json" > "$tmp/legacy-published.json"
jq '.id=400681565' "$tmp/live-selected.json" > "$tmp/legacy-wrong-id.json"
! "$LEGACY" "$tmp/legacy-assets.json" >/dev/null 2>&1 && ! "$LEGACY" "$tmp/legacy-published.json" >/dev/null 2>&1 && ! "$LEGACY" "$tmp/legacy-wrong-id.json" >/dev/null 2>&1 && ok AF_legacy_state_mutations_fail || bad AF_legacy_state_mutations_fail
cat > "$tmp/legacy-ref.json" <<'JSON'
{"object":{"type":"commit","sha":"b589d4d92200ac393a04344f2f203efe7f177e6a"}}
JSON
"$REF" "$tmp/legacy-ref.json" b589d4d92200ac393a04344f2f203efe7f177e6a
sed 's/b589d4d92200ac393a04344f2f203efe7f177e6a/1111111111111111111111111111111111111111/' "$tmp/legacy-ref.json" > "$tmp/legacy-ref-wrong.json"
! "$REF" "$tmp/legacy-ref-wrong.json" b589d4d92200ac393a04344f2f203efe7f177e6a >/dev/null 2>&1 && ok AG_legacy_ref_target_enforced || bad AG_legacy_ref_target_enforced
! rg -n 'DELETE.*400681564|releases/400681564.*(PATCH|DELETE)|assets/400681564' "$WF" >/dev/null \
 && has "$WF" '[ "$INPUT_CONTROL_SHA" != "$old_control" ]' && has "$M" 'LEGACY-RESERVATION-SUPERSESSION.json' \
 && [ "$(grep -c 'name: Revalidate data and sign exact manifests' "$WF")" = 1 ] \
 && ! "$RESERVATION" "$tmp/live-selected.json" d0819f7bacf5ee6dedca4345796a8d022ff6a5cc b589d4d92200ac393a04344f2f203efe7f177e6a >/dev/null 2>&1 \
 && ok AH_legacy_untouched_new_identity_only || bad AH_legacy_untouched_new_identity_only
echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
