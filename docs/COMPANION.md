# Companion Setup Guide (Deck UI & Wiring)

This document explains **how the Companion page works**, how to **import** it safely, and how to **wire** actions/feedbacks. Keep all code comments and docs in **English**.

---

## 1) Import options (IMPORTANT)

* **Preferred:** Import a **single Page** from `pages/*.companionconfig`
  *Companion UI → Import → Page → pick the XL layout file.*

* **Full Import (backup restore):** files in `backups/`
  *Warning:* Full Import **overwrites the entire Companion configuration** (devices, pages, variables, triggers).
  Always export a backup before doing this.

---

## 2) Variables (must be created manually)

Companion cannot import “variables only”. Create these variables by hand:

* **Custom string variables:** `custom_ip_addr`, `custom_prefix`, `custom_gateway`, `custom_dns1`
* **Expression (boolean) variables:**
  `custom_ip_valid`, `custom_prefix_valid`, `custom_gateway_valid`, `custom_dns1_valid`, `all_valid`

> All exact expressions are in `docs/VARIABLES.md`.
> In the expression editor, switch to **Expression mode** (the `$` button).

---

## 3) Page layout (StreamDeck XL)

* **Top row (4 blocks):** visual split of the IP entry

  * Block 1: `192.`
  * Block 2: `168.`
  * Block 3: `1.`
  * Block 4: `1`
    Each block’s **Button text** is an *expression* reading from the current input (we use `entry_raw`) and displays only its part.

* **Middle rows:** numeric keypad, dot (`.`), delete/backspace, clear, move cursor (if you use cursor mode), etc.

* **Bottom row:** `APPLY`, `DHCP`, optional helper/info/status.

> The provided page export is designed for **StreamDeck XL / XL emulators** only.

---

## 4) Button text (expressions)

Set Button text to **Expression mode** (`$`) and paste:

**Block 1**

```
s = trim($(dataentry:entry_raw));
a = split(s, ".");
length(a) >= 2 ? concat(a[0], ".") : (length(a) >= 1 ? a[0] : "")
```

**Block 2**

```
s = trim($(dataentry:entry_raw));
a = split(s, ".");
length(a) >= 3 ? concat(a[1], ".") : (length(a) >= 2 ? a[1] : "")
```

**Block 3**

```
s = trim($(dataentry:entry_raw));
a = split(s, ".");
length(a) >= 4 ? concat(a[2], ".") : (length(a) >= 3 ? a[2] : "")
```

**Block 4 (no trailing dot)**

```
s = trim($(dataentry:entry_raw));
a = split(s, ".");
length(a) >= 4 ? a[3] : ""
```

---

## 5) Feedbacks (valid / almost-ok)

Use **Feedback → internal → Variable → Check boolean expression** (switch to `$`).

* **Green (valid) per block:** see `docs/VARIABLES.md` (we validate octet range `0..255` and presence of the next dot for blocks 1–3).
* **Yellow (almost):** valid octet but **no dot yet** after it (for blocks 1–3); for block 4, valid octet but user added an **extra trailing dot**.

> Order matters: put **Green** above **Yellow** in the feedback list so Green wins when fully valid.

---

## 6) APPLY / DHCP actions (wiring)

**APPLY → Run shell path (local):**

```bash
/usr/local/bin/nm-apply-ip.sh \
  $(internal:custom_ip_addr) \
  $(internal:custom_prefix) \
  $(internal:custom_gateway) \
  $(internal:custom_dns1) \
  eth0
```

**DHCP → Run shell path (local):**

```bash
/usr/local/bin/nm-apply-dhcp.sh eth0
```

> Replace `eth0` with your actual interface name if different.
> Scripts and sudoers setup are described in `docs/INSTALL.md`.

---

## 7) APPLY guarding (visuals)

This project is designed to **encourage** action, not block it. Two approaches:

* **Recommended (current):** Keep APPLY pressable, but use `$(expression:all_valid)` to **color** the button (e.g., gray when false, green when true).

* **Optional lock-out:** Use **Step expressions** so only the “valid” step has actions.

  * Step 1 (invalid): `!bool($(expression:all_valid))` → no actions
  * Step 2 (valid): `bool($(expression:all_valid))` → run shell path

---

## 8) Notes & gotchas

* **`entry_raw` vs `entry_cursor`:**
  Our expressions use `entry_raw`. If you use `entry_cursor`, the string contains `|` cursor — strip it first or switch back to `entry_raw`.

* **Absolute paths:**
  For shell actions, always use full paths (`/usr/local/bin/...`, `/usr/bin/nmcli`).

* **Sudoers:**
  If APPLY does nothing, check sudoers for the Companion service user. Test with:
  `sudo -u <user> -H sudo -n /usr/bin/nmcli -g general.state g`

* **Interface name:**
  Change `eth0` in button actions if your NIC name differs (`end0`, `enx…`).

* **Full Import warning:**
  Only import from `backups/` if you intend to reset the whole Companion configuration.

---

## 9) Customization ideas

* Startup “gate” screen (countdown + Accept/Change) before Companion loads the main page.
* IP-only convenience mode (derive `/24`, GW=first host, DNS1=GW) — scripts already support this pattern if you enable it later.
* Multi-interface selector on deck (toggle target NIC variable and pass it to the script).

---

