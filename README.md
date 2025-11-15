# Companion Network Apply (StreamDeck XL)

A minimal, operator-friendly way to set a Raspberry Pi’s **Ethernet** settings directly from **Bitfocus Companion** on a **StreamDeck XL**—no external apps, no HID hacking.

* Enter IPv4, subnet mask (dotted or CIDR), gateway, and DNS1 from the deck.
* Apply via Companion’s **Run shell path (local)**.
* Uses **NetworkManager** (`nmcli`) under the hood.
* One-tap **DHCP** fallback.

> **Note:** This layout is designed for **StreamDeck XL** (and XL emulators). It will not fit smaller decks.

---

## What it does

### On-deck input & validation

Companion’s **Generic Data Entry** + expressions/feedbacks validate each octet and the full address before you hit **APPLY**. Visual states (green / yellow / red) guide the operator.

### System-level apply

Two tiny bash scripts:

* `nm-apply-ip.sh` — set static IPv4 on `eth0` (or another interface)
* `nm-apply-dhcp.sh` — switch interface to DHCP

### Operator-friendly defaults

* Subnet mask can be entered as `255.255.255.0` **or** `/24`.
* `DNS2` is always set to `8.8.8.8`.
* *(Optional, future switch)* If only IP is provided, derive sensible defaults (mask `/24`, gateway = first host, DNS1 = gateway).

---

## Requirements

* Raspberry Pi OS **Bookworm** (or any Linux) with **NetworkManager** enabled
* **Bitfocus Companion 3.5+**
* **StreamDeck XL** or an **XL emulator**
* Ability to grant `sudo` rights for `nmcli` to the Companion service user

---

## Quick Start

### 1) Install scripts

```bash
# place scripts
sudo cp scripts/nm-apply-ip.sh /usr/local/bin/
sudo cp scripts/nm-apply-dhcp.sh /usr/local/bin/
sudo chmod 0755 /usr/local/bin/nm-apply-*.sh
```

### 2) Grant `nmcli` sudo (no password)

Create `/etc/sudoers.d/companion-nm` via `visudo` and allow your Companion service user (e.g. `companion`) to run `nmcli`:

```
Cmnd_Alias NM_OK = /usr/bin/nmcli, /usr/bin/nmcli *
companion ALL=(root) NOPASSWD: NM_OK
```

### 3) Import the page

In Companion UI: **Import → Page** → select the provided `.companionconfig` from `pages/`.

### 4) Create custom variables

Add the variables listed in `docs/VARIABLES.md` (IP, mask/prefix, gateway, DNS1; plus boolean expressions for validity).

### 5) Wire the APPLY / DHCP buttons

Each calls **Run shell path (local)**.

**APPLY**

```bash
/usr/local/bin/nm-apply-ip.sh \
  $(internal:custom_ip_addr) \
  $(internal:custom_prefix) \
  $(internal:custom_gateway) \
  $(internal:custom_dns1) \
  eth0
```

**DHCP**

```bash
/usr/local/bin/nm-apply-dhcp.sh eth0
```

> Replace `eth0` if your interface name differs.

---

## Operator Flow

1. Type **IP**, **MASK** (dotted or `/xx`), **GW**, **DNS1**.
2. Visual feedback shows per-octet and whole-address validity.
3. Press **APPLY** → scripts configure NetworkManager instantly.
4. Need auto-assignment? Press **DHCP**.

---

## Project Structure

```
scripts/   # system scripts (bash)
sudoers/   # sudoers snippet for nmcli
pages/     # Companion .companionconfig exports (XL layout)
docs/      # INSTALL / VARIABLES / notes
```

---

## Design Notes

* Pure Companion: **no** separate HID app or service.
* Local execution: **Run shell path (local)** avoids SSH/HTTP hops.
* Safe by default: validation in Companion; the script double-checks and exits cleanly on invalid inputs.
* Second DNS is always `8.8.8.8` (operator sets only DNS1).

---

## Roadmap

* Optional “gate” page on startup (countdown + Accept/Change).
* “IP-only” convenience mode (derive mask/GW/DNS1 automatically).
* Multi-interface support (`eth0`, `end0`, etc.) via on-deck selector.
* Status poll (read-back) and display of effective values.

---

## License

MIT — see `LICENSE`.

---

## Support / Contributions

Issues and PRs welcome.
When exporting from Companion, prefer **pages** (not full configs) to avoid clobbering existing setups.
