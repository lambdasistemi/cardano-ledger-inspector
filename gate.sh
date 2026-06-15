#!/usr/bin/env bash
set -euo pipefail

git diff --check
just ui-check
just build-ui
just test-playwright
