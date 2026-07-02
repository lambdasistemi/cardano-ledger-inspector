#!/usr/bin/env bash
# Score every captured screenshot with a headless Claude vision pass -> per-scenario JSON.
set -euo pipefail
dir="$(cd "$(dirname "$0")" && pwd)"
out="$dir/out"
rubric="$dir/rubric.md"
shopt -s nullglob
: > "$out/judge.err"
for img in "$out"/[0-9]*.png; do
  name="$(basename "$img" .png)"
  prompt="You are a strict UX judge. Use the Read tool to view the screenshot at ${img} and read the rubric at ${rubric}. The screenshot is scenario '${name}' of the Ledger Inspector SPA (a full-page capture). Score it against every rubric dimension and output ONLY the JSON object the rubric specifies — no prose, no markdown fences."
  echo "judging ${name} ..."
  if ! claude -p "$prompt" --allowedTools "Read" > "$out/${name}.judge.txt" 2>>"$out/judge.err"; then
    echo "  claude failed for ${name} (see out/judge.err)"
  fi
done
echo "judging done"
