#!/usr/bin/env bash
set -euo pipefail

codex_version="${CODEXVERSION:-0.121.0}"
enable_firewall="${ENABLEFIREWALL:-true}"
allowed_domains="${ALLOWEDDOMAINS:-api.openai.com auth.openai.com github.com api.github.com codeload.github.com raw.githubusercontent.com objects.githubusercontent.com registry.npmjs.org}"
include_github_meta_ranges="${INCLUDEGITHUBMETARANGES:-true}"

fail() {
  printf 'codex-secure: %s\n' "$*" >&2
  exit 1
}

validate_boolean() {
  case "$1" in
    true | false) ;;
    *) fail "$2 must be true or false" ;;
  esac
}

validate_boolean "$enable_firewall" "enableFirewall"
validate_boolean "$include_github_meta_ranges" "includeGitHubMetaRanges"

if [[ ! "$codex_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]]; then
  fail "codexVersion must be an exact semantic version"
fi

if [ ! -r /etc/os-release ]; then
  fail "cannot identify the container operating system"
fi

# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in
  debian | ubuntu) ;;
  *) fail "only Debian and Ubuntu base images are currently supported (found ${ID:-unknown})" ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  aggregate \
  bubblewrap \
  ca-certificates \
  curl \
  dnsutils \
  iproute2 \
  ipset \
  iptables \
  jq \
  sudo \
  util-linux
rm -rf /var/lib/apt/lists/*

if command -v update-alternatives >/dev/null 2>&1 && [ -x /usr/sbin/iptables-nft ]; then
  update-alternatives --set iptables /usr/sbin/iptables-nft
  update-alternatives --set ip6tables /usr/sbin/ip6tables-nft
  update-alternatives --set arptables /usr/sbin/arptables-nft 2>/dev/null || true
  update-alternatives --set ebtables /usr/sbin/ebtables-nft 2>/dev/null || true
fi

bwrap_path="$(command -v bwrap)"
chmod u+s "$bwrap_path"

command -v npm >/dev/null 2>&1 || fail "Node Feature dependency did not provide npm"
npm install --global --omit=dev "@openai/codex@${codex_version}"
command -v codex >/dev/null 2>&1 || fail "Codex CLI installation did not create a codex executable"

install -d -m 0755 /etc/codex /usr/local/share/codex-secure
install -d -m 0775 /var/lib/codex-home
install -m 0500 init-firewall.sh /usr/local/share/codex-secure/init-firewall.sh
install -m 0555 entrypoint.sh /usr/local/share/codex-secure/entrypoint.sh
install -m 0555 verify.sh /usr/local/bin/codex-secure-verify
codex --version

remote_user="${_REMOTE_USER:-${_CONTAINER_USER:-root}}"
if [ "$remote_user" = "automatic" ] || ! id "$remote_user" >/dev/null 2>&1; then
  for candidate in vscode node codespace; do
    if id "$candidate" >/dev/null 2>&1; then
      remote_user="$candidate"
      break
    fi
  done
fi
if ! id "$remote_user" >/dev/null 2>&1; then
  remote_user=root
fi
printf '%s\n' "$remote_user" > /etc/codex/remote-user
chown "$remote_user:$(id -gn "$remote_user")" /var/lib/codex-home

: > /etc/codex/allowed-domains.txt
while IFS= read -r domain; do
  [ -n "$domain" ] || continue
  if [[ ! "$domain" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*\.[A-Za-z]{2,}$ ]]; then
    fail "invalid domain in allowedDomains: $domain"
  fi
  printf '%s\n' "$domain" >> /etc/codex/allowed-domains.txt
done < <(printf '%s\n' "$allowed_domains" | tr ', ' '\n\n' | sed '/^$/d' | sort -u)

if [ ! -s /etc/codex/allowed-domains.txt ]; then
  fail "allowedDomains must contain at least one domain"
fi

{
  printf 'ENABLE_FIREWALL=%s\n' "$enable_firewall"
  printf 'INCLUDE_GITHUB_META_RANGES=%s\n' "$include_github_meta_ranges"
} > /etc/codex/firewall.conf

chmod 0444 /etc/codex/allowed-domains.txt /etc/codex/firewall.conf /etc/codex/remote-user

printf 'codex-secure: installed Codex %s for remote user %s\n' "$codex_version" "$remote_user"
