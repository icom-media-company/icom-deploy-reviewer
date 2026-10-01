#!/usr/bin/env bash
# shellcheck disable=SC2015,SC2016
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; WF="$ROOT/.github/workflows/manual-db-fulfillment-signer.yml"; V="$ROOT/trusted/manual_db_validate.py"; M="$ROOT/trusted/mint_manual_db_bundle.sh"
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); echo "PASS $1"; }; bad(){ FAIL=$((FAIL+1)); echo "FAIL $1" >&2; }
has(){ grep -Fq "$2" "$1"; }
has "$WF" '[ "$GITHUB_REPOSITORY" = icom-media/icom-deploy-reviewer ]' && has "$WF" '[ "$GITHUB_REF" = refs/heads/main ]' && ok A_protected_repo_ref || bad A_protected_repo_ref
has "$WF" 'GITHUB_TRIGGERING_ACTOR' && has "$WF" 'ICOM_MANUAL_DB_AUTHORIZED_ACTOR' && ok B_unauthorized_caller_rejected || bad B_unauthorized_caller_rejected
has "$WF" 'environment: read-business' && has "$WF" 'ICOM_BUSINESS_READ_TOKEN' && ok C_read_only_business_boundary || bad C_read_only_business_boundary
! grep -Eq '(bash|source|chmod \+x).*candidate' "$WF" && has "$WF" 'as data only' && ok D_candidate_never_executed || bad D_candidate_never_executed
validate_block="$(sed -n '/^  validate-data:/,/^  mint:/p' "$WF")"; ! grep -q 'ICOM_DEPLOY_CI_SIGNING_KEY\|manual-db-sign' <<<"$validate_block" && ok E_validation_has_no_signing_secret || bad E_validation_has_no_signing_secret
mint_block="$(sed -n '/^  mint:/,$p' "$WF")"; grep -q 'environment: manual-db-sign' <<<"$mint_block" && grep -q 'ICOM_DEPLOY_CI_SIGNING_KEY' <<<"$mint_block" && ok F_mint_secret_isolated || bad F_mint_secret_isolated
has "$V" 'd0819f7bacf5ee6dedca4345796a8d022ff6a5cc' && [ "$(grep -c '20261001-.*-[0-9][0-9]' "$V")" -ge 4 ] && ok G_exact_candidate_and_order || bad G_exact_candidate_and_order
has "$V" 'd["authorization"]["operations"] != ["forward","verify"]' && ok H_rollback_not_authorized || bad H_rollback_not_authorized
has "$V" 'pinned package mismatch' && has "$V" 'SQL hash mismatch' && has "$V" 'document hash mismatch' && ok I_hash_mutations_fail_closed || bad I_hash_mutations_fail_closed
has "$WF" 'gh release view' && has "$WF" 'gh release create' && has "$WF" 'concurrency:' && ok J_durable_exactly_once_gate || bad J_durable_exactly_once_gate
! rg -n 'psql|supabase db push|apply_migration' "$WF" "$V" "$M" && ok K_no_database_execution || bad K_no_database_execution
[ "$(sha256sum "$ROOT/trusted/ci-allowed-signers"|awk '{print $1}')" = 704dc47b50f2ebbb8515b400bde88a943d967f313255a85a5bd4b1534177acd9 ] && ok L_existing_ci_trust_compatible || bad L_existing_ci_trust_compatible
echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
