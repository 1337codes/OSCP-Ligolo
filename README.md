# OSCP-Ligolo

Interactive Bash wrapper for spinning up a **Ligolo-NG** lab environment on Arch, CachyOS, Kali, or any Debian/Ubuntu derivative. Centralizes the proxy install, agent staging, TUN interface setup, route plumbing, and a copy-paste reference cheat sheet for pivoting through multi-hop networks.

> Authorized use only. Internal labs, CTFs, OSCP/PEN-200 practice, and engagements where you have explicit permission. Do not point this at networks you don't own or aren't paid to break into.

---

## What it does

* Downloads and stages the Ligolo-NG proxy and cross-platform agents into the repo directory
* Loads and persists the `tun` kernel module
* Patches the wrapper scripts (`tunnels.sh`, `ligolofix.sh`) to use your local paths automatically
* Drops `ligoloup` and `ligolofix` aliases into your shell rc so the wrappers are one word away
* Portable: no hardcoded username, no hardcoded path. Clone anywhere, run, done.

---

## Quick install

```bash
git clone https://github.com/1337codes/OSCP-Ligolo.git
cd OSCP-Ligolo
chmod +x setup-ligolo-arch.sh
bash setup-ligolo-arch.sh
source ~/.zshrc        # or open a fresh terminal
```

After that you have two commands available globally:

```bash
ligolofix    # set up tun interfaces and routes (run this first)
ligoloup     # launch the proxy with the interactive wrapper
```

Pinning a different release version is one env var away:

```bash
LIGOLO_VERSION=0.8.4 bash setup-ligolo-arch.sh
```

---

## Workspace layout

The script uses the directory it was launched from as the workspace. Wherever you clone the repo, that's where everything lives:

```
OSCP-Ligolo/
├── proxy                       <- ligolo-ng proxy binary
├── ligolo-ng.yaml              <- runtime config (created if missing)
├── ligolofix.sh                <- interface setup + stale route cleaner
├── tunnels.sh                  <- the big interactive wrapper
├── setup-ligolo-arch.sh        <- this installer
├── setup-ligolo.sh             <- legacy variant
├── README.md
└── agents/                     <- cross-platform agent binaries
    ├── ligolo-agent-linux-amd64
    ├── ligolo-agent-linux-arm64
    ├── ligolo-agent-windows-amd64.exe
    ├── ligolo-agent-windows-arm64.exe
    ├── ligolo-agent-darwin-amd64
    ├── ligolo-agent-darwin-arm64
    ├── ligolo-agent-freebsd-amd64
    └── ligolo-agent-freebsd-arm64
```

---

## ligoloup

The main interactive wrapper. Started by typing `ligoloup`. It will:

1. Show you a quick agent-naming reference (which agent file matches which target).
2. Prompt for the local interface or IP (defaults to `tun0`), the listener port (default `8888`), the HTTP delivery port (default `80`), and the Linux/Windows agent filenames you want to drop on the target.
3. Print copy-paste blocks for:
   * TUN interface creation (five `ligolomachineXX` and five `ligolonetXX` pairs)
   * 240.0.0.X route mapping per pivot
   * Status checks (which interfaces are up, which routes exist)
   * Session-to-interface mapping for up to 5 simultaneous pivots
   * Ligolo console commands (`session`, `start`, `autoroute`, `listener_add`)
   * Double-pivot and triple-pivot relay setups
   * Agent delivery one-liners for Linux and Windows (raw, base64, fileless via `/dev/shm`, certutil, IWR, SMB copy, etc.)
4. Finally launches the proxy:
   ```
   sudo ./proxy -selfcert -laddr 0.0.0.0:<PORT>
   ```

The 240.0.0.X scheme means each pivot gets its own dedicated `/32` so pivot port access (`start` on `ligolomachineXX`) and internal subnet routing (`autoroute` on `ligolonetXX`) can run side by side without colliding.

---

## ligolofix

Smaller helper. Two modes:

```
ligolofix
 [1] Setup ligolo interfaces      (create tun interfaces + 240.0.0.X routes)
 [2] Clean stale history IPs      (wipe ligolo-ng.yaml + flush old routes)
```

Use option `1` after a reboot or a fresh shell to bring the ten TUN interfaces (`ligolomachine01..05`, `ligolonet01..05`) back up. Use option `2` if the proxy is throwing weird state about routes it thinks already exist.

---

## Session and interface mapping

Each ligolo session in the proxy console maps to a dedicated pair:

| Session | Pivot IP    | Pivot ports interface | Internal subnet interface |
| ------- | ----------- | --------------------- | ------------------------- |
| 1       | 240.0.0.1   | ligolomachine01       | ligolonet01               |
| 2       | 240.0.0.2   | ligolomachine02       | ligolonet02               |
| 3       | 240.0.0.3   | ligolomachine03       | ligolonet03               |
| 4       | 240.0.0.4   | ligolomachine04       | ligolonet04               |
| 5       | 240.0.0.5   | ligolomachine05       | ligolonet05               |

The session number in `tunnel_list` is the X in every interface name. Easy to keep track of when you're juggling multiple agents.

---

## Multi-hop pivots

The wrapper auto-generates the listener commands for double and triple pivots. Pattern:

```
[Kali] --- [Pivot 1] --- [Pivot 2] --- [Pivot 3]
 tun0      240.0.0.1     240.0.0.2     240.0.0.3
```

Each new hop relays the ligolo port (and the HTTP delivery port) on the previous pivot, then the next agent connects to that pivot's **internal** IP. The wrapper bakes your actual IPs and ports into the printed commands so you can copy them straight into the ligolo console.

---

## Customization

| Variable           | What it does                                  | Default |
| ------------------ | --------------------------------------------- | ------- |
| `LIGOLO_VERSION`   | Ligolo-NG release to install                  | `0.8.3` |

Everything else (user, paths, shell rc files) is auto-detected. To move the install somewhere else, just `mv` the repo directory and re-run `setup-ligolo-arch.sh` from the new location. It will repatch the wrappers and refresh the aliases.

---

## What the installer touches

* `<repo-dir>/proxy` — downloaded
* `<repo-dir>/agents/*` — downloaded
* `<repo-dir>/ligolo-ng.yaml` — created if missing
* `<repo-dir>/tunnels.sh` — `LIGOLO_DIR` rewritten to match repo location (`.orig` backup kept)
* `<repo-dir>/ligolofix.sh` — same treatment
* `/etc/modules-load.d/tun.conf` — created if missing (requires `sudo`)
* `~/.zshrc` and `~/.bashrc` — adds a marked alias block

The alias block is bracketed by `# >>> ligolo wrappers >>>` and `# <<< ligolo wrappers <<<` markers, so re-runs replace it cleanly instead of stacking duplicates.

---

## Troubleshooting

**`ligoloup: command not found` after install.**
The aliases are written to your rc file but the current shell hasn't sourced it yet. Either open a new terminal or `source ~/.zshrc` (or `~/.bashrc`).

**Aliases exist but point to the wrong path after moving the repo.**
Re-run `bash setup-ligolo-arch.sh` from the new location. It will rewrite the alias block.

**Proxy fails with `bind: permission denied`.**
The wrapper calls `sudo ./proxy`. If sudo is configured to drop env, that's fine, the script doesn't rely on any inherited env vars.

**`windows-amd64 not available in vX.Y.Z, skipping`.**
Means there's no `ligolo-ng_agent_<version>_windows_amd64.zip` published for that tag. Either bump `LIGOLO_VERSION` to one that has it, or drop a Windows agent into `agents/` manually as `ligolo-agent-windows-amd64.exe`.

**`tun` module won't load.**
On some hardened kernels you need to install the matching `linux-modules-extra` package. On Arch/CachyOS the module ships with the default kernel.

**Sessions show up but `240.0.0.X` is unreachable.**
Run `ligolofix` option 1 to confirm `ligolomachineXX` interfaces are up and the `240.0.0.X/32` routes exist. `ip route | grep 240.0.0` should list all five.

**Stale routes from a previous session.**
`ligolofix` option 2 wipes `ligolo-ng.yaml` and flushes leftover routes from `ligolomachine*` and `ligolonet*` interfaces. Restart the proxy after.

---

## Uninstall

```bash
# remove the alias block
sed -i '/# >>> ligolo wrappers >>>/,/# <<< ligolo wrappers <<</d' ~/.zshrc ~/.bashrc

# tear down interfaces
for i in 01 02 03 04 05; do
  sudo ip link delete ligolomachine$i 2>/dev/null
  sudo ip link delete ligolonet$i 2>/dev/null
done

# wipe persistence
sudo rm -f /etc/modules-load.d/tun.conf

# and the repo
rm -rf <path-to-OSCP-Ligolo>
```

---

## Credits

Wrapper around [nicocha30/ligolo-ng](https://github.com/nicocha30/ligolo-ng). All the actual tunneling magic is theirs. This repo is just operator ergonomics: prompts, paths, aliases, and a fat cheat sheet so you stop pasting the same nine commands every box.
