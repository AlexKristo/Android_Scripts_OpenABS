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

: "${CONFIG_FLAVOUR:=stub}" # flavour-{profile}.sh, these profiles are found in Kitchen/profiles directory
set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # A pipeline will fail if any command in it fails.
capture_dir="$(pwd)"
dir="$capture_dir" # Static one-parse time of kernel dir
toolchain="$dir/toolchain"
HOST_ARCH="$(uname -m)"

source "$dir/Kitchen/Functions/functions.sh"
source "$dir/Kitchen/Functions/functions-overlay.sh"

if [ "$CONFIG_FLAVOUR" != "N" ] && [ "$CONFIG_FLAVOUR" != "stub" ]; then
    file_exists "$dir/Kitchen/profiles/flavour-$CONFIG_FLAVOUR.sh" || exit 1
    source "$dir/Kitchen/profiles/flavour-$CONFIG_FLAVOUR.sh"
elif [ "$CONFIG_FLAVOUR" = "stub" ]; then
    error "Using stub config flavour is not allowed"
    exit 1
else
    error "Set a valid flavour profile for the buildsystem."
    info "Check build.sh for guidance."
    exit 1
fi

while getopts "abfklmh" opt; do
    case $opt in
        a) CONFIG_MKBOOTIMG=n ;;
        b) CONFIG_CLEAN_BUILD=y ;;
        f) CONFIG_MAKE_ALL=y; SKIP_PROMPT=y ;;
        k) CONFIG_MAKE_ALL_PLUS=y; SKIP_PROMPT=y; SKIP_PROMPT_SELINUX=y; SKIP_PROMPT_KSU=y ;;
        l) CONFIG_SUBMODULES_KSU=y; SKIP_PROMPT_KSU=y ;;
        m) CONFIG_ALWAYS_PERMISSIVE=n; SKIP_PROMPT_SELINUX=y ;;
        h) get_help ;;
        *) get_help ;;
    esac
done

if [ $CONFIG_CLI_SETUP != "y" ]; then
    clear # Clean terminal before running build
fi

if [ "$CONFIG_CLI_SETUP" != "y" ]; then
    if [ "$SKIP_PROMPT" != "y" ]; then
        while true; do
            echo -n "Select Target [${build_order[*]}, ALL]: "
            read choice
            choice="${choice^^}"
            matched=false
            for target in "${build_order[@]}" ALL; do
                if [[ "$choice" == "$target" ]]; then
                    matched=true
                    break
                fi
            done
            if $matched; then
                CONFIG_SELECTED="$choice"
                [[ "$choice" == "ALL" ]] && CONFIG_MAKE_ALL=y
                break
            else
                error "Invalid selection: '$choice'. Please choose from ${build_order[*]}, or ALL."
            fi
        done
    fi

    if [ "$CONFIG_MAKE_ALL_PLUS" != "y" ]; then
        if [ "$SKIP_PROMPT_SELINUX" != "y" ]; then
            prompt_yes_no "Selinux Always Permissive? [y/N]: " CONFIG_ALWAYS_PERMISSIVE 'n'
        fi
        if [ "$SKIP_PROMPT_KSU" != "y" ]; then
            prompt_yes_no "Enable KernelSU? [y/N]: " CONFIG_SUBMODULES_KSU 'n'
        fi

    fi
fi

if [ "$CONFIG_MAKE_ALL" = "y" ] && [ "$CONFIG_MAKE_ALL_PLUS" = "y" ]; then
    error "Cannot select both MAKE_ALL (-f) and MAKE_ALL_PLUS (-k) simultaneously."
    exit 1
fi

set_toolchain_prefix

if [ ! -d "$dir/Kitchen/bin" ] && [ "$CONFIG_MKBOOTIMG" = "y" ]; then
    error "Kitchen folder is missing, that has the needed tools for generating boot.img"
    error "Aborting..."
    exit 1
fi

if [ ! -f "$dir/Kitchen/boot/$CONFIG_BASE_BOOTIMG" ] && [ "$CONFIG_MKBOOTIMG" = "y" ]; then
    error "Base boot.img: $CONFIG_BASE_BOOTIMG not found under $dir/Kitchen/boot/"
    error "Aborting..." 
    exit 1
fi

download_toolchain
setup_environment
mkdir -p "$dir/out"
mkdir -p "$dir/Kitchen/logs" # Fix build errorr when dir is missing

if [ "$CONFIG_MKBOOTIMG" = "y" ]; then 
  cache_base_bootimg

  # Populate mkbootimg options
  KERNEL="$dir/Kitchen/premade-mkbootimg/${CONFIG_BASE_BOOTIMG}-kernel"
  RAMDISK="$dir/Kitchen/premade-mkbootimg/${CONFIG_BASE_BOOTIMG}-ramdisk"
  DT="$dir/Kitchen/premade-mkbootimg/${CONFIG_BASE_BOOTIMG}-dt"
  BASE="$(cat "$dir/Kitchen/premade-mkbootimg/${CONFIG_BASE_BOOTIMG}-base")"
  KERNEL_OFFSET="$(cat "$dir/Kitchen/premade-mkbootimg/${CONFIG_BASE_BOOTIMG}-kernel_offset")"
  SECOND_OFFSET="$(cat "$dir/Kitchen/premade-mkbootimg/${CONFIG_BASE_BOOTIMG}-second_offset")"
  TAGS_OFFSET="$(cat "$dir/Kitchen/premade-mkbootimg/${CONFIG_BASE_BOOTIMG}-tags_offset")"
  CMDLINE="$(cat "$dir/Kitchen/premade-mkbootimg/${CONFIG_BASE_BOOTIMG}-cmdline")"
  OS_VERSION="$(cat "$dir/Kitchen/premade-mkbootimg/${CONFIG_BASE_BOOTIMG}-os_version")"
  OS_PATCH_LEVEL="$(cat "$dir/Kitchen/premade-mkbootimg/${CONFIG_BASE_BOOTIMG}-os_patch_level")"
  PAGESIZE="$(cat "$dir/Kitchen/premade-mkbootimg/${CONFIG_BASE_BOOTIMG}-pagesize")"

  # Genbootimg logic
  REAL_KERNEL="$dir/arch/$ARCH/boot/Image"
  REAL_DT="${dt[$CONFIG_SELECTED]}"
fi

[ "$CONFIG_SUBMODULES" = "y" ] && info "Initialising Git Submodules..." && git submodule update --init --recursive
[ "$CONFIG_CLEAN_BUILD" = "y" ] && info "Cleaning build artifacts..." && make clean && make mrproper

if [ "$CONFIG_SUBMODULES" = "y" ]; then 
     info "Updating Git Submodules..."
     git submodule update --remote --merge -f > /dev/null || exit 1
fi

if [ "$CONFIG_MAKE_ALL_PLUS" = "y" ]; then
    env_log "Starting MAKE_ALL_PLUS: Building all combinations..."
    build_combinations plus
elif [ "$CONFIG_MAKE_ALL" = "y" ]; then
    env_log "Starting MAKE_ALL: Building for all supported devices..."
    build_combinations stn
else
    build_target "$CONFIG_SELECTED"
fi

info "Final artifacts are in the '$dir/Kitchen/out' directory:"