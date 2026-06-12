#!/bin/zsh
# ============================================================================
# OUI SPY - Upstream Import Helper
#
# The src/raw/*.cpp files are a FORK of the upstream mode firmwares: they carry
# Nesso N1 board abstractions (#ifdef NESSO_N1), display hooks, and local
# fixes. This script therefore does NOT blindly overwrite them. When an
# upstream file has changed, it is written next to the fork as <file>.upstream
# for a manual merge; the fork itself is never clobbered.
#
# Usage:
#   ./sync.sh           Import all modes + build
#   ./sync.sh 4         Import only mode 4 (Flock-You) + build
#   ./sync.sh status    Show which forked files diverge from upstream (no build)
# ============================================================================

SCRIPT_DIR="${0:A:h}"
RAW_DIR="$SCRIPT_DIR/src/raw"
SRC_DIR="$SCRIPT_DIR/src"
PARENT_DIR="${SCRIPT_DIR:h}"
PIO="$HOME/.platformio/penv/bin/pio"

RED=$'\e[0;31m'; GREEN=$'\e[0;32m'; YELLOW=$'\e[1;33m'
BLUE=$'\e[0;34m'; CYAN=$'\e[0;36m'; BOLD=$'\e[1m'; NC=$'\e[0m'

repo_dir()  { case $1 in 1) echo "ouispy-detector";; 2) echo "ouispy-foxhunter";; 4) echo "flock-you";; 5) echo "Sky-Spy";; esac }
mode_name() { case $1 in 1) echo "Detector";; 2) echo "Foxhunter";; 4) echo "Flock-You";; 5) echo "Sky Spy";; esac }

# import <upstream-file> <local-fork-file>
# Never overwrites the fork. New files are copied; diverged ones are written to
# <local>.upstream for manual merge.
import() {
    local up="$1" loc="$2"
    [[ -f "$up" ]] || return
    if [[ ! -f "$loc" ]]; then
        cp "$up" "$loc"
        echo "    ${GREEN}+ added${NC} ${loc:t}"
    elif diff -q "$up" "$loc" &>/dev/null; then
        :  # identical, nothing to do
    else
        cp "$up" "$loc.upstream"
        echo "    ${YELLOW}! ${loc:t} diverged${NC} -> wrote ${loc:t}.upstream (merge manually)"
    fi
}

sync_mode() {
    local m=$1
    local repo=$(repo_dir $m)
    local name=$(mode_name $m)
    local rp="$PARENT_DIR/$repo"

    if [[ ! -d "$rp" ]]; then
        echo "  ${RED}[SKIP]${NC} $repo not found"
        return 1
    fi

    if [[ -d "$rp/.git" ]]; then
        (cd "$rp" && git pull --quiet 2>/dev/null) || true
    fi

    echo "  ${BLUE}[$m]${NC} $name"

    case $m in
        1) import "$rp/src/main.cpp" "$RAW_DIR/detector.cpp" ;;
        2) import "$rp/src/main.cpp" "$RAW_DIR/foxhunter.cpp" ;;
        4) import "$rp/src/main.cpp" "$RAW_DIR/flockyou.cpp" ;;
        5)
            import "$rp/src/main.cpp"      "$RAW_DIR/skyspy.cpp"
            import "$rp/src/opendroneid.h" "$SRC_DIR/opendroneid.h"
            import "$rp/src/opendroneid.c" "$SRC_DIR/opendroneid.c"
            import "$rp/src/odid_wifi.h"   "$SRC_DIR/odid_wifi.h"
            import "$rp/src/wifi.c"        "$SRC_DIR/wifi.c"
            ;;
    esac
}

check_mode() {
    local m=$1
    local repo=$(repo_dir $m)
    local rp="$PARENT_DIR/$repo"
    local name=$(mode_name $m)
    local diverged=0

    [[ ! -d "$rp" ]] && { echo "  ${BLUE}[$m]${NC} $name ${RED}repo missing${NC}"; return; }

    diff_one() { [[ -f "$1" && -f "$2" ]] && ! diff -q "$1" "$2" &>/dev/null && diverged=1; }

    case $m in
        1) diff_one "$rp/src/main.cpp" "$RAW_DIR/detector.cpp" ;;
        2) diff_one "$rp/src/main.cpp" "$RAW_DIR/foxhunter.cpp" ;;
        4) diff_one "$rp/src/main.cpp" "$RAW_DIR/flockyou.cpp" ;;
        5) diff_one "$rp/src/main.cpp" "$RAW_DIR/skyspy.cpp"
           for f in opendroneid.h opendroneid.c odid_wifi.h wifi.c; do
               diff_one "$rp/src/$f" "$SRC_DIR/$f"
           done ;;
    esac

    if [[ $diverged -eq 1 ]]; then
        echo "  ${BLUE}[$m]${NC} $name ${YELLOW}diverges from upstream${NC}"
    else
        echo "  ${BLUE}[$m]${NC} $name ${GREEN}matches upstream${NC}"
    fi
}

# ============================================================================
echo ""
echo "${CYAN}${BOLD}  OUI SPY - Upstream Import${NC}"
echo ""

case "${1:-sync}" in
    status)
        echo "${YELLOW}Checking divergence from upstream...${NC}"
        echo ""
        for m in 1 2 4 5; do check_mode $m; done
        ;;
    [1-5])
        echo "${GREEN}Importing mode $1...${NC}"
        echo ""
        sync_mode $1
        echo ""
        echo "${CYAN}Building...${NC}"
        cd "$SCRIPT_DIR" && $PIO run 2>&1
        ;;
    *)
        echo "${GREEN}Importing all modes...${NC}"
        echo ""
        for m in 1 2 4 5; do sync_mode $m; done
        echo ""
        echo "${CYAN}Building...${NC}"
        cd "$SCRIPT_DIR" && $PIO run 2>&1
        ;;
esac

echo ""
