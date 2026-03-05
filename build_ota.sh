#!/bin/bash
#
# OTA Package Builder for Termux
# Custom Recovery ONLY - Auto-detect payload.bin
#
# Repository: https://github.com/hoshiyomiX/PayloadFlashableZip
#

set -o pipefail

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

readonly SCRIPT_VERSION="4.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/output"
WORK_DIR=""

# Build info
DEVICES=()
PAYLOAD_PATH=""
PAYLOAD_PROPS_PATH=""
OUTPUT_NAME=""

# ═══════════════════════════════════════════════════════════════════════════
# COLORS
# ═══════════════════════════════════════════════════════════════════════════

C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_WHITE='\033[1;37m'
C_DIM='\033[2m'

HEADER_LINE="${C_CYAN}═══════════════════════════════════════════════════════════════${C_RESET}"
SECTION_LINE="${C_BLUE}───────────────────────────────────────────────────────────────${C_RESET}"

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════

log_header() {
    echo -e ""
    echo -e "$HEADER_LINE"
    echo -e "${C_CYAN}  $1${C_RESET}"
    echo -e "$HEADER_LINE"
    echo -e ""
}

log_section() {
    echo -e ""
    echo -e "$SECTION_LINE"
    echo -e "${C_BLUE}  $1${C_RESET}"
    echo -e "$SECTION_LINE"
}

log_info()  { echo -e "  ${C_CYAN}●${C_RESET} $1"; }
log_ok()    { echo -e "  ${C_GREEN}✓${C_RESET} $1"; }
log_warn()  { echo -e "  ${C_YELLOW}!${C_RESET} $1"; }
log_error() { echo -e "  ${C_RED}✗${C_RESET} $1"; }

die() {
    echo -e ""
    echo -e "${C_RED}  Error: $1${C_RESET}"
    echo -e ""
    cleanup
    exit 1
}

# ═══════════════════════════════════════════════════════════════════════════
# UTILITIES
# ═══════════════════════════════════════════════════════════════════════════

cleanup() {
    [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
}

get_size() {
    du -h "$1" 2>/dev/null | cut -f1
}

format_devices() {
    local IFS=", "
    echo "${DEVICES[*]}"
}

# ═══════════════════════════════════════════════════════════════════════════
# DEPENDENCIES
# ═══════════════════════════════════════════════════════════════════════════

check_dependencies() {
    log_section "Dependencies"

    if command -v zip &>/dev/null; then
        log_ok "zip ($(zip -v 2>&1 | head -2 | tail -1 | awk '{print $2}'))"
    else
        log_info "Installing zip..."
        pkg install -y zip 2>/dev/null || die "Failed to install zip"
        log_ok "zip installed"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# INPUT VALIDATION
# ═══════════════════════════════════════════════════════════════════════════

validate_input() {
    log_section "Scanning Input Files"

    # Auto-detect payload.bin
    if [[ -z "$PAYLOAD_PATH" ]]; then
        if [[ -f "$SCRIPT_DIR/payload.bin" ]]; then
            PAYLOAD_PATH="$SCRIPT_DIR/payload.bin"
            log_ok "payload.bin (auto-detected)"
        else
            log_error "payload.bin not found"
            die "Place payload.bin in script directory"
        fi
    else
        if [[ ! -f "$PAYLOAD_PATH" ]]; then
            die "payload.bin not found: $PAYLOAD_PATH"
        fi
        log_ok "payload.bin ($(get_size "$PAYLOAD_PATH"))"
    fi

    # Auto-detect payload_properties.txt
    if [[ -z "$PAYLOAD_PROPS_PATH" ]]; then
        if [[ -f "$SCRIPT_DIR/payload_properties.txt" ]]; then
            PAYLOAD_PROPS_PATH="$SCRIPT_DIR/payload_properties.txt"
            log_ok "payload_properties.txt (auto-detected)"
        else
            log_warn "payload_properties.txt (not found)"
            log_warn "A/B OTA may fail without this file"
        fi
    else
        if [[ ! -f "$PAYLOAD_PROPS_PATH" ]]; then
            log_warn "payload_properties.txt not found: $PAYLOAD_PROPS_PATH"
            PAYLOAD_PROPS_PATH=""
        else
            log_ok "payload_properties.txt ($(get_size "$PAYLOAD_PROPS_PATH"))"
        fi
    fi

    log_ok "Validation passed"
}

# ═══════════════════════════════════════════════════════════════════════════
# GENERATORS - Minimal for Custom Recovery Auto-Detect
# ═══════════════════════════════════════════════════════════════════════════

generate_update_binary() {
    local output="$1"

    # Minimal shell script - recovery will ignore this if payload.bin exists
    cat > "$output" << 'BINARY'
#!/sbin/sh
#
# Minimal update-binary for Custom Recovery
# Recovery will auto-detect payload.bin and use update_engine_sideload
#
# This script is only executed if NO payload.bin is found in the ZIP
#

echo "Minimal update-binary"
echo "Custom Recovery should handle payload.bin automatically"
exit 0
BINARY

    chmod +x "$output"
}

generate_updater_script() {
    local output="$1"

    # Minimal script - recovery will ignore this if payload.bin exists
    cat > "$output" << SCRIPT
# Minimal updater-script
# Custom Recovery will auto-detect and flash payload.bin
# This script only runs if payload.bin is NOT present

ui_print("Installing OTA Package...");
ui_print("If payload.bin exists, recovery will flash it automatically.");
SCRIPT
}

# ═══════════════════════════════════════════════════════════════════════════
# BUILD
# ═══════════════════════════════════════════════════════════════════════════

build_package() {
    WORK_DIR=$(mktemp -d)
    local meta_dir="$WORK_DIR/META-INF/com/google/android"
    local output_path="$OUTPUT_DIR/$OUTPUT_NAME"

    mkdir -p "$meta_dir"

    log_section "Preparing Package"

    # Copy payload.bin
    log_info "Copying payload.bin..."
    cp "$PAYLOAD_PATH" "$WORK_DIR/payload.bin"
    log_ok "payload.bin ($(get_size "$WORK_DIR/payload.bin"))"

    # Copy payload_properties.txt
    if [[ -n "$PAYLOAD_PROPS_PATH" ]]; then
        log_info "Copying payload_properties.txt..."
        cp "$PAYLOAD_PROPS_PATH" "$WORK_DIR/payload_properties.txt"
        log_ok "payload_properties.txt"
    fi

    # Generate minimal update-binary (dummy - recovery will ignore)
    log_info "Generating minimal update-binary..."
    generate_update_binary "$meta_dir/update-binary"
    log_ok "update-binary (minimal)"

    # Generate minimal updater-script (dummy - recovery will ignore)
    log_info "Generating minimal updater-script..."
    generate_updater_script "$meta_dir/updater-script"
    log_ok "updater-script (minimal)"

    # Create ZIP
    log_section "Building ZIP Package"

    log_info "Packaging files (store mode)..."
    (cd "$WORK_DIR" && zip -rq -0 "$output_path" .) || die "ZIP creation failed"
    log_ok "Package created ($(get_size "$output_path"))"

    # Cleanup
    rm -rf "$WORK_DIR"
    WORK_DIR=""

    # Summary
    log_section "Build Summary"

    echo -e ""
    echo -e "${C_WHITE}  Device(s):${C_RESET}    $(format_devices)"
    echo -e "${C_WHITE}  Output:${C_RESET}       $output_path"
    echo -e "${C_WHITE}  Size:${C_RESET}         $(get_size "$output_path")"
    echo -e ""
    echo -e "${C_DIM}Note: Custom Recovery will auto-detect payload.bin${C_RESET}"
    echo -e ""
}

# ═══════════════════════════════════════════════════════════════════════════
# INSTRUCTIONS
# ═══════════════════════════════════════════════════════════════════════════

show_instructions() {
    log_header "Ready to Flash"

    echo -e "${C_WHITE}  Flashing Instructions:${C_RESET}"
    echo -e ""
    echo -e "  ${C_CYAN}1.${C_RESET} Boot to Custom Recovery"
    echo -e "     ${C_DIM}TWRP 3.5+ / OrangeFox R11+ / PBRP / SkyHawk${C_RESET}"
    echo -e ""
    echo -e "  ${C_CYAN}2.${C_RESET} Go to ${C_WHITE}Install${C_RESET}"
    echo -e ""
    echo -e "  ${C_CYAN}3.${C_RESET} Select ${C_WHITE}$OUTPUT_NAME${C_RESET}"
    echo -e ""
    echo -e "  ${C_CYAN}4.${C_RESET} Swipe to flash"
    echo -e "     ${C_DIM}Recovery will auto-detect payload.bin${C_RESET}"
    echo -e ""
    echo -e "  ${C_CYAN}5.${C_RESET} Wait for completion"
    echo -e ""
    echo -e "  ${C_CYAN}6.${C_RESET} Reboot system"
    echo -e ""
    echo -e "$SECTION_LINE"
    echo -e ""
}

# ═══════════════════════════════════════════════════════════════════════════
# HELP
# ═══════════════════════════════════════════════════════════════════════════

show_help() {
    cat << HELP
${C_CYAN}OTA Package Builder for Termux${C_RESET}
${C_DIM}Version $SCRIPT_VERSION${C_RESET}

${C_YELLOW}Usage:${C_RESET}
    $0 -d <device> -o <output.zip> [options]

${C_YELLOW}Required Files (place in script directory):${C_RESET}
    payload.bin             ROM payload (required)
    payload_properties.txt  Payload metadata (recommended)

${C_YELLOW}Options:${C_RESET}
    -d <device>    Device codename (required, can specify multiple)
    -o <name>      Output filename (required)
    -p <file>      payload.bin path (default: script directory)
    -P <file>      payload_properties.txt path (default: script directory)
    -h             Show this help

${C_YELLOW}How It Works:${C_RESET}
    Custom Recovery (TWRP/OrangeFox/PBRP) auto-detects payload.bin
    and flashes it via update_engine_sideload. No signing needed.

${C_YELLOW}Examples:${C_RESET}
    $0 -d X695C -o LineageOS.zip
    $0 -d X695C -d Infinix-X695C -o MyROM.zip

${C_YELLOW}Supported Recoveries:${C_RESET}
    TWRP 3.5+, OrangeFox R11+, PBRP, SkyHawk, RedWolf

${C_RED}Note:${C_RESET} Stock Recovery is NOT supported

HELP
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════
# ARGUMENTS
# ═══════════════════════════════════════════════════════════════════════════

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d)
                [[ -z "$2" ]] && die "Option -d requires device codename"
                DEVICES+=("$2")
                shift 2
                ;;
            -o)
                [[ -z "$2" ]] && die "Option -o requires filename"
                OUTPUT_NAME="$2"
                shift 2
                ;;
            -p)
                [[ -z "$2" ]] && die "Option -p requires file path"
                PAYLOAD_PATH="$2"
                shift 2
                ;;
            -P)
                [[ -z "$2" ]] && die "Option -P requires file path"
                PAYLOAD_PROPS_PATH="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    if [[ ${#DEVICES[@]} -eq 0 ]]; then
        log_error "No device specified (use -d)"
        echo -e ""
        echo -e "  Usage: $0 -d <device> -o <output.zip>"
        echo -e "  Help:  $0 -h"
        echo -e ""
        exit 1
    fi

    if [[ -z "$OUTPUT_NAME" ]]; then
        log_error "No output filename specified (use -o)"
        echo -e ""
        echo -e "  Usage: $0 -d <device> -o <output.zip>"
        echo -e "  Help:  $0 -h"
        echo -e ""
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════

main() {
    trap cleanup EXIT

    parse_arguments "$@"

    echo -e ""
    echo -e "${C_CYAN}╔═══════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}             ${C_WHITE}OTA Package Builder for Termux${C_RESET}                  ${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}         ${C_DIM}Custom Recovery Auto-Detect Payload${C_RESET}             ${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}╚═══════════════════════════════════════════════════════════════╝${C_RESET}"
    echo -e ""
    echo -e "  ${C_WHITE}Device:${C_RESET} $(format_devices)"
    echo -e "  ${C_WHITE}Output:${C_RESET} $OUTPUT_NAME"

    mkdir -p "$OUTPUT_DIR"

    check_dependencies
    validate_input
    build_package
    show_instructions
}

main "$@"
