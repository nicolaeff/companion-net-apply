#!/usr/bin/env bash
# Switch an interface to DHCP via NetworkManager (nmcli).

set -euo pipefail

NMCLI="/usr/bin/nmcli"
IFACE="${1:-eth0}"

# Find or create a connection bound to IFACE
CONN="$("$NMCLI" -t -f NAME,DEVICE con show | awk -F: -v IF="$IFACE" '$2==IF{print $1; exit}')" || true
if [[ -z "${CONN:-}" ]]; then
  CONN="companion-${IFACE}"
  sudo -n "$NMCLI" con add type ethernet ifname "$IFACE" con-name "$CONN" || true
fi

sudo -n "$NMCLI" con mod "$CONN" \
  connection.interface-name "$IFACE" \
  ipv4.method auto \
  ipv4.addresses "" \
  ipv4.gateway "" \
  ipv4.dns "" \
  ipv6.method ignore \
  autoconnect yes

sudo -n "$NMCLI" con up "$CONN" || sudo -n "$NMCLI" dev reapply "$IFACE"
echo "OK: $CONN -> DHCP"

