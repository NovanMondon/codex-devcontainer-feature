#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

allowed_domains_file="/etc/codex/allowed-domains.txt"
include_github_meta_ranges="${CODEX_INCLUDE_GITHUB_META_RANGES:-true}"

mapfile -t allowed_domains < <(sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$allowed_domains_file")
if [ "${#allowed_domains[@]}" -eq 0 ]; then
  printf 'codex-secure: no allowed domains configured\n' >&2
  exit 1
fi

add_ipv4_cidr_to_allowlist() {
  local source="$1"
  local cidr="$2"

  if [[ ! "$cidr" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$ ]]; then
    printf 'codex-secure: invalid %s CIDR range: %s\n' "$source" "$cidr" >&2
    exit 1
  fi
  ipset add allowed-domains "$cidr" -exist
}

configure_ipv6_default_deny() {
  command -v ip6tables >/dev/null 2>&1 || {
    printf 'codex-secure: ip6tables is required for IPv6 default-deny\n' >&2
    exit 1
  }

  ip6tables -F
  ip6tables -X
  ip6tables -t mangle -F
  ip6tables -t mangle -X
  ip6tables -t nat -F 2>/dev/null || true
  ip6tables -t nat -X 2>/dev/null || true
  ip6tables -A INPUT -i lo -j ACCEPT
  ip6tables -A OUTPUT -o lo -j ACCEPT
  ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  ip6tables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
  ip6tables -P INPUT DROP
  ip6tables -P FORWARD DROP
  ip6tables -P OUTPUT DROP
}

docker_dns_rules="$(iptables-save -t nat | grep '127\.0\.0\.11' || true)"

iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
ipset destroy allowed-domains 2>/dev/null || true

if [ -n "$docker_dns_rules" ]; then
  iptables -t nat -N DOCKER_OUTPUT 2>/dev/null || true
  iptables -t nat -N DOCKER_POSTROUTING 2>/dev/null || true
  while IFS= read -r rule; do
    [ -n "$rule" ] || continue
    # The rule comes from iptables-save, not user input. Word splitting is required.
    # shellcheck disable=SC2086
    iptables -t nat $rule
  done <<< "$docker_dns_rules"
fi

iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --sport 53 -j ACCEPT
iptables -A INPUT -p tcp --sport 53 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

ipset create allowed-domains hash:net
for domain in "${allowed_domains[@]}"; do
  printf 'codex-secure: resolving %s\n' "$domain"
  ips="$(dig +short A "$domain" | grep -E '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' | sed '/^[[:space:]]*$/d')"
  if [ -z "$ips" ]; then
    printf 'codex-secure: failed to resolve %s\n' "$domain" >&2
    exit 1
  fi
  while IFS= read -r ip; do
    ipset add allowed-domains "$ip" -exist
  done <<< "$ips"
done

if [ "$include_github_meta_ranges" = "true" ]; then
  github_meta="$(curl -fsSL --connect-timeout 10 https://api.github.com/meta)"
  echo "$github_meta" | jq -e '.web and .api and .git' >/dev/null || {
    printf 'codex-secure: GitHub meta response is missing expected fields\n' >&2
    exit 1
  }
  while IFS= read -r cidr; do
    [ -n "$cidr" ] || continue
    [[ "$cidr" == *:* ]] && continue
    add_ipv4_cidr_to_allowlist GitHub "$cidr"
  done < <(echo "$github_meta" | jq -r '((.web // []) + (.api // []) + (.git // []))[]' | sort -u)
fi

host_ip="$(ip route | awk '/default/ {print $3; exit}')"
if [ -z "$host_ip" ]; then
  printf 'codex-secure: failed to detect the container gateway\n' >&2
  exit 1
fi
host_network="$(echo "$host_ip" | sed 's/\.[0-9]*$/.0\/24/')"
iptables -A INPUT -s "$host_network" -j ACCEPT
iptables -A OUTPUT -d "$host_network" -j ACCEPT

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -A INPUT -j REJECT --reject-with icmp-admin-prohibited
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited
iptables -A FORWARD -j REJECT --reject-with icmp-admin-prohibited

configure_ipv6_default_deny

if curl --connect-timeout 5 https://example.com >/dev/null 2>&1; then
  printf 'codex-secure: firewall verification failed; example.com is reachable\n' >&2
  exit 1
fi
if ! curl --connect-timeout 5 https://api.openai.com >/dev/null 2>&1; then
  printf 'codex-secure: firewall verification failed; api.openai.com is unreachable\n' >&2
  exit 1
fi
if curl --connect-timeout 5 -6 https://example.com >/dev/null 2>&1; then
  printf 'codex-secure: IPv6 firewall verification failed\n' >&2
  exit 1
fi

printf 'codex-secure: firewall verification passed\n'
