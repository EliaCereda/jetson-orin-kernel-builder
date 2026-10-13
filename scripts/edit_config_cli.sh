#!/bin/bash
# Command-Line Kernel Configuration Script for NVIDIA Jetson Developer Kit
# This script enables users to configure the Linux kernel using 'make menuconfig', 
# a text-based interface for kernel configuration. It verifies the presence of 
# the required ncurses library and prompts the user to install it if missing.
# Once dependencies are met, it locates the kernel source directory under the given
# parent (default: /usr/src) and launches 'make menuconfig'. The source directory name
# varies by release (kernel-jammy-src on JetPack 6.X, kernel-noble on JetPack 7.X) and
# is detected automatically.
#
# Usage:
#   ./edit_config_cli.sh [[-d directory ] | [-h]]
#
# Options:
#   -d | --directory  Specify the parent directory containing the kernel source
#                     (default: /usr/src)
#   -h | --help       Display this help message
#
# Example:
#   ./edit_config_cli.sh                   # Use default kernel source directory
#   ./edit_config_cli.sh -d /custom/src    # Specify a custom kernel source parent
#
# Notes:
# - If the ncurses development package is missing, the script prompts the user to
#   install it ('libncurses5-dev' on Ubuntu 22.04, 'libncurses-dev' on Ubuntu 24.04).
# - If the kernel source directory does not exist, the script exits with an error.
# - Requires sudo permissions to modify kernel configurations.
#
# Copyright (c) 2016-25 JetsonHacks
# MIT License

# Shared helpers for locating the kernel source tree
source "$(dirname "$(readlink -f "$0")")/kernel_paths.sh"

SOURCE_TARGET="/usr/src"
KERNEL_RELEASE=$(uname -r | cut -d. -f1-2)

function usage {
    echo "usage: ./editConfig.sh [[-d directory ] | [-h]]"
    echo "-d | --directory Directory path to parent of kernel"
    echo "-h | --help  This message"
}

# Parse command-line options
while [ "$1" != "" ]; do
    case $1 in
        -d | --directory ) shift
                           SOURCE_TARGET=$1
                           ;;
        -h | --help )      usage
                           exit 0
                           ;;
        * )                usage
                           exit 1
    esac
    shift
done

# Ensure directory path has a trailing slash
if [[ "${SOURCE_TARGET: -1}" != "/" ]]; then
   SOURCE_TARGET="${SOURCE_TARGET}/"
fi

# Check for the ncurses development package. Ubuntu 22.04 (Jammy) ships
# libncurses5-dev; Ubuntu 24.04 (Noble) replaced it with libncurses-dev.
NCURSES_PKG=$(ncurses_dev_package)
if ! dpkg -s "$NCURSES_PKG" &> /dev/null; then
    echo "[WARNING] '$NCURSES_PKG' is not installed. It is required for 'menuconfig'."
    read -rp "Would you like to install it now? (Y/N): " INSTALL_CHOICE
    case "$INSTALL_CHOICE" in
        [Yy]* )
            echo "Installing '$NCURSES_PKG'..."
            sudo apt-get update && sudo apt-get install -y "$NCURSES_PKG"
            ;;
        [Nn]* )
            echo "[ERROR] '$NCURSES_PKG' is required. Exiting."
            exit 1
            ;;
        * )
            echo "[ERROR] Invalid choice. Please enter Y or N."
            exit 1
            ;;
    esac
fi

# Locate the kernel source directory (name varies by release)
if ! PROPOSED_SRC_PATH=$(resolve_kernel_src "$SOURCE_TARGET"); then
  tput setaf 1
  echo "==== Cannot find kernel source! =============== "
  tput sgr0
  echo "The kernel source does not appear to be installed under: "
  echo "   ${SOURCE_TARGET}kernel/"
  echo "Expected one of: ${KNOWN_KERNEL_SRC_DIRS[*]}"
  echo "Unable to edit kernel configuration."
  exit 1
fi

echo "Kernel source path: ${PROPOSED_SRC_PATH}"

# Enter kernel source directory and launch menuconfig
cd "$PROPOSED_SRC_PATH"
sudo make menuconfig
