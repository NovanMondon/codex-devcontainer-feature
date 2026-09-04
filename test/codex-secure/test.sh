#!/usr/bin/env bash
set -euo pipefail

for _ in $(seq 1 60); do
  test -f /run/codex-secure.ready && break
  test ! -f /run/codex-secure.failed || exit 1
  sleep 1
done
test -f /run/codex-secure.ready

command -v codex
codex --version
codex sandbox linux /bin/true
command -v bwrap
test -u "$(command -v bwrap)"
test "${CODEX_HOME:-}" = "/var/lib/codex-home"
test -f "$CODEX_HOME/auth.json"
test -r "$CODEX_HOME/auth.json"
test -w "$CODEX_HOME/auth.json"
touch "$CODEX_HOME/.write-test"
rm "$CODEX_HOME/.write-test"
test -d /etc/codex/skills
if touch /etc/codex/skills/.write-test 2>/dev/null; then
  rm -f /etc/codex/skills/.write-test
  exit 1
fi
sudo iptables -S OUTPUT | grep -q -- '-P OUTPUT DROP'
sudo ip6tables -S OUTPUT | grep -q -- '-P OUTPUT DROP'
