#!/usr/bin/env bash
set -euo pipefail

command -v bwrap
command -v curl
command -v python3
command -v coding-agents
test "${CODEX_HOME:-}" = "/var/lib/codex-home"
test ! -e "$CODEX_HOME/auth.json"
touch "$CODEX_HOME/.write-test"
rm "$CODEX_HOME/.write-test"

# The lifecycle entrypoint must have applied the environment without opening Bash.
test -L /etc/codex/config.toml
test -L /etc/codex/hooks.json
test -x /etc/codex/rollback-hook
test -L "$CODEX_HOME/AGENTS.md"
"$HOME/.local/bin/codex" --version
"$HOME/.local/bin/arb" --help >/dev/null
python3 - <<'PY'
import json
from pathlib import Path
status = json.loads((Path.home() / '.local/state/coding-agents/status.json').read_text())
assert not status['problems'], status['problems']
assert not status['container_rebuild_required']
PY
