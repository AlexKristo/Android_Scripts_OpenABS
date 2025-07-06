#!/bin/bash
#
# This script is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2
# as published by the Free Software Foundation.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License v2
# along with this script; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
# Author: Alex Kristo <202012252+AlexKristo@users.noreply.github.com>
# Date: 6th of July, 2025
#

_log() {
    local color_code="$1"; shift
    echo -e "\033[1;${color_code}m[$(date '+%H:%M:%S')] \033[0m$@"
}
info() { _log "34" "INFO: $*"; }
warn() { _log "33" "WARN: $*"; }
error() { _log "31" "ERROR: $*"; }
success() { _log "32" "SUCCESS: $*"; }
env_log() { _log "32" "ENV: $*"; }

command_exists() {
  if ! type -t "$1" >/dev/null 2>&1; then
    error "Required command or function '$1' not found. Please install or define it."
    exit 1
  fi
}

file_exists() {
    if [ ! -f "$1" ]; then
        error "File $1 doesn't exist"
        return 1
    fi
    return 0
}

# Stub function, this should be defined properly in your flavour profile
setup_environment() {
    exit 1
}

download_toolchain() {
    if [ "$CONFIG_TOOLCHAIN" = "CLANG" ]; then
        if [ -z "$clang_url" ] || [[ "$clang_url" == *"0" ]]; then
            error "Invalid or missing Clang URL for version $CONFIG_CLANG_VERSION"
            exit 1
        fi
        if [ ! -d "$clang_dir/bin" ]; then
            info "Clang toolchain not found at $clang_dir."
            if [ "$CONFIG_CLI_SETUP" != "y" ]; then
                read -p "Download Toolchain? (Y/n) > " TC_DL
                [[ "$TC_DL" =~ ^[Nn]$ ]] && exit 1
            fi
            env_log "Downloading Clang from $clang_url..."
            rm -rf "$clang_dir" && mkdir -p "$clang_dir"
            if ! wget -qO- "$clang_url" | tar -xz -C "$clang_dir"; then
                error "Download or extraction failed. Please check the URL and try again."
                rm -rf "$clang_dir"; exit 1
            fi
            success "Toolchain downloaded successfully."
        fi
    fi

    if [ "$CONFIG_TOOLCHAIN" = "GCC" ]; then
        local gcc_url="${gcc_urls[$CONFIG_GCC_VERSION]}"
        if [ -z "$gcc_url" ] || [[ "$gcc_url" == "0" ]]; then
            error "Invalid or missing GCC URL for version $CONFIG_GCC_VERSION"
            exit 1
        fi
        if [ ! -d "$gcc_dir/bin" ]; then
            info "GCC toolchain not found at $gcc_dir"
            if [ "$CONFIG_CLI_SETUP" != "y" ]; then
                read -p "Download Toolchain? (Y/n) > " TC_DL
                [[ "$TC_DL" =~ ^[Nn]$ ]] && exit 1
            fi
            env_log "Downloading GCC..."
            rm -rf "$gcc_dir" && mkdir -p "$gcc_dir"
            if ! wget -qO- "$gcc_url" | tar -xJ --strip-components=1 -C "$gcc_dir"; then
                error "Download or extraction failed. Please check the URL and try again."
                rm -rf "$gcc_dir"; exit 1
            fi
            success "Toolchain downloaded successfully."
        fi
    fi
}

build_boot() {
    local final_img_path="$dir/Kitchen/out/$out_name.img"
    "$dir/Kitchen/bin/$HOST_ARCH/mkbootimg" \
        --kernel "$REAL_KERNEL" \
        --ramdisk "$RAMDISK" \
        --dt "$REAL_DT" \
        --cmdline "$CMDLINE" \
        --base "$BASE" \
        --kernel_offset "$KERNEL_OFFSET" \
        --second_offset "$SECOND_OFFSET" \
        --tags_offset "$TAGS_OFFSET" \
        --os_version "$OS_VERSION" \
        --header_version "$HEADER_VERSION" \
        --os_patch_level "$OS_PATCH_LEVEL" \
        --pagesize "$PAGESIZE" \
        -o "$final_img_path"
    success "New boot.img created: $final_img_path ($(du -h "$final_img_path" | cut -f1))"
}

# Stub, actual definition is defined in flavour profile
build_target() {
    exit 1
}

build_combinations() {
    if [ "$1" = "plus" ]; then
        for p_choice in y n; do
            for k_choice in y n; do
                export CONFIG_ALWAYS_PERMISSIVE="$p_choice"
                export CONFIG_SUBMODULES_KSU="$k_choice"
                for device in "${build_order[@]}"; do
                    build_target "$device" || return 1
                    info "----------------------------------------------------"
                done
            done
        done
    elif [ "$1" = "stn" ]; then
        for device in "${build_order[@]}"; do
            build_target "$device" || return 1
            info "----------------------------------------------------"
        done
    fi
}

cache_base_bootimg() {
  ( # enter subshell
    cd "$dir/Kitchen/bin/$HOST_ARCH" || exit 1
    rm -f ../../premade-mkbootimg/*  # Clean up previous artifacts
    ./unpackbootimg -i ../boot/"$CONFIG_BASE_BOOTIMG" -o ../premade-mkbootimg > /dev/null
  ) # exit subshell
  [ -d "$dir/Kitchen/premade-mkbootimg" ] || { error "Directory not found: $dir/Kitchen/premade-mkbootimg" >&2; exit 1; }
}

prompt_yes_no() {
    local prompt_text="$1"
    local -n result_var="$2" # Use a nameref to modify the original variable
    local default_val="$3"   # 'y' or 'n'

    local choice
    while true; do
        read -p "$prompt_text" choice
        # If user presses enter, use the default value
        choice=${choice:-$default_val}
        case "$choice" in
            [Yy]* ) result_var='y'; break ;;
            [Nn]* ) result_var='n'; break ;;
            * ) error "Invalid input. Please enter 'y' or 'n'." ;;
        esac
    done
}

append_to_config() {
    local config_line="$1"
    local config_file="$2"
    echo >> "$config_file" # Ensure there's always a newline before appending the new config
    echo "$config_line" >> "$config_file"
}

clean_dtb() {
    info "Cleaning previous DTB artifacts..."
    rm -f $dir/arch/$ARCH/boot/dtb.img
    rm -f $dir/arch/$ARCH/boot/dts/$SUPER_ARCH/*.dtb
    rm -f $dir/arch/$ARCH/boot/dts/$SUPER_ARCH/*.tmp
    rm -f $dir/arch/$ARCH/boot/dts/$SUPER_ARCH/*.cmd
    rm -f $dir/arch/$ARCH/boot/dts/$SUPER_ARCH/*.reverse.dts
}

get_help() {
    cat <<EOF
Usage: $0 [options]
  -a  Disable creation of boot.img (CONFIG_MKBOOTIMG=n)
  -b  Clean build before starting (make mrproper)
  -f  Build for all available targets
  -k  Build all combinations (Permissive/Enforcing, KSU/NoKSU) for all devices
  -l  Enable KernelSU
  -m  Set Selinux to always enforce
  -h  Show this help message
EOF
    exit 0
}