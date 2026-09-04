#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'codex-feature: %s\n' "$*" >&2
  exit 1
}

# OS が Debian または Ubuntu であることを確認する
if [ ! -r /etc/os-release ]; then
  fail "cannot identify the container operating system"
fi
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in
  debian | ubuntu) ;;
  *) fail "only Debian and Ubuntu base images are currently supported (found ${ID:-unknown})" ;;
esac

# Bubblewrap をインストールしてセットアップする
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  bubblewrap \
  ca-certificates \
  curl
rm -rf /var/lib/apt/lists/*

bwrap_path="$(command -v bwrap)"
chmod u+s "$bwrap_path"

# devcontainer の remoteUser を取得する
remote_user="${_REMOTE_USER:-${_CONTAINER_USER:-root}}"
if ! id "$remote_user" >/dev/null 2>&1; then
  fail "remote user does not exist: $remote_user"
fi

# Codex ホームディレクトリを作成して remoteUser に適切な権限を設定する
install -d -m 0775 -o "$remote_user" -g "$(id -gn "$remote_user")" /var/lib/codex-home

printf 'codex-feature: configured the Codex IDE extension environment for user %s\n' "$remote_user"
