#!/usr/bin/env bash
set -euo pipefail

git diff --check
just format-check
just hlint
just ui-check
just build-ui
just test-playwright
