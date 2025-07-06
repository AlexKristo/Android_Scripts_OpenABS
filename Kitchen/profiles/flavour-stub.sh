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

#
# THIS IS A STUB 
# Take this file as reference for configuring the buildsystem
#

# Define env vars here. You may write buildsystem's env vars here.
# Env vars not present in buildsystem may not be written here.

# Start env vars definitions
# Write any env var defined in buildsystem

# Pre-setup Env
: "${CONFIG_SELECTED:=stub}"                # Stub0, Stub1, Stub3
: "${CONFIG_LOCALVERSION:=lorem_ipsum}"     # Kernel name
: "${CONFIG_TOOLCHAIN:=stub}"               # GCC or CLANG
: "${CONFIG_GCC_VERSION:=stub}"             # According to defined versions
: "${CONFIG_CLANG_VERSION:=19}"             # According to defined versions
: "${CONFIG_BCMDHD:=stub}"                  # Applies only to Dual-Wifi driver kernels. Select NEW to enable, otherwise select N
: "${CONFIG_MKBOOTIMG:=y}"                  # To build boot.img after 'make build'
: "${CONFIG_EXTRA:=overlay_defconfig}"      # To merge with device defconfig at build time
: "${CONFIG_BASE_BOOTIMG:=boot-stub.img}"   # All roms have their own init binaries, so extract from target rom stock img
: "${CONFIG_SUBMODULES:=y}"                 # To dictate whether to fetch and update submodules
: "${CONFIG_SUBMODULES_KSU:=n}"             # To dictate whether its KernelSU build or not
: "${CONFIG_ALWAYS_PERMISSIVE:=y}"          # To dictate wether to make a Permissive SELINUX Build
: "${CONFIG_MAKE_ALL:=n}"                   # Build for all targets. Selectable only if CONFIG_MAKE_ALL_PLUS is N
: "${CONFIG_MAKE_ALL_PLUS:=n}"              # Build all permissive/KSU combinations for all targets
: "${CONFIG_CLI_SETUP:=n}"                  # Disables all interactive user prompts, so you configure by script flags 
: "${CMD_SILENT:=y}"                        # To silence some stuff like defconfig generation
: "${KVER:=0.1}"                            # Kernel Version

# Kbuild
export ARCH=arm64 
export SUBARCH=arm64

# Buildsystem
build_order=("Stub3" "Stub2" "Stub0") # Any amount of targets accepted.
SUPER_ARCH="exynos"
defconfig_dir="$dir/arch/$ARCH/configs"
dt_dir="$dir/arch/$ARCH/boot/dts/$SUPER_ARCH"
HEADER_VERSION="0" # Mkbootimg Dependendent

declare -A dt=(
  [A1]="$dt_dir/A1xxxxxxxxxxxxxxxxxxxxxxxxxxxxx.dtb"    # Stub
  [A2]="$dt_dir/A2xxxxxxxxxxxxxxxxxxxxxxxxxxxxx.dtb"   # Stub
  [A3]="$dt_dir/A3xxxxxxxxxxxxxxxxxxxxxxxxxxxxx.dtb"   # Stub
)   

declare -A defconfigs=(
  [A1]="a1_defconfig"                  # Stub
  [A2]="a2_defconfig"                  # Stub
  [A3]="a3_defconfig"                  # Stub
)

declare -A clang_versions=(
  [14]="llvm-r450784/clang-r450784b"
  [19]="llvm-r530567/clang-r530567"
  [20]="main/clang-r547379"
)
clang_ref="${clang_versions[$CONFIG_CLANG_VERSION]}"
clang_url="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/$clang_ref.tar.gz"
clang_dir="$toolchain/clang-${CONFIG_CLANG_VERSION}"

declare -A gcc_versions=(
  [11.3]="gcc-11.3"
  [12.3]="gcc-12.3"
  [13.3]="gcc-13.3"
  [14]="0"
)

declare -A gcc_urls=(
  [11.3]="https://developer.arm.com/-/media/Files/downloads/gnu/11.3.rel1/binrel/arm-gnu-toolchain-11.3.rel1-x86_64-aarch64-none-linux-gnu.tar.xz"
  [12.3]="https://developer.arm.com/-/media/Files/downloads/gnu/12.3.rel1/binrel/arm-gnu-toolchain-12.3.rel1-x86_64-aarch64-none-linux-gnu.tar.xz"
  [13.3]="https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-linux-gnu.tar.xz"
  [15]="0"
)
gcc_dir="$toolchain/${gcc_versions[$CONFIG_GCC_VERSION]}"

build_target() {
    local target_device="$1"
    local base_defconfig="${defconfigs[$target_device]}"

    if [ -z "$base_defconfig" ]; then
        error "Invalid target device: '$target_device'. Please choose from [${build_order[@]}, ALL]."
        return 1
    fi

    # 1. Generate Dynamic Name
    local out_name="$CONFIG_LOCALVERSION-$KVER-$target_device"

    info "Starting build for $target_device"
    env_log "Output name: $out_name.img"

    # 2. Generate Defconfig
    info "Generating final defconfig..."
    local temp_defconfig="$defconfig_dir/temp_defconfig"
    cat "$defconfig_dir/$base_defconfig" "$defconfig_dir/$CONFIG_EXTRA" > "$temp_defconfig"

    if [ "$CMD_SILENT" = "y" ]; then
        if ! make temp_defconfig > /dev/null 2>&1; then
            error "Failed to generate final defconfig"
            exit 1
        fi
    else
        if ! make temp_defconfig; then
            error "Failed to generate final defconfig"
            exit 1
        fi
    fi
    scripts/config --set-str CONFIG_LOCALVERSION "-$out_name" # Set CONFIG_LOCALVERSION in .config

    # 3. Build Kernel
    clean_dtb
    rm -f $dir/out/build_errors.log
    info "Building kernel..."
    export BUILD_START="$(date +"%T")"
    if [ "$CMD_SILENT" = "y" ]; then
        if ! make ARCH=arm64 -j"$(nproc)" > /dev/null 2>Kitchen/logs/build_errors.log; then
            error "Kernel build failed!"
            info "Export CMD_SILENT to 'n' for debugging.."
            env_log "See $dir/Kitchen/logs/build_errors.log for details."
            exit 1
        fi
    else
        if ! make ARCH=arm64 -j"$(nproc)"; then
            error "Kernel build failed!"
            exit 1
        fi
    fi
    export BUILD_END="$(date +"%T")"
    rm -f $dir/Kitchen/logs/build_errors.log # Automatically cleanup if make build is succesful

    # 4. Package boot.img
    if [ "$CONFIG_MKBOOTIMG" = "y" ]; then
        info "Packaging new boot.img..."
        (
            if [ $CMD_SILENT = "y" ]; then
                build_boot > /dev/null 2>&1
            else
                build_boot
            fi
        )
    fi
    info "Build started at $BUILD_START and ended at $BUILD_END"
    success "Finished build for $target_device"
}

setup_environment() {
    info "Setting up build environment for $CONFIG_TOOLCHAIN $CONFIG_TC_VERSION"
    export PATH="$clang_dir:$clang_dir/bin:$clang_dir/lib:$gcc_dir:$gcc_dir/bin:$gcc_dir/lib:${PATH}"

if [ $CONFIG_TOOLCHAIN = "CLANG" ]; then
    export CC="clang"
    export REAL_CC="clang"
    export LLVM=1
    export LLVM_IAS=1
else
    export CC="$CONFIG_TC_PREFIX-gcc"
    export REAL_CC="$CONFIG_TC_PREFIX-gcc"
fi
    export AR="$CONFIG_TC_PREFIX-ar"
    export NM="$CONFIG_TC_PREFIX-nm"
    export OBJCOPY="$CONFIG_TC_PREFIX-objcopy"
    export OBJDUMP="$CONFIG_TC_PREFIX-objdump"
    export READELF="$CONFIG_TC_PREFIX-readelf"
    export STRIP="$CONFIG_TC_PREFIX-strip"
    export LD="ld.lld" # Use it for GCC Builds
    export CROSS_COMPILE=aarch64-none-linux-gnu-
    export CROSS_COMPILE_ARM32=arm-linux-gnu-
}

set_toolchain_prefix() {
    if [ "$CONFIG_TOOLCHAIN" = "GCC" ]; then
        CONFIG_TC_VERSION="$CONFIG_GCC_VERSION"
        CONFIG_TC_PREFIX="aarch64-none-linux-gnu"
    else
        CONFIG_TC_VERSION="$CONFIG_CLANG_VERSION"
        CONFIG_TC_PREFIX="llvm"
    fi
}

# Convert all targets to uppercase
for i in "${!build_order[@]}"; do
  build_order[$i]="${build_order[$i]^^}"
done

# Require LD.LLD for GCC Builds
# if [ "$GITHUB_ACTIONS" = "true" ] || [ "$CONFIG_TOOLCHAIN" = "GCC" ]; then
#     # Github Actions CI :: Need Clang Toolchain to build Kernel with LD.LLD 
#     if [ ! -d "$clang_dir/bin" ]; then
#         env_log "Downloading Clang Toolchain needed for LLD Linker..."
#         CONFIG_TOOLCHAIN="CLANG" download_toolchain
#     fi
# fi 

# GCC Compat check
# if [ $CONFIG_TOOLCHAIN = "GCC" ]; then
# max_version=14.0
# if (( $(echo "$CONFIG_GCC_VERSION >= $max_version" | bc -l) )); then
#     error "CONFIG_GCC_VERSION must be less than 14. Current: $CONFIG_GCC_VERSION"
#     exit 1
# fi
# fi

# Dependency Checks
command_exists make
command_exists bash
command_exists wget
command_exists arm-linux-gnu-ld
# command_exists works with functions too