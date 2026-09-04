#!/usr/bin/env bash
set -euo pipefail

command -v bwrap
test -u "$(command -v bwrap)"
test "${CODEX_HOME:-}" = "/var/lib/codex-home"
test -f "$CODEX_HOME/auth.json"
test -r "$CODEX_HOME/auth.json"
test -w "$CODEX_HOME/auth.json"
touch "$CODEX_HOME/.write-test"
rm "$CODEX_HOME/.write-test"
