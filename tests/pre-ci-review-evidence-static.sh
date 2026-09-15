#!/usr/bin/env bash
set -euo pipefail
WF="$(cd "$(dirname "$0")/.." && pwd)/.github/workflows/pre-ci-review-evidence.yml"
test -s "$WF"
grep -q 'environment: read-business' "$WF"
grep -q 'environment: review' "$WF"
grep -q 'candidate_sha' "$WF"
grep -q 'expected_current_sha' "$WF"
grep -q 'forward-only' "$WF"
grep -q 'ICOM_DEPLOY_REVIEWER_SIGNING_KEY' "$WF"
! grep -Eq 'contents: write|packages: write|deploy-approved|owner-deploy|docker (run|stop|rm)' "$WF"
echo 'PASS: pre-CI reviewer producer preserves read/sign separation and has no deploy authority.'
