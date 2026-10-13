#!/bin/bash
# Shared kernel source path helpers for NVIDIA Jetson Developer Kit
# This file is meant to be sourced, not executed directly.
#
# NVIDIA renames the kernel source tree to follow the Ubuntu codename of the
# release. JetPack 6.X (Jetson Linux 36.X, Ubuntu 22.04) ships the sources in
# kernel/kernel-jammy-src, while JetPack 7.X (Jetson Linux 39.X, Ubuntu 24.04)
# ships them in kernel/kernel-noble. These helpers locate the tree at runtime so
# the other scripts do not have to hardcode a release-specific name.
#
# Usage:
#   source "$(dirname "$(readlink -f "$0")")/kernel_paths.sh"
#   KERNEL_SRC=$(resolve_kernel_src /usr/src) || exit 1
#
# Copyright (c) 2016-25 JetsonHacks
# MIT License

# Known kernel source directory names, newest release first
KNOWN_KERNEL_SRC_DIRS=("kernel-noble" "kernel-jammy-src")

# Returns 0 if the given directory looks like a Linux kernel source tree
is_kernel_src_dir() {
    local candidate="$1"
    [ -d "$candidate" ] || return 1
    [ -f "$candidate/Makefile" ] || return 1
    grep -qE '^VERSION[[:space:]]*=' "$candidate/Makefile" 2>/dev/null || return 1
    grep -qE '^PATCHLEVEL[[:space:]]*=' "$candidate/Makefile" 2>/dev/null || return 1
    return 0
}

# Echoes the path to the kernel source directory, or returns 1 if none is found.
# $1 - parent directory holding the 'kernel' directory (default: /usr/src)
#
# Set KERNEL_SRC_DIR_OVERRIDE to bypass detection entirely.
resolve_kernel_src() {
    local parent="${1:-/usr/src}"

    # Trim any trailing slash so paths concatenate cleanly
    parent="${parent%/}"

    # Escape hatch: explicit override always wins
    if [ -n "$KERNEL_SRC_DIR_OVERRIDE" ]; then
        if [ -d "$KERNEL_SRC_DIR_OVERRIDE" ]; then
            echo "$KERNEL_SRC_DIR_OVERRIDE"
            return 0
        fi
        return 1
    fi

    # Probe the known layouts, newest release first
    local name
    for name in "${KNOWN_KERNEL_SRC_DIRS[@]}"; do
        if [ -d "$parent/kernel/$name" ]; then
            echo "$parent/kernel/$name"
            return 0
        fi
    done

    # Fall back to any kernel-* directory that looks like a kernel tree, so a
    # future Ubuntu codename rename does not require editing these scripts
    local candidate
    for candidate in "$parent"/kernel/kernel-*; do
        if is_kernel_src_dir "$candidate"; then
            echo "$candidate"
            return 0
        fi
    done

    return 1
}

# Echoes the name of the ncurses development package available on this release.
# Ubuntu 24.04 (Noble) dropped libncurses5-dev in favor of libncurses-dev.
ncurses_dev_package() {
    if apt-cache policy libncurses5-dev 2>/dev/null | grep -q "Candidate: (none)"; then
        echo "libncurses-dev"
    elif apt-cache policy libncurses5-dev 2>/dev/null | grep -q "Candidate:"; then
        echo "libncurses5-dev"
    else
        # Package is unknown to apt entirely; the modern name is the safer bet
        echo "libncurses-dev"
    fi
}
