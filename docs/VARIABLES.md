# VARIABLES

This project relies on a small set of **custom variables** (string) and **expression variables** (boolean) inside Bitfocus Companion.
All names below are **case-sensitive** and should be created exactly as written.

---

## 1) Custom variables (strings)

> Companion UI → **Variables** → **Add** (custom)

| Name             | Type   |                 Example | Purpose                                             |
| ---------------- | ------ | ----------------------: | --------------------------------------------------- |
| `custom_ip_addr` | string |         `192.168.12.25` | Full IPv4 address to apply                          |
| `custom_prefix`  | string | `255.255.255.0` or `24` | Subnet mask (dotted) or CIDR prefix                 |
| `custom_gateway` | string |          `192.168.12.1` | Default gateway                                     |
| `custom_dns1`    | string |          `192.168.12.1` | Primary DNS (DNS2 is fixed to `8.8.8.8` in scripts) |

> Notes
> • `custom_prefix` accepts either dotted mask *or* CIDR (e.g., `/24` → just `24`).
> • `custom_dns2` is **not** needed — it’s enforced to `8.8.8.8` by the scripts.

---

## 2) Expression variables (booleans)

> Companion UI → **Variables** → **Add Expression**
> Switch the editor to **Expression mode** (`$`) and paste the code.

### 2.1 `custom_ip_valid`

Validates a full IPv4 in `custom_ip_addr`.

```text
s = trim($(internal:custom_ip_addr));
a = split(s, ".");
length(a) == 4
&& strlen(a[0]) >= 1 && strlen(a[0]) <= 3 && isNumber(+a[0]) && +a[0] >= 0 && +a[0] <= 255
&& strlen(a[1]) >= 1 && strlen(a[1]) <= 3 && isNumber(+a[1]) && +a[1] >= 0 && +a[1] <= 255
&& strlen(a[2]) >= 1 && strlen(a[2]) <= 3 && isNumber(+a[2]) && +a[2] >= 0 && +a[2] <= 255
&& strlen(a[3]) >= 1 && strlen(a[3]) <= 3 && isNumber(+a[3]) && +a[3] >= 0 && +a[3] <= 255
```

### 2.2 `custom_gateway_valid`

Same IPv4 check for `custom_gateway`.

```text
s = trim($(internal:custom_gateway));
a = split(s, ".");
length(a) == 4
&& strlen(a[0]) >= 1 && strlen(a[0]) <= 3 && isNumber(+a[0]) && +a[0] >= 0 && +a[0] <= 255
&& strlen(a[1]) >= 1 && strlen(a[1]) <= 3 && isNumber(+a[1]) && +a[1] >= 0 && +a[1] <= 255
&& strlen(a[2]) >= 1 && strlen(a[2]) <= 3 && isNumber(+a[2]) && +a[2] >= 0 && +a[2] <= 255
&& strlen(a[3]) >= 1 && strlen(a[3]) <= 3 && isNumber(+a[3]) && +a[3] >= 0 && +a[3] <= 255
```

### 2.3 `custom_dns1_valid`

Same IPv4 check for `custom_dns1`.

```text
s = trim($(internal:custom_dns1));
a = split(s, ".");
length(a) == 4
&& strlen(a[0]) >= 1 && strlen(a[0]) <= 3 && isNumber(+a[0]) && +a[0] >= 0 && +a[0] <= 255
&& strlen(a[1]) >= 1 && strlen(a[1]) <= 3 && isNumber(+a[1]) && +a[1] >= 0 && +a[1] <= 255
&& strlen(a[2]) >= 1 && strlen(a[2]) <= 3 && isNumber(+a[2]) && +a[2] >= 0 && +a[2] <= 255
&& strlen(a[3]) >= 1 && strlen(a[3]) <= 3 && isNumber(+a[3]) && +a[3] >= 0 && +a[3] <= 255
```

### 2.4 `custom_prefix_valid`

Accepts **either** dotted mask with contiguous ones (e.g., `255.255.255.0`) **or** numeric CIDR `0..32`.

```text
s = trim($(internal:custom_prefix));

isNumeric = isNumber(+s) && +s >= 0 && +s <= 32;

isDotted =
  includes(s, ".")
  && (
    a = split(s, ".");
    length(a) == 4
    && arrayIncludes(["0","128","192","224","240","248","252","254","255"], a[0])
    && arrayIncludes(["0","128","192","224","240","248","252","254","255"], a[1])
    && arrayIncludes(["0","128","192","224","240","248","252","254","255"], a[2])
    && arrayIncludes(["0","128","192","224","240","248","252","254","255"], a[3])

    // Non-increasing sequence by rank (255 >= 254 >= ... >= 0)
    && (
      order = ["255","254","252","248","240","224","192","128","0"];
      r0 = arrayIndexOf(order, a[0]);
      r1 = arrayIndexOf(order, a[1]);
      r2 = arrayIndexOf(order, a[2]);
      r3 = arrayIndexOf(order, a[3]);
      r0 <= r1 && r1 <= r2 && r2 <= r3
    )

    // At most one "partial" octet (not 255 and not 0)
    && (
      p0 = (a[0] != "255" && a[0] != "0") ? 1 : 0;
      p1 = (a[1] != "255" && a[1] != "0") ? 1 : 0;
      p2 = (a[2] != "255" && a[2] != "0") ? 1 : 0;
      p3 = (a[3] != "255" && a[3] != "0") ? 1 : 0;
      (p0 + p1 + p2 + p3) <= 1
    )

    // If a partial exists at position k, all following octets must be 0
    && (
      (p0 == 1 && a[1] == "0" && a[2] == "0" && a[3] == "0")
      || (p1 == 1 && a[2] == "0" && a[3] == "0")
      || (p2 == 1 && a[3] == "0")
      || (p0 + p1 + p2 + p3 == 0)  // no partials -> all 255/0, also valid
    )
  );

isNumeric || isDotted
```

### 2.5 `all_valid`

Turns `true` only when **everything** is valid. Useful to lock “APPLY” visuals or as a guard.

```text
bool($(expression:custom_ip_valid))
&& bool($(expression:custom_prefix_valid))
&& bool($(expression:custom_dns1_valid))
&& bool($(expression:custom_gateway_valid))
```

---

## 3) Recommended visuals (optional)

* **Green** when a block is valid, **Yellow** when “almost ok” (valid octet but missing the dot), **Red** otherwise.
* Make **APPLY** show a “disabled” look unless `$(expression:all_valid)` is `true`.
  (You can do this with **Step expressions** or a conditional “proxy press” as discussed in README.)

---

## 4) Notes

* Keep comments and docs **in English** (project standard).
* DNS2 is not a variable — scripts always set it to `8.8.8.8`.
* If you ever rename variables, update both button texts **and** expressions accordingly.

