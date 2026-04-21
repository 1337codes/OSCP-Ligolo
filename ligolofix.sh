#!/bin/bash

# ============================================================================
# LIGOLOFIX - Interface Setup & Stale Route Cleaner
# Location: /home/alien/Desktop/OSCP/LIGOLO/ligolofix.sh
# Symlink:  sudo ln -sf /home/alien/Desktop/OSCP/LIGOLO/ligolofix.sh /usr/local/bin/ligolofix
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

LIGOLO_DIR="/home/alien/Desktop/OSCP/LIGOLO"
YAML_FILE="$LIGOLO_DIR/ligolo-ng.yaml"

echo ""
echo -e "${BOLD}=============================================="
echo -e "  LIGOLOFIX"
echo -e "==============================================${NC}"
echo ""
echo -e "  ${GREEN}[1]${NC} Setup ligolo interfaces ${GRAY}(create tun/tap + 240.0.0.X routes)${NC}"
echo -e "  ${GREEN}[2]${NC} Clean stale history IPs ${GRAY}(wipe ligolo-ng.yaml + flush old OS routes)${NC}"
echo ""
read -p "  Choose option [1/2]: " CHOICE
echo ""

case "$CHOICE" in

# ============================================================================
# OPTION 1 - CREATE INTERFACES + ROUTES
# ============================================================================
1)
    echo -e "[1/3] Creating ligolomachineXX interfaces..."
    for i in 01 02 03 04 05; do
        sudo ip tuntap add user "$(whoami)" mode tun "ligolomachine$i" 2>/dev/null \
            && echo -e "  ${GREEN}[OK]${NC} ligolomachine$i created" \
            || echo -e "  ${YELLOW}[--]${NC} ligolomachine$i already exists (skipped)"
        sudo ip link set "ligolomachine$i" up 2>/dev/null \
            && echo -e "  ${GREEN}[OK]${NC} ligolomachine$i up" \
            || echo -e "  ${RED}[!!]${NC} ligolomachine$i failed to bring up"
    done
    echo -e "[1/3] Completed creating ligolomachineXX interfaces."

    echo ""
    echo -e "[2/3] Adding 240.0.0.X/32 routes to ligolomachineXX interfaces..."
    for i in 01 02 03 04 05; do
        NUM=$((10#$i))
        sudo ip route replace "240.0.0.$NUM/32" dev "ligolomachine$i" 2>/dev/null \
            && echo -e "  ${GREEN}[OK]${NC} 240.0.0.$NUM/32 -> ligolomachine$i" \
            || echo -e "  ${RED}[!!]${NC} Failed to add 240.0.0.$NUM/32 -> ligolomachine$i"
    done
    echo -e "[2/3] Completed adding 240.0.0.X/32 routes."

    echo ""
    echo -e "[3/3] Creating ligolonetXX interfaces..."
    for i in 01 02 03 04 05; do
        sudo ip tuntap add user "$(whoami)" mode tun "ligolonet$i" 2>/dev/null \
            && echo -e "  ${GREEN}[OK]${NC} ligolonet$i created" \
            || echo -e "  ${YELLOW}[--]${NC} ligolonet$i already exists (skipped)"
        sudo ip link set "ligolonet$i" up 2>/dev/null \
            && echo -e "  ${GREEN}[OK]${NC} ligolonet$i up" \
            || echo -e "  ${RED}[!!]${NC} ligolonet$i failed to bring up"
    done
    echo -e "[3/3] Completed creating ligolonetXX interfaces."

    echo ""
    echo -e "${GREEN}[DONE]${NC} All tasks completed."
    echo ""
    ;;

# ============================================================================
# OPTION 2 - CLEAN STALE HISTORY IPs
# ============================================================================
2)
    echo -e "${CYAN}[*]${NC} Cleaning stale ligolo history IPs..."
    echo ""

    # -- Step 1: Wipe ligolo-ng.yaml (clears all saved routes/interfaces) ----
    if [ -f "$YAML_FILE" ]; then
        echo -e "  ${CYAN}[*]${NC} Backing up and wiping $YAML_FILE..."
        cp "$YAML_FILE" "${YAML_FILE}.bak" 2>/dev/null \
            && echo -e "  ${GREEN}[OK]${NC} Backup saved -> ${YAML_FILE}.bak"
        sudo truncate -s 0 "$YAML_FILE" \
            && echo -e "  ${GREEN}[OK]${NC} ligolo-ng.yaml cleared (stale routes removed)" \
            || echo -e "  ${RED}[!!]${NC} Failed to clear $YAML_FILE (check permissions)"
    else
        echo -e "  ${YELLOW}[--]${NC} $YAML_FILE not found -- nothing to wipe"
    fi

    echo ""

    # -- Step 2: Flush any stale OS routes from ligolomachineXX interfaces ---
    echo -e "  ${CYAN}[*]${NC} Flushing stale routes from ligolomachineXX interfaces..."
    for i in 01 02 03 04 05; do
        IFACE="ligolomachine$i"
        if ip link show "$IFACE" &>/dev/null; then
            ROUTES=$(ip route show dev "$IFACE" 2>/dev/null | grep -v '^240\.0\.0\.' | awk '{print $1}')
            if [ -n "$ROUTES" ]; then
                for ROUTE in $ROUTES; do
                    sudo ip route del "$ROUTE" dev "$IFACE" 2>/dev/null \
                        && echo -e "  ${GREEN}[OK]${NC} Removed stale route $ROUTE from $IFACE" \
                        || echo -e "  ${YELLOW}[--]${NC} Could not remove $ROUTE from $IFACE (may already be gone)"
                done
            else
                echo -e "  ${GRAY}[--]${NC} $IFACE: no stale routes found"
            fi
        else
            echo -e "  ${GRAY}[--]${NC} $IFACE: interface not present (skipped)"
        fi
    done

    echo ""

    # -- Step 3: Flush stale routes from ligolonetXX interfaces --------------
    echo -e "  ${CYAN}[*]${NC} Flushing stale routes from ligolonetXX interfaces..."
    for i in 01 02 03 04 05; do
        IFACE="ligolonet$i"
        if ip link show "$IFACE" &>/dev/null; then
            ROUTES=$(ip route show dev "$IFACE" 2>/dev/null | awk '{print $1}')
            if [ -n "$ROUTES" ]; then
                for ROUTE in $ROUTES; do
                    sudo ip route del "$ROUTE" dev "$IFACE" 2>/dev/null \
                        && echo -e "  ${GREEN}[OK]${NC} Removed stale route $ROUTE from $IFACE" \
                        || echo -e "  ${YELLOW}[--]${NC} Could not remove $ROUTE from $IFACE"
                done
            else
                echo -e "  ${GRAY}[--]${NC} $IFACE: no stale routes found"
            fi
        else
            echo -e "  ${GRAY}[--]${NC} $IFACE: interface not present (skipped)"
        fi
    done

    echo ""
    echo -e "${GREEN}[DONE]${NC} Stale routes cleared."
    echo -e "${YELLOW}[!]${NC}  Restart ligolo proxy to pick up clean state."
    echo -e "${YELLOW}[!]${NC}  Run ${CYAN}ligolofix${NC} option 1 if interfaces also need to be recreated."
    echo ""
    ;;

*)
    echo -e "${RED}[!]${NC} Invalid option. Run ligolofix again and choose 1 or 2."
    echo ""
    ;;

esac
