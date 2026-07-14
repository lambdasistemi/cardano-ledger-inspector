#!/usr/bin/env bash
set -euo pipefail

workflow=${CI_WORKFLOW:-.github/workflows/ci.yml}
justfile=${CI_JUSTFILE:-justfile}

for file in "$workflow" "$justfile"; do
  if [[ ! -r $file ]]; then
    printf 'CI entry-point guard cannot read: %s\n' "$file" >&2
    exit 2
  fi
done

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

extract_targets() {
  { grep -Ev '^[[:space:]]*#' "$1" || true; } \
    | { grep -oE '\.#[[:alnum:]_.+-]+' || true; } \
    | sort -u
}

extract_ci_recipe() {
  awk '
    /^ci:[[:space:]]*$/ { in_ci = 1; next }
    in_ci && /^[^[:space:]#]/ { exit }
    in_ci && !/^[[:space:]]*#/ { print }
  ' "$1"
}

extract_targets "$workflow" >"$tmpdir/workflow-targets"
extract_ci_recipe "$justfile" \
  | { grep -oE '\.#[[:alnum:]_.+-]+' || true; } \
  | sort -u >"$tmpdir/ci-targets"

missing=$(comm -23 "$tmpdir/workflow-targets" "$tmpdir/ci-targets")
extra=$(comm -13 "$tmpdir/workflow-targets" "$tmpdir/ci-targets")

if [[ -n $missing || -n $extra ]]; then
  if [[ -n $missing ]]; then
    printf 'missing CI targets:\n%s\n' "$missing" >&2
  fi
  if [[ -n $extra ]]; then
    printf 'extra CI targets:\n%s\n' "$extra" >&2
  fi
  exit 1
fi
