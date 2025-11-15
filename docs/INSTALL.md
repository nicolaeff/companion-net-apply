# INSTALL / SETUP

This guide covers importing the Companion page, adding variables **manually**, and wiring the APPLY/DHCP actions.

> **Important:** Companion’s **Full Import** replaces the entire configuration (devices, pages, variables, triggers).
> For safety, **prefer importing a single Page** from `pages/*.companionconfig`. If you do need Full Import, **export a backup first** (Settings → Backup).

---

## 1) System scripts

Copy the scripts and make them executable:

```bash
sudo cp scripts/nm-apply-ip.sh   /usr/local/bin/
sudo cp scripts/nm-apply-dhcp.sh /usr/local/bin/
sudo chmod 0755 /usr/local/bin/nm-apply-*.sh
```

Grant `nmcli` passwordless sudo for the Companion service user (e.g. `companion`):

```bash
sudo visudo -f /etc/sudoers.d/companion-nm
```

Paste:

```
Cmnd_Alias NM_OK = /usr/bin/nmcli, /usr/bin/nmcli *
companion ALL=(root) NOPASSWD: NM_OK
```

---

## 2) Import the Companion page

In the Companion UI:

* **Import → Page** → pick `pages/ip_setup_page.companionconfig` (StreamDeck **XL** layout).
* Do **not** choose **Full Import**, unless you intend to overwrite your entire setup.

---

## 3) Create variables manually (required)

Companion cannot import “variables only”, so add them by hand:

### 3.1 Custom variables (strings)

Companion → **Variables** → **Add**:

* `custom_ip_addr` (string)
* `custom_prefix` (string)
* `custom_gateway` (string)
* `custom_dns1` (string)

Leave values empty — they will be filled from the on-deck input.

### 3.2 Expression variables (booleans)

Companion → **Variables** → **Add Expression**.
Create:

* `custom_ip_valid` — paste expression from `docs/VARIABLES.md`
* `custom_prefix_valid` — paste expression from `docs/VARIABLES.md`
* `custom_gateway_valid` — paste expression from `docs/VARIABLES.md`
* `custom_dns1_valid` — paste expression from `docs/VARIABLES.md`
* `all_valid` — aggregate expression from `docs/VARIABLES.md`

> Tip: keep `docs/VARIABLES.md` open side-by-side and copy expressions exactly as-is.

---

## 4) Wire the buttons

On the **APPLY** button add **Run shell path (local)**:

```bash
/usr/local/bin/nm-apply-ip.sh \
  $(internal:custom_ip_addr) \
  $(internal:custom_prefix) \
  $(internal:custom_gateway) \
  $(internal:custom_dns1) \
  eth0
```

On the **DHCP** button add **Run shell path (local)**:

```bash
/usr/local/bin/nm-apply-dhcp.sh eth0
```

> Replace `eth0` with your interface name if needed.

---

## 5) Operator workflow

1. Type **IP**, **MASK** (dotted or `/xx`), **GW**, **DNS1** on the deck.
2. Check the visual status (per-octet + whole-address).
3. Press **APPLY** to configure; use **DHCP** to revert to automatic addressing.

---

## 6) Troubleshooting

* Button seems to do nothing → check sudoers:
  `sudo -u <companion-user> -H sudo -n /usr/bin/nmcli -g general.state g`
* “Permission denied” → ensure the scripts in `/usr/local/bin` are `0755` and owned by `root:root`.
* Interface name mismatch → replace `eth0` in button actions (common names: `eth0`, `end0`, `enx…`).

