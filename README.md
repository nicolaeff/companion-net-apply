# Companion Network Apply (StreamDeck XL)

A minimal, operator-friendly way to set a Raspberry Pi’s **Ethernet** settings directly from **Bitfocus Companion** on a **StreamDeck XL**—no external apps, no HID hacking.

* Enter IPv4, subnet mask (dotted **or** numeric CIDR), gateway, and DNS1 on the deck
* Apply via Companion’s **Run shell path (local)**
* Uses **NetworkManager** (`nmcli`) under the hood
* One-tap **DHCP** fallback

> **Note:** This layout targets **StreamDeck XL** (and XL emulators). Smaller decks are **not supported** due to layout density.

---

## What it does

### On-deck input & validation

Companion’s **Generic Data Entry** plus expressions/feedbacks validate each octet and the full address before you hit **APPLY**. Visual states (green / yellow / red) guide the operator.

### System-level apply

Two tiny bash scripts:

* `nm-apply-ip.sh` — set static IPv4 on `eth0` (or another interface)
* `nm-apply-dhcp.sh` — switch interface to DHCP

### Operator-friendly defaults

* Subnet mask may be entered as **`255.255.255.0`** or **`24`** (CIDR **number**, no slash).
* **DNS2** is always `8.8.8.8`.
* If **mask/gateway/DNS1 are omitted**, the script derives sensible defaults:
  mask = `/24`, gateway = first host in the subnet (or last if the IP is `.1`), DNS1 = gateway.
* Inputs are **not normalized** inside octets; only **trailing garbage** (extra dots/digits at the end) is trimmed.

---

## Requirements

* Raspberry Pi OS **Bookworm** (or any Linux) with **NetworkManager** enabled
* **Bitfocus Companion 3.5+**
* **StreamDeck XL** or an **XL emulator**
* Ability to grant `sudo` rights for `nmcli` to the Companion service user

> **NetworkManager notes**
>
> * Ensure the NIC is managed by NetworkManager:
>
>   ```bash
>   nmcli device status
>   ```
>
>   The target interface (e.g. `eth0`) should show `managed` and an NM state.
> * If another DHCP client/service manages the interface (e.g. `dhcpcd`, legacy tools), disable it and enable NM:
>
>   ```bash
>   sudo systemctl disable --now dhcpcd || true
>   sudo systemctl enable --now NetworkManager
>   ```
> * Install if missing:
>
>   ```bash
>   sudo apt-get update && sudo apt-get install -y network-manager
>   ```

---

## Quick Start

See also: [`docs/INSTALL.md`](docs/INSTALL.md) • [`docs/VARIABLES.md`](docs/VARIABLES.md) • [`docs/COMPANION.md`](docs/COMPANION.md)

### 1) Install scripts

```bash
# from repo root
sudo cp scripts/nm-apply-ip.sh   /usr/local/bin/
sudo cp scripts/nm-apply-dhcp.sh /usr/local/bin/
sudo chmod 0755 /usr/local/bin/nm-apply-*.sh
```

### 2) Grant `nmcli` sudo (no password)

Create `/etc/sudoers.d/companion-nm` via `visudo` and allow your Companion service user (e.g. `companion`) to run `nmcli`:

```
Cmnd_Alias NM_OK = /usr/bin/nmcli, /usr/bin/nmcli *
companion ALL=(root) NOPASSWD: NM_OK
```

### 3) Import the page (recommended)

In Companion UI: **Import → Page** → select a page export from `pages/`
(e.g. `pages/ip_set_page_*_export.companionconfig`).

> **Avoid Full Import** unless you intend to overwrite your entire Companion configuration. See **Backups & Imports** below.

### 4) Create variables (required)

Companion cannot import “variables only”. Add the variables listed in **`docs/VARIABLES.md`** (IP, mask/prefix, gateway, DNS1; plus boolean expressions for validity).

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

> Replace `eth0` if your interface name differs (`end0`, `enx…`).

---

## Operator Flow

1. Type **IP**, **MASK** (dotted or CIDR number, e.g. `24`), **GW**, **DNS1** on the deck.
2. Check the visual status (per-octet + whole-address).
3. Press **APPLY** to configure; use **DHCP** for automatic addressing.

---

## Project Structure

```
docs/           # INSTALL / VARIABLES / Companion wiring notes
full_backups/   # full Companion exports (Full Import will overwrite everything)
pages/          # page-level exports for XL (preferred import target)
scripts/        # system scripts (bash)
sudoers/        # sudoers snippet for nmcli
.gitattributes
.gitignore
LICENSE
README.md
```

---

## Backups & Imports

* **Preferred:** Import a **single Page** from `pages/` via *Import → Page*.
* **Full Import:** Files in `full_backups/` are full configuration exports.
  **Warning:** Full Import **replaces** devices, pages, variables, and triggers.
  Always export a backup first (Companion **Settings → Backup**).

For details on imports, feedback wiring, and layout notes, see **`docs/COMPANION.md`**.

---

## Design Notes

* Pure Companion: **no** separate HID app or resident service.
* Local execution: **Run shell path (local)** avoids SSH/HTTP hops.
* Safe by default: Companion validates; scripts re-check and fail fast on invalid input.
* DNS2 is always `8.8.8.8` (operator sets only DNS1).
* Comments and docs are kept **in English** (project standard).

---

## Roadmap

* Startup “gate” screen (countdown + Accept/Change)
* IP-only convenience mode toggle (defaults already supported in scripts)
* Multi-interface selector on deck
* Status read-back (show effective values on deck)

---

## License

MIT — see `LICENSE`.

---

## Support / Contributions

Issues and PRs welcome.
When exporting from Companion, prefer **page exports** (not full configs) to avoid clobbering existing setups.
Please keep code comments and docs **in English**.

