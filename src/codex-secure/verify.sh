#!/usr/bin/env bash
set -euo pipefail

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

for _ in $(seq 1 60); do
  [ -f /run/codex-secure.ready ] && break
  [ ! -f /run/codex-secure.failed ] || fail "Feature startup initialization failed"
  sleep 1
done
[ -f /run/codex-secure.ready ] || fail "Feature startup initialization did not finish"
pass "Feature startup initialization completed"

command -v codex >/dev/null 2>&1 || fail "codex is not installed"
codex_version="$(codex --version 2>&1)" || fail "codex failed to start"
pass "codex is installed ($codex_version)"

command -v bwrap >/dev/null 2>&1 || fail "bubblewrap is not installed"
[ -u "$(command -v bwrap)" ] || fail "bubblewrap is not setuid"
pass "bubblewrap is installed in setuid mode"

if ! codex sandbox linux /bin/true 2>/dev/null && ! codex sandbox /bin/true; then
  fail "Codex Linux sandbox failed to execute"
fi
pass "Codex Linux sandbox executes successfully"

[ "${CODEX_HOME:-}" = "/var/lib/codex-home" ] || fail "CODEX_HOME is not /var/lib/codex-home"
[ -f "$CODEX_HOME/auth.json" ] || fail "shared auth.json is missing"
[ -r "$CODEX_HOME/auth.json" ] || fail "shared auth.json is not readable"
[ -w "$CODEX_HOME/auth.json" ] || fail "shared auth.json is not writable"
if ! touch "$CODEX_HOME/.codex-write-test" 2>/dev/null; then
  fail "CODEX_HOME is not writable"
fi
rm -f "$CODEX_HOME/.codex-write-test"
pass "WSL auth.json is shared read/write"

[ -d /etc/codex/skills ] || fail "shared skills directory is missing"
if touch /etc/codex/skills/.codex-write-test 2>/dev/null; then
  rm -f /etc/codex/skills/.codex-write-test
  fail "shared skills directory is writable"
fi
pass "shared skills are read-only"

if [ -r /etc/codex/firewall.conf ] && grep -q '^ENABLE_FIREWALL=true$' /etc/codex/firewall.conf; then
  sudo iptables -S OUTPUT | grep -q -- '-P OUTPUT DROP' || fail "IPv4 firewall is not default-deny"
  sudo ip6tables -S OUTPUT | grep -q -- '-P OUTPUT DROP' || fail "IPv6 firewall is not default-deny"
  pass "IPv4 and IPv6 firewalls are default-deny"
fi

if [ -S /var/run/docker.sock ]; then
  fail "Docker socket is mounted in the devcontainer"
fi
pass "Docker socket is not mounted"

printf '\nCodex secure environment checks completed.\n'
