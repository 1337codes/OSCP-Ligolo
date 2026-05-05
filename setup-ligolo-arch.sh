#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# setup-ligolo-arch.sh — Arch/CachyOS/BlackArch port of setup-ligolo.sh
#
#   Pulls Ligolo-NG proxy + cross-platform agents from upstream releases
#   (nicocha30/ligolo-ng) and stages the workspace exactly the way the
#   upstream Kali-based script does — but without apt-get / dpkg.
#
#   Repo:   https://github.com/1337codes/OSCP-Ligolo
#   Usage:  chmod +x setup-ligolo-arch.sh && ./setup-ligolo-arch.sh
# ─────────────────────────────────────────────────────────────────────

set -u

R='\033[91m'; G='\033[92m'; Y='\033[93m'; C='\033[96m'; B='\033[1m'; N='\033[0m'

banner() { echo -e "\n${C}${B}[*]${N} ${B}$1${N}"; }
ok()     { echo -e "${G}[+]${N} $1"; }
warn()   { echo -e "${Y}[!]${N} $1"; }
fail()   { echo -e "${R}[-]${N} $1" >&2; }

# ─── version + paths ─────────────────────────────────────────────────
LIGOLO_VERSION="${LIGOLO_VERSION:-0.8.3}"
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
WORKSPACE="$TARGET_HOME/Desktop/OSCP/LIGOLO"
RELEASE_BASE="https://github.com/nicocha30/ligolo-ng/releases/download/v${LIGOLO_VERSION}"

if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo &>/dev/null; then
        fail "Run as root or install sudo."; exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

run_as_user() {
    if [[ $EUID -eq 0 ]] && [[ "$TARGET_USER" != "root" ]]; then
        sudo -u "$TARGET_USER" -H "$@"
    else
        "$@"
    fi
}

banner "Ligolo-NG pivot wrapper installer (Arch/CachyOS)"
echo "    version:    ${LIGOLO_VERSION}"
echo "    workspace:  ${WORKSPACE}"
echo "    user:       ${TARGET_USER}"

# ─── sanity: required tools ──────────────────────────────────────────
banner "Checking required tools"
need=(curl tar ip)
missing=()
for t in "${need[@]}"; do command -v "$t" &>/dev/null || missing+=("$t"); done
if (( ${#missing[@]} )); then
    warn "missing: ${missing[*]} — installing via pacman"
    $SUDO pacman -S --needed --noconfirm curl tar iproute2 || { fail "pacman install failed"; exit 1; }
fi
ok "curl / tar / iproute2 present"

# ─── stage workspace ─────────────────────────────────────────────────
banner "Staging workspace at $WORKSPACE"
run_as_user mkdir -p "$WORKSPACE/agents"
ok "workspace ready"

# ─── proxy ───────────────────────────────────────────────────────────
banner "Fetching ligolo-proxy ${LIGOLO_VERSION} (linux/amd64)"
PROXY_TGZ="ligolo-ng_proxy_${LIGOLO_VERSION}_linux_amd64.tar.gz"
PROXY_TMP=$(mktemp -d)
if curl -sLf "${RELEASE_BASE}/${PROXY_TGZ}" | tar xz -C "$PROXY_TMP"; then
    run_as_user mv -f "$PROXY_TMP/proxy" "$WORKSPACE/proxy"
    run_as_user chmod +x "$WORKSPACE/proxy"
    ok "$WORKSPACE/proxy installed ($(stat -c%s "$WORKSPACE/proxy") bytes)"
else
    fail "could not fetch proxy tarball — check network / version"
    exit 1
fi
rm -rf "$PROXY_TMP"

# ─── strict cleanup of agents/ ───────────────────────────────────────
ALLOWED_RX='^ligolo-agent-(linux|windows|darwin|freebsd)-(amd64|arm64|386|armv[5-7])(\.exe)?$'
banner "Scrubbing stale entries from agents/"
CLEANED=0
while IFS= read -r f; do
    base=$(basename "$f")
    if ! [[ "$base" =~ $ALLOWED_RX ]]; then
        run_as_user rm -f "$f" && CLEANED=$((CLEANED+1))
    fi
done < <(find "$WORKSPACE/agents" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null)
[[ $CLEANED -eq 0 ]] && ok "agents/ already clean" || ok "removed $CLEANED stale entry/entries"

# ─── agents (cross-platform) ─────────────────────────────────────────
# Note: linux/darwin/freebsd are .tar.gz, windows is .zip
banner "Fetching agents (linux / windows / darwin / freebsd × amd64+arm64)"

# Make sure unzip is around for the windows case
if ! command -v unzip &>/dev/null; then
    warn "unzip missing — installing for windows agent extraction"
    $SUDO pacman -S --needed --noconfirm unzip || warn "couldn't install unzip — windows agents will be skipped"
fi

STAGED=0; SKIPPED=0
for os in linux windows darwin freebsd; do
    for arch in amd64 arm64; do
        ext=""; [[ "$os" == "windows" ]] && ext=".exe"
        dst="$WORKSPACE/agents/ligolo-agent-${os}-${arch}${ext}"
        if [[ -f "$dst" ]]; then
            SKIPPED=$((SKIPPED+1))
            continue
        fi
        tmp=$(mktemp -d)
        if [[ "$os" == "windows" ]]; then
            # Windows is shipped as zip
            zip="ligolo-ng_agent_${LIGOLO_VERSION}_${os}_${arch}.zip"
            if curl -sLf "${RELEASE_BASE}/${zip}" -o "$tmp/a.zip" \
               && command -v unzip &>/dev/null \
               && unzip -q "$tmp/a.zip" -d "$tmp" \
               && [[ -f "$tmp/agent.exe" ]]; then
                run_as_user mv -f "$tmp/agent.exe" "$dst"
                run_as_user chmod +x "$dst"
                ok "${os}-${arch}${ext}"
                STAGED=$((STAGED+1))
            else
                warn "${os}-${arch} not available in v${LIGOLO_VERSION}, skipping"
            fi
        else
            # Everything else is tar.gz
            tgz="ligolo-ng_agent_${LIGOLO_VERSION}_${os}_${arch}.tar.gz"
            if curl -sLf "${RELEASE_BASE}/${tgz}" | tar xz -C "$tmp" 2>/dev/null \
               && [[ -f "$tmp/agent" ]]; then
                run_as_user mv -f "$tmp/agent" "$dst"
                run_as_user chmod +x "$dst"
                ok "${os}-${arch}"
                STAGED=$((STAGED+1))
            else
                warn "${os}-${arch} not available in v${LIGOLO_VERSION}, skipping"
            fi
        fi
        rm -rf "$tmp"
    done
done
ok "agents staged: ${STAGED} new, ${SKIPPED} already present"

# ─── TUN kernel module ───────────────────────────────────────────────
banner "Loading TUN kernel module"
if lsmod | grep -q '^tun '; then
    ok "tun module already loaded"
else
    $SUDO modprobe tun && ok "tun module loaded" || fail "could not load tun module"
fi

# Persist via systemd-modules-load (the Arch way), not /etc/modules
if [[ ! -f /etc/modules-load.d/tun.conf ]] || ! grep -q '^tun$' /etc/modules-load.d/tun.conf 2>/dev/null; then
    echo tun | $SUDO tee /etc/modules-load.d/tun.conf >/dev/null && ok "tun added to /etc/modules-load.d/tun.conf"
else
    ok "tun already persistent in /etc/modules-load.d/"
fi

# ─── ligolo-ng.yaml stub ─────────────────────────────────────────────
banner "Checking ligolo-ng.yaml"
YAML="$WORKSPACE/ligolo-ng.yaml"
if [[ ! -s "$YAML" ]]; then
    [[ -e "$YAML" ]] && warn "ligolo-ng.yaml exists but is empty — overwriting" || warn "ligolo-ng.yaml missing — writing stub"
    run_as_user tee "$YAML" >/dev/null <<'YAML'
# ligolo-ng minimal config — edit as needed
# Reference: https://docs.ligolo.ng/
listen: 0.0.0.0:11601
selfcert: true
selfcert-domain: ligolo
# certfile: certs/cert.pem
# keyfile: certs/key.pem
# autocert: false
# allow-domains: ""
verbose: false
YAML
    ok "ligolo-ng.yaml stub written ($(stat -c%s "$YAML") bytes)"
else
    ok "ligolo-ng.yaml present ($(stat -c%s "$YAML") bytes)"
fi

# ─── final state ─────────────────────────────────────────────────────
banner "Workspace state"
echo
echo -e "${C}$WORKSPACE${N}"
run_as_user ls -la "$WORKSPACE" | grep -vE '^total|^d.+ \.\.?$'
echo
echo -e "${C}$WORKSPACE/agents${N}"
run_as_user ls -la "$WORKSPACE/agents" | grep -vE '^total|^d.+ \.\.?$'

echo
echo -e "${G}${B}[✓] Ligolo-NG ready to roll.${N}"
echo
echo -e "    ${C}Workspace:${N}  $WORKSPACE"
echo -e "    ${C}Proxy:${N}      $WORKSPACE/proxy"
echo -e "    ${C}Agents:${N}     $WORKSPACE/agents/  (cross-platform, clean names)"
echo
echo -e "${C}${B}Quick start:${N}"
echo -e "    ${C}# 1. Create a TUN interface (the wrapper does this for you):${N}"
echo -e "    sudo ip tuntap add user $TARGET_USER mode tun ligolo"
echo -e "    sudo ip link set ligolo up"
echo
echo -e "    ${C}# 2. Run the wrapper:${N}"
echo -e "    cd $WORKSPACE && bash tunnels.sh"
echo
echo -e "${Y}[!] Reminder:${N} ligolofix.sh / tunnels.sh hard-code /home/alien/Desktop/OSCP/LIGOLO."
echo -e "    If your username isn't 'alien', edit the LIGOLO_DIR variable inside both scripts:"
echo -e "    sed -i \"s|/home/alien/Desktop/OSCP/LIGOLO|$WORKSPACE|g\" ligolofix.sh tunnels.sh"
