#!/usr/bin/env bash
set -euo pipefail
WF="$(cd "$(dirname "$0")/.." && pwd)/.github/workflows/pre-ci-review-evidence.yml"
test -s "$WF"
grep -q 'environment: read-business' "$WF"
grep -q 'environment: review' "$WF"
grep -q 'candidate_sha' "$WF"
grep -q 'expected_current_sha' "$WF"
grep -q 'service:' "$WF"
grep -q 'forward-only' "$WF"
grep -q 'ICOM_DEPLOY_REVIEWER_SIGNING_KEY' "$WF"
grep -q 'creator_discovery_phase1_api_scope' "$WF"
grep -q 'creator_intelligence_phase2_api_scope' "$WF"
grep -q 'migration_41_scope' "$WF"
grep -q 'migration_42_scope' "$WF"
grep -q 'auto_invite_send_unchanged' "$WF"
grep -q 'auto_invite_configuration_unchanged' "$WF"
grep -q 'backorder_classification_unchanged' "$WF"
grep -q 'unrelated_api_paths_rejected' "$WF"
grep -q 'candidate_tree_sha' "$WF"
grep -q 'source_repository' "$WF"
grep -q 'apps/api/app/cron/affiliate-creator-discovery/route.ts' "$WF"
grep -q 'apps/api/app/cron/affiliate-creator-metric-refresh/route.ts' "$WF"
grep -q 'apps/api/lib/affiliate-creator-metric-refresh.ts' "$WF"
grep -q 'apps/api/lib/__tests__/affiliate-creator-metric-refresh.test.ts' "$WF"
grep -q 'scripts/icom-affiliate-creator-sync.sh' "$WF"
grep -q 'scripts/cron.d/icom-affiliate-creator-sync' "$WF"
grep -q 'scripts/patch-cron-allowlist-affiliate-creator-sync.sh' "$WF"
grep -q 'scripts/__tests__/icom-affiliate-creator-sync.test.sh' "$WF"
grep -q '20260916_41_affiliate_creator_discovery_metadata.sql' "$WF"
grep -q '20260916_42_affiliate_creator_sync_runs.sql' "$WF"
grep -q '20260916_42_affiliate_creator_sync_runs_ROLLBACK.sql' "$WF"
grep -q '20260916_42_affiliate_creator_sync_runs_VERIFY.sql' "$WF"
grep -q 'auto_invite_shop_settings_ui_scope' "$WF"
grep -q 'migration_43_scope' "$WF"
grep -q 'migration_43_checksum' "$WF"
grep -q '20260917_43_affiliate_shop_settings_control.sql' "$WF"
grep -q '20260917_43_affiliate_shop_settings_control_ROLLBACK.sql' "$WF"
grep -q '20260917_43_affiliate_shop_settings_control_VERIFY.sql' "$WF"
grep -q 'f391fa4b474075ec2dab61ed3d05ebdd51e9d134643c865cbded090c1bfe735b' "$WF"
grep -q 'send_off_boundary' "$WF"
grep -q 'invite_creation_absent' "$WF"
grep -q 'queue_execution_absent' "$WF"
grep -q 'quota_consumption_absent' "$WF"
grep -q 'scheduler_activation_absent' "$WF"
grep -q 'migration_sha256' "$WF"
grep -q 'auto_invite_shop_settings_audit_scope' "$WF"
grep -q 'migration_44_scope' "$WF"
grep -q 'migration_44_checksum' "$WF"
grep -q 'truthful_backfill' "$WF"
grep -q 'atomic_settings_audit' "$WF"
grep -q 'audit_failure_rolls_back' "$WF"
grep -q '20260917_44_affiliate_shop_settings_audit.sql' "$WF"
grep -q '20260917_44_affiliate_shop_settings_audit_ROLLBACK.sql' "$WF"
grep -q '20260917_44_affiliate_shop_settings_audit_VERIFY.sql' "$WF"
grep -q 'verify-auto-invite-settings-audit-db.sh' "$WF"
grep -q 'cfba02ef9f49d912b6b629352063c913caf94795579e51b7aafbbea6c3d35b2c' "$WF"
grep -q 'affiliate_auto_invite_shop_eligibility_backfilled' "$WF"
grep -q "'source_enabled_at'" "$WF"
grep -q 'affiliate_invite_queue' "$WF"
grep -q 'affiliate_invite_reservations' "$WF"
grep -Fq 'insert[[:space:]]+into' "$WF"
grep -Fq 'delete[[:space:]]+from' "$WF"
grep -Fq 'merge[[:space:]]+into' "$WF"
grep -Fq 'upsert[[:space:]]+into' "$WF"
grep -Fq 'truncate([[:space:]]+table)?' "$WF"
grep -Fq 'affiliate_outreach_quota(_snapshot)?' "$WF"
grep -Fq '\.(insert|upsert|update|delete)' "$WF"
grep -q 'affiliate_outreach_quota' "$WF"
grep -q 'cron\\.schedule' "$WF"
! grep -Eq 'apps/api/(app|lib)/\*' "$WF"
! grep -Eq 'contents: write|packages: write|deploy-approved|owner-deploy|docker (run|stop|rm)' "$WF"

SENSITIVE_TABLES='(affiliate_invite_queue|affiliate_invite_reservations|affiliate_invites|affiliate_outreach_quota(_snapshot)?)'
SQL_MUTATION="(insert[[:space:]]+into|upsert[[:space:]]+into|update|delete[[:space:]]+from|merge[[:space:]]+into|truncate([[:space:]]+table)?|copy)[[:space:]]+(public\\.)?${SENSITIVE_TABLES}"
CLIENT_MUTATION="(from|table)[(][[:space:]]*['\"]${SENSITIVE_TABLES}['\"][[:space:]]*[)][[:space:]]*\.(insert|upsert|update|delete)[(]"
for fixture in \
  'insert into public.affiliate_invite_queue values (1)' \
  'update affiliate_invite_reservations set state = 1' \
  'delete from affiliate_invites where id = 1' \
  'upsert into affiliate_outreach_quota values (1)' \
  'truncate table affiliate_invite_queue' \
  'client.from("affiliate_invites").insert({})' \
  'db.table("affiliate_outreach_quota_snapshot").upsert({})'; do
  grep -Eiq "$SQL_MUTATION|$CLIENT_MUTATION" <<<"$fixture" \
    || { echo "FAIL: mutation fixture escaped scanner: $fixture"; exit 1; }
done
for fixture in \
  'create table public.affiliate_invite_queue (id bigint primary key)' \
  'select count(*) from public.affiliate_invite_reservations' \
  'if (select count(*) from public.affiliate_invites) <> 0 then raise exception'; do
  ! grep -Eiq "$SQL_MUTATION|$CLIENT_MUTATION" <<<"$fixture" \
    || { echo "FAIL: proof-only fixture rejected: $fixture"; exit 1; }
done
echo 'PASS: pre-CI reviewer producer preserves read/sign separation and has no deploy authority.'
