#!/usr/bin/env bash
set -euo pipefail

git diff --check

# --- issue #168 ticket-specific proof (fail fast, before the full CI recipe) ---
# The review projection is what this ticket changes; run its focused checks
# first so a regression surfaces in minutes rather than after a full wasm build.
just check-review-types
just check-review

# FR-004 compatibility guard: asset_class_count must survive as a control-group
# field. This ticket adds `assets` ALONGSIDE it; silently dropping or
# repurposing the count would satisfy the new unit tests while breaking every
# existing consumer.
review_schema=specs/001-ledger-functional-layer/schemas/tx-review-result.schema.json
grep -qF '"asset_class_count"' "$review_schema" \
  || { echo "FAIL: asset_class_count removed from $review_schema"; exit 1; }
grep -qF '"asset_class_count"' libs/cardano-ledger-inspector/src/Conway/Inspector/Review.hs \
  || { echo "FAIL: asset_class_count no longer emitted by Review.hs"; exit 1; }
# --- end issue #168 proof ---

just ci
just build-pages-site
test -f _site/inspector/index.html
grep -F 'https://lambdasistemi.github.io/cardano-swiss-knife/' _site/inspector/index.html
test -f _site/openapi/cardano-ledger-functional.openapi.json
test ! -e _site/inspector/index.js
