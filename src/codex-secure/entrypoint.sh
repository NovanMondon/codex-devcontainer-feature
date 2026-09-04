#!/usr/bin/env bash
set -euo pipefail

feature_dir="/usr/local/share/codex-secure"
config_file="/etc/codex/firewall.conf"
codex_home="${CODEX_HOME:-/var/lib/codex-home}"
ready_file="/run/codex-secure.ready"
failed_file="/run/codex-secure.failed"

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    printf 'codex-secure: root access is required to initialize the container\n' >&2
    return 1
  fi
}

as_root rm -f "$ready_file" "$failed_file" 2>/dev/null || true
trap 'status=$?; if [ "$status" -ne 0 ]; then printf "%s\n" "$status" | as_root tee "$failed_file" >/dev/null; fi' EXIT

if [ ! -f "$codex_home/auth.json" ]; then
  printf 'codex-secure: %s is missing; create ~/.codex/auth.json in the current WSL distribution before opening the container\n' "$codex_home/auth.json" >&2
  exit 1
fi
if [ ! -d /etc/codex/skills ]; then
  printf 'codex-secure: /etc/codex/skills is missing; set AGENTS_SKILLS_DIR before opening the container\n' >&2
  exit 1
fi

remote_user="$(cat /etc/codex/remote-user 2>/dev/null || printf 'root')"
if id "$remote_user" >/dev/null 2>&1; then
  as_root chown "$remote_user:$(id -gn "$remote_user")" "$codex_home"
fi

enable_firewall=true
include_github_meta_ranges=true
if [ -r "$config_file" ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      ENABLE_FIREWALL) enable_firewall="$value" ;;
      INCLUDE_GITHUB_META_RANGES) include_github_meta_ranges="$value" ;;
    esac
  done < "$config_file"
fi

if [ "$enable_firewall" = "true" ]; then
  printf 'codex-secure: applying default-deny egress firewall\n'
  if [ "$(id -u)" -eq 0 ]; then
    CODEX_INCLUDE_GITHUB_META_RANGES="$include_github_meta_ranges" \
      "$feature_dir/init-firewall.sh"
  else
    sudo CODEX_INCLUDE_GITHUB_META_RANGES="$include_github_meta_ranges" \
      "$feature_dir/init-firewall.sh"
  fi
else
  printf 'codex-secure: firewall disabled by Feature option\n'
fi

printf 'ready\n' | as_root tee "$ready_file" >/dev/null
trap - EXIT
