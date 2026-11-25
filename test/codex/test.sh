#!/usr/bin/env bash
set -euo pipefail

command -v bwrap
command -v curl
test "${CODEX_HOME:-}" = "/var/lib/codex-home"
test ! -e "$CODEX_HOME/auth.json"
touch "$CODEX_HOME/.write-test"
rm "$CODEX_HOME/.write-test"
