# Owner ceremony — fulfillment manual DB bundle

Never execute a verifier from the untrusted bundle to establish trust. Independently obtain
the reviewed reviewer-control SHA and create a clean checkout of
`icom-media/icom-deploy-reviewer` at that exact SHA.

```bash
EXPECTED_REVIEWER_CONTROL_SHA='<independently supplied reviewed 40-hex SHA>'
REVIEWER_CONTROL=/tmp/icom-deploy-reviewer-control
CANDIDATE=/tmp/icom-db-candidate-d0819f7b
DB_CONTROL=/tmp/icom-db-control-96722ad7
BUNDLE=/path/to/extracted-bundle

git -C /path/to/icom-deploy-reviewer worktree add --detach "$REVIEWER_CONTROL" "$EXPECTED_REVIEWER_CONTROL_SHA"
test "$(git -C "$REVIEWER_CONTROL" rev-parse HEAD)" = "$EXPECTED_REVIEWER_CONTROL_SHA"
test -z "$(git -C "$REVIEWER_CONTROL" status --porcelain)"
test "$(git -C "$REVIEWER_CONTROL" remote get-url origin)" = https://github.com/icom-media/icom-deploy-reviewer.git
test "$(jq -r .trusted_control_sha "$BUNDLE/BUNDLE-METADATA.json")" = "$EXPECTED_REVIEWER_CONTROL_SHA"
"$REVIEWER_CONTROL/trusted/verify_manual_db_bundle.py" "$BUNDLE" \
  d0819f7bacf5ee6dedca4345796a8d022ff6a5cc "$EXPECTED_REVIEWER_CONTROL_SHA" \
  "$REVIEWER_CONTROL/trusted/ci-allowed-signers"

git -C /path/to/icom-business worktree add --detach "$CANDIDATE" d0819f7bacf5ee6dedca4345796a8d022ff6a5cc
git -C /path/to/icom-business worktree add --detach "$DB_CONTROL" 96722ad7c5c285deb4c636dfff76e6cefa7e5c04
test -z "$(git -C "$CANDIDATE" status --porcelain)"
test -z "$(git -C "$DB_CONTROL" status --porcelain)"
for p in 20261001-fulfillment-retry-90 20261001-pgsodium-prerequisite-91 20261001-fulfillment-historical-evidence-92 20261001-mto-claim-93; do
  cp "$BUNDLE/docs/deploy-candidates/$p/candidate-manifest.json.ci.sig" "$CANDIDATE/docs/deploy-candidates/$p/"
done
```

Use only `owner-cosign-manual-db-migration.sh` from the clean DB control checkout, and
authorize `forward,verify` only:

```bash
OWNER_KEY="$HOME/.ssh/icom_deploy_owner_approval"
PACKAGES=(20261001-fulfillment-retry-90 20261001-pgsodium-prerequisite-91 20261001-fulfillment-historical-evidence-92 20261001-mto-claim-93)
MANIFESTS=(
  2dff21f4ddb83ea52905420994c238eaf517e9bbbb6009b6086db87356612f44
  0cb36140d395a8c3b8468485e13ab91e25d75a966cef93300b90e5009c5da6fa
  f4a4f6e4ae1a5bfa0d441829cf7bb68dd8d6c81ce1a8c28a6e653bba70b8873e
  24882dc7d6d450c1b2c86638ca9084dbd7e67302684518fd9c2f352dacfa3b65
)
for i in 0 1 2 3; do
  dir="$CANDIDATE/docs/deploy-candidates/${PACKAGES[$i]}"
  manifest="$dir/candidate-manifest.json"; request="$dir/owner-authorization-request.json"
  "$DB_CONTROL/infra/icom-deploy/owner-cosign-manual-db-migration.sh" \
    "$manifest" "$CANDIDATE" "${MANIFESTS[$i]}" "$(jq -r .candidate_id "$manifest")" \
    "$(jq -r '.artifacts[]|select(.role=="forward")|.path' "$manifest")" \
    "$(jq -r '.artifacts[]|select(.role=="forward")|.sha256' "$manifest")" \
    "$(jq -r '.artifacts[]|select(.role=="verify")|.sha256' "$manifest")" \
    "$(jq -r '.artifacts[]|select(.role=="rollback")|.sha256' "$manifest")" \
    "$(jq -r .expected_db_head "$request")" "$(jq -r .scope_sha256 "$request")" \
    "$OWNER_KEY" "$DB_CONTROL/infra/icom-deploy/trust/ci-allowed-signers" \
    'I APPROVE THIS MANUAL DATABASE MIGRATION' forward,verify \
    "$(jq -r .execution_contract_sha256 "$request")" \
    "$(jq -r .production_database_lineage_sha256 "$request")"
done

RUNNER="$CANDIDATE/scripts/run-fulfillment-recovery-db-package.sh"
for package in "${PACKAGES[@]}"; do
  "$RUNNER" "$CANDIDATE/docs/deploy-candidates/$package" forward "$DB_CONTROL"
  "$RUNNER" "$CANDIDATE/docs/deploy-candidates/$package" verify "$DB_CONTROL"
done
```

The four owner signatures are written beside the candidate manifests. Follow every package
precheck/runbook requirement before the runner. Never authorize rollback and never copy an
owner private key into the bundle.
