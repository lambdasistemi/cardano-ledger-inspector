#!/usr/bin/env bash
# Configure branch protection on main:
# - Require every per-concern CI job plus the Build Gate populator
# - Require branch be up-to-date with base before merging
# - Disallow force-pushes and deletions
# - No required reviewers (single-maintainer repo); bump if collaborators join
#
# The required-contexts list mirrors the job 'name:' fields in
# .github/workflows/ci.yml. When a new per-concern job is added, list it here
# too.
#
# Idempotent. Re-run any time the required-checks list changes.
#
# Requires: gh authenticated as a repo admin.
set -euo pipefail

OWNER="${1:-lambdasistemi}"
REPO="${2:-cardano-ledger-inspector}"
BRANCH="${3:-main}"

gh api -X PUT "repos/$OWNER/$REPO/branches/$BRANCH/protection" \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Build Gate",
      "OpenAPI regen + diff",
      "Swagger alias check",
      "Smoke tx.identify",
      "Smoke tx.witness.plan",
      "Smoke tx.intent",
      "Smoke tx.validate",
      "Smoke tx.evaluate.scripts",
      "Smoke explicit UTxO input context",
      "Smoke Extism conformance vs WASI",
      "Format (fourmolu)",
      "Hlint"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON

echo "Branch protection applied to $OWNER/$REPO:$BRANCH"
gh api "repos/$OWNER/$REPO/branches/$BRANCH/protection" \
  --jq '{required_status_checks, allow_force_pushes, allow_deletions, enforce_admins}'
