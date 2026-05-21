#!/usr/bin/env bash
# ============================================================================
# Ligolo-NG pivot wrapper installer (Arch / CachyOS / Kali)
#
# Portable rewrite:
#   - No hardcoded username (uses $USER / $SUDO_USER / id -un)
#   - No hardcoded path. Workspace = directory this script lives in.
#   - Auto-patches LIGOLO_DIR inside tunnels.sh and ligolofix.sh
#   - Auto-installs ligoloup / ligolofix aliases for zsh and/or bash
#   - Drops stale install bugs (Windows agent fetch fixed, idempotent re-runs)
# ============================================================================

set -euo pipefail

# -- color helpers -----------------------------------------------------------
RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[1;33m'
CYN=$'\033[0;36m'; BLD=$'\033[1m';   NC=$'\033[0m'

say()  { printf '%s[*]%s %s\n' "$CYN" "$NC" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$GRN" "$NC" "$*"; }
warn() { printf '%s[!]%s %s\n' "$YLW" "$NC" "$*"; }
die()  { printf '%s[X]%s %s\n' "$RED" "$NC" "$*" >&2; exit 1; }

# -- config ------------------------------------------------------------------
VERSION="${LIGOLO_VERSION:-0.8.3}"

# Real user (works correctly even if invoked via sudo)
CURRENT_USER="${SUDO_USER:-$(id -un)}"

# Workspace = directory this script lives in (whatever the repo dir is)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)"
WORKSPACE="$SCRIPT_DIR"

PROXY_BIN="$WORKSPACE/proxy"
AGENT_DIR="$WORKSPACE/agents"
YAML_FILE="$WORKSPACE/ligolo-ng.yaml"

REL_BASE="https://github.com/nicocha30/ligolo-ng/releases/download/v${VERSION}"

# host arch detection for the local proxy
HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  x86_64)  PROXY_ARCH="amd64" ;;
  aarch64) PROXY_ARCH="arm64" ;;
  armv7l)  PROXY_ARCH="armv7" ;;
  *)       PROXY_ARCH="amd64"; warn "Unknown host arch '$HOST_ARCH', defaulting proxy to amd64" ;;
esac

printf '%s\n' "$BLD============================================================$NC"
say "Ligolo-NG pivot wrapper installer"
printf '    version:    %s\n' "$VERSION"
printf '    workspace:  %s\n' "$WORKSPACE"
printf '    user:       %s\n' "$CURRENT_USER"
printf '    host arch:  %s (%s)\n' "$HOST_ARCH" "$PROXY_ARCH"
printf '%s\n' "$BLD============================================================$NC"

# -- required tools ----------------------------------------------------------
say "Checking required tools"
for t in curl tar unzip ip; do
  command -v "$t" >/dev/null 2>&1 || die "Missing required tool: $t"
done
ok "curl / tar / unzip / iproute2 present"

# -- workspace ---------------------------------------------------------------
say "Staging workspace at $WORKSPACE"
mkdir -p "$AGENT_DIR"
ok "workspace ready"

# -- fetch proxy -------------------------------------------------------------
PROXY_TARBALL="ligolo-ng_proxy_${VERSION}_linux_${PROXY_ARCH}.tar.gz"
say "Fetching ligolo-proxy ${VERSION} (linux/${PROXY_ARCH})"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
if curl -fL --progress-bar "${REL_BASE}/${PROXY_TARBALL}" -o "$TMP/proxy.tgz"; then
  tar -xzf "$TMP/proxy.tgz" -C "$TMP" proxy
  install -m 0755 "$TMP/proxy" "$PROXY_BIN"
  ok "$PROXY_BIN installed ($(stat -c%s "$PROXY_BIN") bytes)"
else
  die "Failed to download $PROXY_TARBALL"
fi

# -- fetch agents ------------------------------------------------------------
say "Scrubbing stale entries from agents/"
find "$AGENT_DIR" -maxdepth 1 -type f -name 'ligolo-agent-*' -mtime +180 -delete 2>/dev/null || true
ok "agents/ pruned"

# (os, arch, ext)   ext is "tar.gz" for unix-likes, "zip" for windows
AGENTS=(
  "linux:amd64:tar.gz"
  "linux:arm64:tar.gz"
  "windows:amd64:zip"
  "windows:arm64:zip"
  "darwin:amd64:tar.gz"
  "darwin:arm64:tar.gz"
  "freebsd:amd64:tar.gz"
  "freebsd:arm64:tar.gz"
)

say "Fetching agents"
got=0; missing=0; present=0
for spec in "${AGENTS[@]}"; do
  IFS=: read -r os arch ext <<<"$spec"
  pkg="ligolo-ng_agent_${VERSION}_${os}_${arch}.${ext}"
  case "$os" in
    windows) dest="$AGENT_DIR/ligolo-agent-${os}-${arch}.exe" ;;
    *)       dest="$AGENT_DIR/ligolo-agent-${os}-${arch}" ;;
  esac

  if [[ -x "$dest" ]]; then
    present=$((present+1))
    continue
  fi

  if ! curl -fLs --max-time 30 "${REL_BASE}/${pkg}" -o "$TMP/${pkg}"; then
    warn "${os}-${arch} not available in v${VERSION}, skipping"
    missing=$((missing+1))
    continue
  fi

  case "$ext" in
    tar.gz)
      tar -xzf "$TMP/${pkg}" -C "$TMP" agent
      install -m 0755 "$TMP/agent" "$dest"
      ;;
    zip)
      unzip -q -o "$TMP/${pkg}" -d "$TMP/wzip"
      # the windows zip ships agent.exe
      install -m 0755 "$TMP/wzip/agent.exe" "$dest"
      rm -rf "$TMP/wzip"
      ;;
  esac
  got=$((got+1))
done
ok "agents staged: $got new, $present already present, $missing missing"

# -- TUN module --------------------------------------------------------------
say "Loading TUN kernel module"
if lsmod | grep -q '^tun '; then
  ok "tun module already loaded"
else
  sudo modprobe tun && ok "tun loaded" || warn "could not modprobe tun (continuing)"
fi

PERSIST="/etc/modules-load.d/tun.conf"
if [[ -f "$PERSIST" ]] && grep -q '^tun$' "$PERSIST"; then
  ok "tun already persistent in /etc/modules-load.d/"
else
  echo 'tun' | sudo tee "$PERSIST" >/dev/null && ok "tun added to $PERSIST"
fi

# -- ligolo-ng.yaml ----------------------------------------------------------
say "Checking ligolo-ng.yaml"
if [[ -f "$YAML_FILE" ]]; then
  ok "ligolo-ng.yaml present ($(stat -c%s "$YAML_FILE") bytes)"
else
  : > "$YAML_FILE"
  ok "ligolo-ng.yaml created (empty)"
fi

# -- patch hardcoded paths in wrappers --------------------------------------
patch_wrapper() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  if grep -q '/home/alien/Desktop/OSCP/LIGOLO' "$f" \
     || grep -q '^LIGOLO_DIR=' "$f"; then
    # Backup once
    [[ -f "${f}.orig" ]] || cp -p "$f" "${f}.orig"
    # Replace the old hardcoded path AND any LIGOLO_DIR= line with our workspace
    sed -i \
      -e "s|/home/alien/Desktop/OSCP/LIGOLO|${WORKSPACE}|g" \
      -e "s|^LIGOLO_DIR=.*|LIGOLO_DIR=\"${WORKSPACE}\"|" \
      "$f"
    chmod +x "$f"
    ok "patched LIGOLO_DIR in $(basename "$f")"
  fi
}

say "Patching wrapper scripts to use $WORKSPACE"
patch_wrapper "$WORKSPACE/tunnels.sh"
patch_wrapper "$WORKSPACE/ligolofix.sh"

# -- shell aliases -----------------------------------------------------------
install_alias_block() {
  local rc="$1"
  [[ -f "$rc" ]] || return 0

  local marker_begin="# >>> ligolo wrappers >>>"
  local marker_end="# <<< ligolo wrappers <<<"

  # Strip any prior block so re-runs don't stack duplicates
  if grep -qF "$marker_begin" "$rc"; then
    sed -i "/${marker_begin}/,/${marker_end}/d" "$rc"
  fi

  {
    echo ""
    echo "$marker_begin"
    echo "alias ligoloup='bash \"${WORKSPACE}/tunnels.sh\"'"
    echo "alias ligolofix='bash \"${WORKSPACE}/ligolofix.sh\"'"
    echo "$marker_end"
  } >> "$rc"

  ok "aliases written to $(basename "$rc")"
}

say "Installing shell aliases"
HOME_DIR="$(eval echo "~${CURRENT_USER}")"
install_alias_block "${HOME_DIR}/.zshrc"
install_alias_block "${HOME_DIR}/.bashrc"

# Make the rc files owned by the actual user even if we ran with sudo
if [[ -n "${SUDO_USER:-}" ]]; then
  chown "${CURRENT_USER}:" "${HOME_DIR}/.zshrc" "${HOME_DIR}/.bashrc" 2>/dev/null || true
fi

# -- summary -----------------------------------------------------------------
echo ""
say "Workspace state $WORKSPACE"
ls -lh "$WORKSPACE" 2>/dev/null | grep -v '^total' || true
echo ""
ls -lh "$AGENT_DIR" 2>/dev/null | grep -v '^total' || true
echo ""
printf '%s[OK]%s Ligolo-NG ready to roll.\n' "$GRN" "$NC"
printf '    Workspace:  %s\n' "$WORKSPACE"
printf '    Proxy:      %s\n' "$PROXY_BIN"
printf '    Agents:     %s/\n' "$AGENT_DIR"
echo ""
printf 'Quick start:\n'
printf '    source ~/.zshrc   # or open a new terminal\n'
printf '    ligolofix         # option 1: create tun interfaces + routes\n'
printf '    ligoloup          # launch proxy with the interactive wrapper\n'
echo ""
