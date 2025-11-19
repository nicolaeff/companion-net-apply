#!/usr/bin/env bash
# Install helper for "companion-net-apply":
# - Downloads nm-apply-ip.sh and nm-apply-dhcp.sh from GitHub
# - Installs them into /usr/local/bin
# - Creates /etc/sudoers.d/companion-nm with passwordless sudo for nmcli
#
# Usage (local):
#   sudo ./install-companion-net-apply.sh -u companion
#
# Usage (one-liner from GitHub):
#   curl -fsSL https://raw.githubusercontent.com/nicolaeff/companion-net-apply/main/scripts/install-companion-net-apply.sh \
#     | sudo bash -s -- -u companion
#
# Options:
#   -u, --user USER   Companion service user (default: companion)
#   -r, --ref  REF    Git ref/branch/tag to fetch from (default: main)
#
# This script must be run as root (use sudo).

set -euo pipefail

# --- Defaults ---------------------------------------------------------------

REPO_OWNER="nicolaeff"
REPO_NAME="companion-net-apply"
REF="${COMPANION_NET_APPLY_REF:-main}"  # can be overridden via env or -r/--ref
COMPANION_USER="${COMPANION_USER:-companion}"

NMCLI_PATH="/usr/bin/nmcli"
VISUDO_PATH="/usr/sbin/visudo"

INSTALL_DIR="/usr/local/bin"
SUDOERS_DIR="/etc/sudoers.d"
SUDOERS_FILE="${SUDOERS_DIR}/companion-nm"

# --- Helpers ----------------------------------------------------------------

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  -u, --user USER   Companion service user (default: ${COMPANION_USER})
  -r, --ref  REF    Git ref/branch/tag to fetch from (default: ${REF})
  -h, --help        Show this help and exit

Environment overrides:
  COMPANION_USER           Default for --user
  COMPANION_NET_APPLY_REF  Default for --ref
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "This script must be run as root. Use: sudo $0 ..."
  fi
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

download_file() {
  local url="$1"
  local dst="$2"

  echo "Downloading: ${url}"
  if have_cmd curl; then
    curl -fsSL "$url" -o "$dst"
  elif have_cmd wget; then
    wget -q "$url" -O "$dst"
  else
    die "Neither curl nor wget found. Please install one of them."
  fi
}

backup_if_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local backup="${path}.bak.${ts}"
    echo "Backing up existing ${path} -> ${backup}"
    cp -p "$path" "$backup"
  fi
}

# --- Parse arguments --------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--user)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      COMPANION_USER="$2"
      shift 2
      ;;
    -r|--ref)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      REF="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

# --- Preflight checks -------------------------------------------------------

need_root

[[ -x "$NMCLI_PATH" ]]  || die "nmcli not found at ${NMCLI_PATH}. Install NetworkManager first."
[[ -x "$VISUDO_PATH" ]] || die "visudo not found at ${VISUDO_PATH}. Install sudo or fix VISUDO_PATH."

if ! id "$COMPANION_USER" >/dev/null 2>&1; then
  echo "WARNING: user '${COMPANION_USER}' does not exist yet."
  echo "         You can create it later; sudoers will still be prepared."
fi

BASE_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REF}"

echo "Using repository: ${REPO_OWNER}/${REPO_NAME}@${REF}"
echo "Target install dir: ${INSTALL_DIR}"
echo "Companion service user: ${COMPANION_USER}"
echo

mkdir -p "$INSTALL_DIR"

# --- Install nm-apply scripts -----------------------------------------------

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

for script_name in nm-apply-ip.sh nm-apply-dhcp.sh; do
  src_url="${BASE_URL}/scripts/${script_name}"
  tmp_path="${TMP_DIR}/${script_name}"
  dst_path="${INSTALL_DIR}/${script_name}"

  download_file "$src_url" "$tmp_path"

  # Basic sanity check: ensure file is not empty and looks like a shell script
  if [[ ! -s "$tmp_path" ]]; then
    die "Downloaded ${script_name} is empty. Aborting."
  fi
  if ! head -n 1 "$tmp_path" | grep -qE '^#!'; then
    die "Downloaded ${script_name} does not look like a script (missing shebang). Aborting."
  fi

  backup_if_exists "$dst_path"
  echo "Installing ${script_name} -> ${dst_path}"
  mv "$tmp_path" "$dst_path"
  chown root:root "$dst_path"
  chmod 0755 "$dst_path"
done

echo
echo "Installed nm-apply scripts:"
ls -l "${INSTALL_DIR}/nm-apply-"*.sh || true
echo

# --- Configure sudoers for nmcli -------------------------------------------

mkdir -p "$SUDOERS_DIR"

TMP_SUDOERS="$(mktemp)"
cat >"$TMP_SUDOERS" <<EOF
# Passwordless nmcli for Bitfocus Companion
Cmnd_Alias NM_OK = ${NMCLI_PATH}, ${NMCLI_PATH} *

${COMPANION_USER} ALL=(root) NOPASSWD: NM_OK
EOF

echo "Validating sudoers snippet with visudo..."
if ! "$VISUDO_PATH" -cf "$TMP_SUDOERS" >/dev/null 2>&1; then
  echo "Validation failed. Contents were:"
  echo "----------------------------------------"
  cat "$TMP_SUDOERS"
  echo "----------------------------------------"
  die "sudoers validation failed; refusing to install /etc/sudoers.d/companion-nm"
fi

backup_if_exists "$SUDOERS_FILE"
echo "Installing sudoers snippet -> ${SUDOERS_FILE}"
mv "$TMP_SUDOERS" "$SUDOERS_FILE"
chown root:root "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"

echo
echo "Sudoers entry installed. You can test it with:"
echo "  sudo -u ${COMPANION_USER} -H sudo -n ${NMCLI_PATH} -g general.state g"
echo

# --- Final info -------------------------------------------------------------

cat <<EOF
Done.

Next steps:

  1) In Companion, configure the APPLY and DHCP buttons to call:
       ${INSTALL_DIR}/nm-apply-ip.sh ...
       ${INSTALL_DIR}/nm-apply-dhcp.sh ...

  2) Ensure your target interface name (eth0, end0, etc.) matches
     what you pass from Companion actions.

  3) Verify NetworkManager manages the interface:
       ${NMCLI_PATH} device status

If anything goes wrong, check:
  - ${SUDOERS_FILE}
  - ${INSTALL_DIR}/nm-apply-ip.sh
  - ${INSTALL_DIR}/nm-apply-dhcp.sh
EOF

