#!/usr/bin/env bash
# Apply static IPv4 via NetworkManager (nmcli), with helper defaults.
# - Accepts dotted netmask (255.255.255.0) or numeric prefix (24)
# - Trims only TAIL garbage from inputs (extra trailing digits/dots/chars)
# - If mask/gateway/dns1 are missing, derive safe defaults:
#     mask=/24, gw=first host in subnet (fallback to last if IP is .1), dns1=gw, dns2=8.8.8.8
# - Refuses to "normalize" inside octets: only tail-trim; otherwise fail.
# - Exits 2 on invalid input; prints a clear error to stderr.

set -euo pipefail

NMCLI="/usr/bin/nmcli"

# -------- utils: string helpers --------
trim() {
  # shellcheck disable=SC2001
  sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//' <<<"$1"
}

# Remove trailing chars until string becomes a valid IPv4 (or empty)
is_valid_ipv4() {
  local s="$1" o1 o2 o3 o4
  [[ "$s" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r o1 o2 o3 o4 <<<"$s"
  for x in "$o1" "$o2" "$o3" "$o4"; do
    [[ "$x" =~ ^[0-9]{1,3}$ ]] || return 1
    (( 0 <= x && x <= 255 ))   || return 1
  done
  return 0
}

trim_tail_to_valid_ipv4() {
  local s
  s="$(trim "$1")"
  while [[ -n "$s" ]]; do
    if is_valid_ipv4 "$s"; then
      printf '%s\n' "$s"
      return 0
    fi
    s="${s%?}" # drop last char
  done
  printf '\n'
  return 0
}

# Netmask helpers
ipv4_to_int() {
  local IFS=.
  read -r o1 o2 o3 o4 <<<"$1"
  printf '%u\n' $(( (o1<<24) | (o2<<16) | (o3<<8) | o4 ))
}

int_to_ipv4() {
  local x=$1
  printf '%d.%d.%d.%d\n' $(( (x>>24)&255 )) $(( (x>>16)&255 )) $(( (x>>8)&255 )) $(( x&255 ))
}

mask_from_prefix() {
  local pfx=$1
  (( pfx >= 0 && pfx <= 32 )) || return 1
  local mask=$(( (pfx==0) ? 0 : (0xFFFFFFFF << (32 - pfx)) & 0xFFFFFFFF ))
  int_to_ipv4 "$mask"
}

prefix_from_mask() {
  local m="$1"
  is_valid_ipv4 "$m" || return 1
  local n; n="$(ipv4_to_int "$m")"
  # Check contiguity: inverted mask must be 0* 1* pattern
  local inv=$(( (~n) & 0xFFFFFFFF ))
  # inv & (inv + 1) == 0  => contiguous ones
  (( (inv & (inv + 1)) == 0 )) || return 1
  # Count ones
  local c=0 tmp=$n
  while (( tmp )); do
    (( c += tmp & 1 ))
    tmp=$(( tmp >> 1 ))
  done
  printf '%d\n' "$c"
}

# Remove trailing chars until value becomes a valid dotted netmask OR pure numeric prefix (0..32)
trim_tail_to_valid_mask_or_prefix() {
  local s; s="$(trim "$1")"
  while [[ -n "$s" ]]; do
    # numeric prefix?
    if [[ "$s" =~ ^[0-9]{1,2}$ ]]; then
      (( 0 <= 10#$s && 10#$s <= 32 )) || { s="${s%?}"; continue; }
      printf '%s\n' "$s"
      return 0
    fi
    # dotted mask?
    if [[ "$s" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && prefix_from_mask "$s" >/dev/null 2>&1; then
      printf '%s\n' "$s"
      return 0
    fi
    s="${s%?}"
  done
  printf '\n'
  return 0
}

to_prefix() {
  local v="$1"
  if [[ -z "$v" ]]; then
    return 1
  elif [[ "$v" =~ ^[0-9]{1,2}$ ]]; then
    (( 0 <= 10#$v && 10#$v <= 32 )) || return 1
    printf '%d\n' "$((10#$v))"
  else
    prefix_from_mask "$v"
  fi
}

# Network arithmetic
network_of() {
  local ip="$1" pfx="$2"
  local ipn maskn
  ipn="$(ipv4_to_int "$ip")"
  maskn="$(ipv4_to_int "$(mask_from_prefix "$pfx")")"
  int_to_ipv4 $(( ipn & maskn ))
}

broadcast_of() {
  local ip="$1" pfx="$2"
  local ipn maskn
  ipn="$(ipv4_to_int "$ip")"
  maskn="$(ipv4_to_int "$(mask_from_prefix "$pfx")")"
  int_to_ipv4 $(( (ipn & maskn) | ((~maskn) & 0xFFFFFFFF) ))
}

in_same_subnet() {
  local ip="$1" gw="$2" pfx="$3"
  [[ "$(network_of "$ip" "$pfx")" == "$(network_of "$gw" "$pfx")" ]]
}

# -------- parse args --------
IP_RAW="${1:-}"
MASK_OR_PFX_RAW="${2:-}"
GW_RAW="${3:-}"
DNS1_RAW="${4:-}"
IFACE="${5:-eth0}"

[[ -n "$IP_RAW" ]] || { echo "ERROR: IP is required" >&2; exit 2; }

# Tail-trim inputs to the nearest valid form, or empty
IP="$(trim_tail_to_valid_ipv4 "$IP_RAW")"
[[ -n "$IP" ]] || { echo "ERROR: Invalid IP after tail-trim: '$IP_RAW'" >&2; exit 2; }

MASK_OR_PFX_CLEAN="$(trim_tail_to_valid_mask_or_prefix "$MASK_OR_PFX_RAW")"

# Compute prefix (defaults if missing)
if [[ -z "$MASK_OR_PFX_CLEAN" ]]; then
  PFX=24
else
  PFX="$(to_prefix "$MASK_OR_PFX_CLEAN")" || { echo "ERROR: Invalid netmask/prefix: '$MASK_OR_PFX_RAW'" >&2; exit 2; }
fi

# Gateway
GW=""
if [[ -n "$GW_RAW" ]]; then
  GW="$(trim_tail_to_valid_ipv4 "$GW_RAW")"
  [[ -n "$GW" ]] || { echo "ERROR: Invalid gateway after tail-trim: '$GW_RAW'" >&2; exit 2; }
else
  # Derive from network (/31-/32 have no host space)
  if (( PFX >= 31 )); then
    echo "ERROR: Cannot derive gateway for /31-/32; please provide gateway explicitly" >&2
    exit 2
  fi
  NET="$(network_of "$IP" "$PFX")"
  BC="$(broadcast_of "$IP" "$PFX")"
  # first host
  local_first="$(int_to_ipv4 $(( $(ipv4_to_int "$NET") + 1 )))"
  local_last="$(int_to_ipv4 $(( $(ipv4_to_int "$BC") - 1 )))"
  GW="$local_first"
  [[ "$GW" != "$IP" ]] || GW="$local_last"
fi

# DNS
DNS2="8.8.8.8"
if [[ -n "$DNS1_RAW" ]]; then
  DNS1="$(trim_tail_to_valid_ipv4 "$DNS1_RAW")"
  # If still invalid => fallback to GW
  [[ -n "$DNS1" ]] || DNS1="$GW"
else
  DNS1="$GW"
fi
DNS="$DNS1 $DNS2"

# Final preflight checks
is_valid_ipv4 "$GW"  || { echo "ERROR: Gateway not valid: '$GW'" >&2; exit 2; }
is_valid_ipv4 "$DNS1" || { echo "ERROR: DNS1 not valid: '$DNS1'" >&2; exit 2; }
is_valid_ipv4 "$DNS2" || { echo "ERROR: DNS2 not valid: '$DNS2'" >&2; exit 2; }
in_same_subnet "$IP" "$GW" "$PFX" || { echo "ERROR: Gateway '$GW' not in subnet of $IP/$PFX" >&2; exit 2; }

ADDR="${IP}/${PFX}"

# Find or create a connection bound to IFACE
CONN="$("$NMCLI" -t -f NAME,DEVICE con show | awk -F: -v IF="$IFACE" '$2==IF{print $1; exit}')" || true
if [[ -z "${CONN:-}" ]]; then
  CONN="companion-${IFACE}"
  sudo -n "$NMCLI" con add type ethernet ifname "$IFACE" con-name "$CONN" || true
fi

# Apply
sudo -n "$NMCLI" con mod "$CONN" \
  connection.interface-name "$IFACE" \
  ipv4.method manual \
  ipv4.addresses "$ADDR" \
  ipv4.gateway "$GW" \
  ipv4.dns "$DNS" \
  ipv4.ignore-auto-dns yes \
  ipv6.method ignore \
  autoconnect yes

if ! sudo -n "$NMCLI" con up "$CONN"; then
  sudo -n "$NMCLI" dev reapply "$IFACE" || true
  sudo -n "$NMCLI" con down "$CONN" || true
  sudo -n "$NMCLI" con up "$CONN"
fi

echo "OK: $CONN -> $ADDR  gw=$GW  dns=$DNS"

