Companion Network Apply (StreamDeck XL)

A minimal, operator-friendly way to set a Raspberry Pi’s Ethernet settings directly from Bitfocus Companion on a StreamDeck XL—no external apps, no HID hacking.

Enter IPv4, subnet mask (dotted or CIDR), gateway, and DNS1 from the deck.

Apply via Companion’s Run shell path (local).

Uses NetworkManager (nmcli) under the hood.

One-tap DHCP fallback.

Designed for StreamDeck XL / XL emulators (layout won’t fit smaller decks).

What it does

On-deck input & validation
Companion’s Generic Data Entry + expressions/feedbacks validate each octet and the whole address before you hit APPLY. Visual states (green/yellow/red) guide the operator.

System-level apply
Two tiny bash scripts:

nm-apply-ip.sh — set static IPv4 on eth0 (or another interface)

nm-apply-dhcp.sh — switch interface to DHCP

Defaults that help operators

Mask may be entered as 255.255.255.0 or /24.

DNS2 is enforced to 8.8.8.8.

(Optional behavior ready to enable later): if only IP is provided, derive reasonable defaults (mask /24, gateway = first host, DNS1 = gateway).

Requirements

Raspberry Pi OS Bookworm (or any Linux) with NetworkManager enabled

Bitfocus Companion 3.5+

StreamDeck XL or an XL emulator

Ability to grant sudo rights for nmcli to the Companion service user

Quick Start

Install scripts

/usr/local/bin/nm-apply-ip.sh
/usr/local/bin/nm-apply-dhcp.sh
chmod 0755 /usr/local/bin/nm-apply-*.sh


Grant nmcli sudo (no password)
Create /etc/sudoers.d/companion-nm via visudo and allow your Companion service user (e.g. companion) to run nmcli:

Cmnd_Alias NM_OK = /usr/bin/nmcli, /usr/bin/nmcli *
companion ALL=(root) NOPASSWD: NM_OK


Import the page
In Companion UI: Import → Page → select the provided .companionconfig from pages/.

Create custom variables
Add the variables listed in docs/VARIABLES.md (IP, mask/prefix, gateway, DNS1; plus boolean expressions for validity).

Wire the APPLY/DHCP buttons
Each calls Run shell path (local):

APPLY:

/usr/local/bin/nm-apply-ip.sh \
  $(internal:custom_ip_addr) \
  $(internal:custom_prefix) \
  $(internal:custom_gateway) \
  $(internal:custom_dns1) \
  eth0


DHCP:

/usr/local/bin/nm-apply-dhcp.sh eth0


Replace eth0 if your interface name differs.

Operator Flow

Type IP, MASK (dotted or /xx), GW, DNS1.

Visual feedback shows per-octet and whole-address validity.

Press APPLY → scripts configure NetworkManager instantly.

Need auto-assignment? Press DHCP.

Project Structure
scripts/          # system scripts (bash)
sudoers/          # sudoers snippet for nmcli
pages/            # Companion .companionconfig exports (XL layout)
docs/             # INSTALL/VARIABLES/notes

Design Notes

Pure Companion: no separate HID app or service.

Local execution: Run shell path (local) avoids SSH/HTTP hops.

Safe by default: validation in Companion; script double-checks and exits cleanly on invalid inputs.

Second DNS is always 8.8.8.8 (operator sets only DNS1).

Roadmap

Optional “gate” page on startup (countdown + Accept/Change).

“IP-only” convenience mode (derive mask/GW/DNS1 automatically).

Multi-interface support (eth0, end0, etc.) via on-deck selector.

Status poll (readback) and display effective values.

License

MIT — see LICENSE.

Support / Contributions

Issues and PRs welcome. Export Companion pages (not full configs) to avoid clobbering existing setups.
