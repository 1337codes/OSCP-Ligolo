#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# setup-ligolo.sh — installs Ligolo-NG + agents and stages workspace
#
#   Repo:   https://github.com/1337codes/OSCP-Ligolo
#   Usage:  chmod +x setup-ligolo.sh && sudo bash setup-ligolo.sh
# ─────────────────────────────────────────────────────────────────────

set -u

R='\033[91m'; G='\033[92m'; Y='\033[93m'; C='\033[96m'; B='\033[1m'; N='\033[0m'

banner() { echo -e "\n${C}${B}[*]${N} ${B}$1${N}"; }
ok()     { echo -e "${G}[+]${N} $1"; }
warn()   { echo -e "${Y}[!]${N} $1"; }
fail()   { echo -e "${R}[-]${N} $1" >&2; }

if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo &>/dev/null; then
        fail "Run as root or install sudo."; exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
WORKSPACE="$TARGET_HOME/Desktop/OSCP/LIGOLO"

run_as_user() {
    if [[ $EUID -eq 0 ]] && [[ "$TARGET_USER" != "root" ]]; then
        sudo -u "$TARGET_USER" -H "$@"
    else
        "$@"
    fi
}

# Strict naming pattern for what we expect in agents/
# Allowed: ligolo-agent-<os>-<arch>[.exe]
ALLOWED_RX='^ligolo-agent-(linux|windows|darwin|freebsd)-(amd64|arm64|386|armv[5-7])(\.exe)?$'

banner "Ligolo-NG pivot wrapper installer"

# ─── apt update + install ────────────────────────────────────────────
banner "Updating package index"
$SUDO apt-get update -qq && ok "apt index updated" || warn "apt update had warnings (continuing)"

banner "Installing Ligolo-NG + agent binaries"
$SUDO apt-get install -y -qq \
    ligolo-ng \
    ligolo-ng-common-binaries \
    iproute2 \
    kmod
ok "ligolo-ng + agents + iproute2 installed"

# ─── verify proxy binary ─────────────────────────────────────────────
banner "Verifying ligolo-proxy"
if command -v ligolo-proxy &>/dev/null; then
    ok "ligolo-proxy on PATH ($(command -v ligolo-proxy))"
else
    fail "ligolo-proxy missing after install — bailing"
    exit 1
fi

# ─── load TUN kernel module ──────────────────────────────────────────
banner "Loading TUN kernel module"
if lsmod | grep -q '^tun '; then
    ok "tun module already loaded"
else
    $SUDO modprobe tun && ok "tun module loaded" || fail "could not load tun module"
fi

if ! grep -qE '^tun$' /etc/modules 2>/dev/null; then
    echo "tun" | $SUDO tee -a /etc/modules >/dev/null && ok "tun added to /etc/modules"
else
    ok "tun already persistent in /etc/modules"
fi

# ─── stage workspace ─────────────────────────────────────────────────
banner "Staging Ligolo workspace at $WORKSPACE"
run_as_user mkdir -p "$WORKSPACE/agents"
ok "workspace ready"

# Symlink the proxy binary as `proxy` (the wrapper expects this name)
if [[ ! -e "$WORKSPACE/proxy" ]]; then
    run_as_user ln -s "$(command -v ligolo-proxy)" "$WORKSPACE/proxy" && \
        ok "$WORKSPACE/proxy → $(command -v ligolo-proxy)"
elif [[ -L "$WORKSPACE/proxy" ]]; then
    ok "$WORKSPACE/proxy already linked → $(readlink "$WORKSPACE/proxy")"
else
    ok "$WORKSPACE/proxy already exists (real file — left untouched)"
fi

# ─── strict cleanup of agents/ ───────────────────────────────────────
# Anything in agents/ that's a symlink AND doesn't match the clean naming
# pattern gets nuked. This catches:
#   - ligolo-ng_agent_0.8.3_* (old versioned format)
#   - ligolo-ng_proxy_*       (proxies don't belong here)
#   - ligolo-ng-common-binaries (wrapper script)
#   - bare ligolo-agent       (no os-arch suffix)
#   - agentxtrap or any other nonsense
banner "Scrubbing stale/bogus symlinks from agents/"
CLEANED=0
while IFS= read -r link; do
    base=$(basename "$link")
    if ! [[ "$base" =~ $ALLOWED_RX ]]; then
        run_as_user rm -f "$link" && CLEANED=$((CLEANED+1))
    fi
done < <(find "$WORKSPACE/agents" -maxdepth 1 -type l 2>/dev/null)

if [[ $CLEANED -eq 0 ]]; then
    ok "agents/ already clean"
else
    ok "removed $CLEANED stale symlink(s)"
fi

# ─── stage agent binaries via dpkg (precise, no guessing) ────────────
banner "Staging ligolo agent binaries with clean names"
STAGED=0
while IFS= read -r src; do
    [[ -f "$src" ]] || continue
    base=$(basename "$src")
    # ligolo-ng_agent_0.8.3_linux_amd64       → ligolo-agent-linux-amd64
    # ligolo-ng_agent_0.8.3_windows_amd64.exe → ligolo-agent-windows-amd64.exe
    clean=$(echo "$base" | sed -E 's/^ligolo-ng_agent_[0-9.]+_/ligolo-agent-/' | tr '_' '-')
    dst="$WORKSPACE/agents/$clean"
    if [[ ! -e "$dst" ]]; then
        run_as_user ln -s "$src" "$dst" && STAGED=$((STAGED+1))
    fi
done < <(dpkg -L ligolo-ng-common-binaries 2>/dev/null | \
         grep -E '/ligolo-ng_agent_[0-9]+\.[0-9]+\.[0-9]+_[a-z0-9]+_[a-z0-9]+(\.exe)?$')

if [[ $STAGED -gt 0 ]]; then
    ok "$STAGED new agent symlink(s) created"
else
    ok "all agents already staged"
fi

# ─── ligolo-ng.yaml stub (use -s, not -f, to catch 0-byte files) ─────
banner "Checking ligolo-ng.yaml"
YAML="$WORKSPACE/ligolo-ng.yaml"
if [[ ! -s "$YAML" ]]; then
    # File missing OR zero bytes
    if [[ -e "$YAML" ]]; then
        warn "ligolo-ng.yaml exists but is empty — writing stub"
    else
        warn "ligolo-ng.yaml missing — writing stub"
    fi
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
    ok "ligolo-ng.yaml present and non-empty ($(stat -c%s "$YAML") bytes)"
fi

# ─── final verification ──────────────────────────────────────────────
banner "Workspace state"
echo
echo -e "${C}$WORKSPACE${N}"
run_as_user ls -la "$WORKSPACE" | grep -vE '^total|^d.+ \.\.?$'
echo
echo -e "${C}$WORKSPACE/agents${N}"
run_as_user ls -la "$WORKSPACE/agents" | grep -vE '^total|^d.+ \.\.?$'

# ─── done ────────────────────────────────────────────────────────────
echo
echo -e "${G}${B}[✓] Ligolo-NG ready to roll.${N}"
echo
echo -e "    ${C}Workspace:${N}  $WORKSPACE"
echo -e "    ${C}Proxy:${N}      $WORKSPACE/proxy"
echo -e "    ${C}Agents:${N}     $WORKSPACE/agents/  (cross-platform, clean names)"
echo
echo -e "${C}${B}Quick start:${N}"
echo -e "    ${C}# 1. Create the TUN interface:${N}"
echo -e "    sudo ip tuntap add user $TARGET_USER mode tun ligolo"
echo -e "    sudo ip link set ligolo up"
echo
echo -e "    ${C}# 2. Run the wrapper:${N}"
echo -e "    cd $WORKSPACE && bash tunnels.sh"
echo
echo -e "    ${C}# 3. Drop the right agent on target:${N}"
echo -e "    Linux x64:    $WORKSPACE/agents/ligolo-agent-linux-amd64"
echo -e "    Linux arm64:  $WORKSPACE/agents/ligolo-agent-linux-arm64"
echo -e "    Windows x64:  $WORKSPACE/agents/ligolo-agent-windows-amd64.exe"
echo -e "    Windows arm:  $WORKSPACE/agents/ligolo-agent-windows-arm64.exe"
echo -e "    macOS x64:    $WORKSPACE/agents/ligolo-agent-darwin-amd64"
echo -e "    macOS arm64:  $WORKSPACE/agents/ligolo-agent-darwin-arm64"
echo
echo -e "${Y}[!] Reminder:${N} the wrapper hard-codes /home/alien/Desktop/OSCP/LIGOLO."
echo -e "    If your username isn't 'alien', edit the path inside ligolofix.sh / tunnels.sh."
