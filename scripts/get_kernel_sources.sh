#!/bin/bash
# Kernel Source Retrieval and Setup Script for NVIDIA Jetson Developer Kit
# This script downloads, extracts, and configures the kernel source for Jetson Linux 36.X
# (JetPack 6.X, Ubuntu 22.04 Jammy) and Jetson Linux 39.X (JetPack 7.X, Ubuntu 24.04 Noble).
# It ensures required dependencies are installed, provides options for backing up or
# replacing existing sources, and sets up the kernel source for compilation.
# Logs the entire process for reference.
#
# Usage:
#   ./get_kernel_sources.sh [--force-replace] [--force-backup]
#
# Options:
#   --force-replace  Delete existing kernel sources and download fresh sources.
#   --force-backup   Backup existing kernel sources before downloading new ones.
#
# Example:
#   ./get_kernel_sources.sh             # Interactive mode: prompts user if sources exist
#   ./get_kernel_sources.sh --force-replace # Force delete and redownload kernel sources
#   ./get_kernel_sources.sh --force-backup  # Backup existing sources and download new ones
#
# Logs are saved in a 'logs' directory within the script's execution path.
#
# Copyright (c) 2016-25 JetsonHacks
# MIT License

set -e  # Exit on error

# Shared helpers for locating the kernel source tree
source "$(dirname "$(readlink -f "$0")")/kernel_paths.sh"

# Set the log directory to ./logs relative to the current working directory
LOG_DIR="$PWD/logs"
# Generate a timestamp for the log file name
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
# Set the log file path with the timestamp
LOG_FILE="$LOG_DIR/get_kernel_sources_$TIMESTAMP.log"
# Ensure the logs directory exists
mkdir -p "$LOG_DIR"

# Define kernel source directory (for native Jetson builds)
KERNEL_SRC_DIR="/usr/src/"

# Default behavior (interactive mode)
FORCE_REPLACE=0
FORCE_BACKUP=0

# Check if user has sudo privileges
if [[ $EUID -ne 0 ]]; then
  if ! sudo -v; then
    echo "[ERROR] This script requires sudo privileges. Please run with sudo access."
    exit 1
  fi
fi

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --force-replace) FORCE_REPLACE=1 ;;
    --force-backup) FORCE_BACKUP=1 ;;
    *) echo "[ERROR] Invalid option: $1" && exit 1 ;;
  esac
  shift
done

# Logging function
log() {
  echo "[INFO] $(date +"%Y-%m-%d %H:%M:%S") - ${1}" | tee -a "$LOG_FILE"
}

# Extract L4T version details using sed
L4T_MAJOR=$(sed -n 's/^.*R\([0-9]\+\).*/\1/p' /etc/nv_tegra_release)
L4T_MINOR=$(sed -n 's/^.*REVISION: \([0-9]\+\(\.[0-9]\+\)*\).*/\1/p' /etc/nv_tegra_release)

SOURCE_BASE="https://developer.nvidia.com/embedded/l4t/r${L4T_MAJOR}_release_v${L4T_MINOR}/sources"
SOURCE_FILE="public_sources.tbz2"

log "Detected L4T version: ${L4T_MAJOR} (${L4T_MINOR})"
log "Kernel sources directory: $KERNEL_SRC_DIR"

# Check if kernel sources already exist
if [[ -d "$KERNEL_SRC_DIR/kernel" ]]; then
  if [[ "$FORCE_REPLACE" -eq 1 ]]; then
    log "Forcing deletion of existing kernel sources..."
    sudo rm -rf "$KERNEL_SRC_DIR/kernel"
  elif [[ "$FORCE_BACKUP" -eq 1 ]]; then
    BACKUP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="${KERNEL_SRC_DIR}kernel_backup_${BACKUP_TIMESTAMP}"
    log "Forcing backup of existing kernel sources to $BACKUP_DIR..."
    sudo mv "$KERNEL_SRC_DIR/kernel" "$BACKUP_DIR"
  else
    echo "Kernel sources already exist at $KERNEL_SRC_DIR/kernel."
    echo "What would you like to do?"
    echo "[K]eep existing sources (default)"
    echo "[R]eplace (delete and re-download)"
    echo "[B]ackup and download fresh sources"
    read -rp "Enter your choice (K/R/B): " USER_CHOICE
    case "$USER_CHOICE" in
      [Rr]* ) 
        log "Deleting existing kernel sources..."
        sudo rm -rf "$KERNEL_SRC_DIR/kernel"
        ;;
      [Bb]* ) 
        BACKUP_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        BACKUP_DIR="${KERNEL_SRC_DIR}kernel_backup_${BACKUP_TIMESTAMP}"
        log "Backing up existing kernel sources to $BACKUP_DIR..."
        sudo mv "$KERNEL_SRC_DIR/kernel" "$BACKUP_DIR"
        ;;
      * ) 
        log "Keeping existing kernel sources. Skipping download."
        exit 0
        ;;
    esac
  fi
fi

log "Downloading kernel sources from: $SOURCE_BASE/$SOURCE_FILE"
wget -N "$SOURCE_BASE/$SOURCE_FILE"

log "Extracting sources..."
# Components to pull out of the release tarball. The unified GPU display driver is
# only shipped starting with Jetson Linux 39.X (JetPack 7.X), so it is optional.
COMPONENTS=(kernel_src.tbz2 kernel_oot_modules_src.tbz2 nvidia_kernel_display_driver_source.tbz2)
OPTIONAL_COMPONENTS=(nvidia_unified_gpu_display_driver_source.tbz2)

TAR_MEMBERS=()
for component in "${COMPONENTS[@]}"; do
  TAR_MEMBERS+=("Linux_for_Tegra/source/$component")
done

# Only request optional components that this release actually ships
for component in "${OPTIONAL_COMPONENTS[@]}"; do
  if tar -tf "$SOURCE_FILE" "Linux_for_Tegra/source/$component" &> /dev/null; then
    log "Release includes optional component: $component"
    COMPONENTS+=("$component")
    TAR_MEMBERS+=("Linux_for_Tegra/source/$component")
  fi
done

tar -xvf "$SOURCE_FILE" "${TAR_MEMBERS[@]}" --strip-components=2

# Extract each component separately into /usr/src/
for component in "${COMPONENTS[@]}"; do
  log "Extracting $component..."
  sudo tar -xvf "$component" -C "$KERNEL_SRC_DIR"
done

# Cleanup tarballs
rm "${COMPONENTS[@]}" "$SOURCE_FILE"

log "Kernel sources and modules extracted to $KERNEL_SRC_DIR"

# Locate the extracted kernel source tree. The directory name follows the Ubuntu
# codename of the release (kernel-jammy-src on 36.X, kernel-noble on 39.X).
if ! KERNEL_SOURCE_PATH=$(resolve_kernel_src "$KERNEL_SRC_DIR"); then
  log "[ERROR] Could not locate the kernel source tree under ${KERNEL_SRC_DIR}kernel/"
  log "Expected one of: ${KNOWN_KERNEL_SRC_DIRS[*]}"
  exit 1
fi
log "Using kernel source tree: $KERNEL_SOURCE_PATH"

# Copy the current kernel config (requires sudo)
log "Copying current kernel config..."
sudo zcat /proc/config.gz | sudo tee "${KERNEL_SOURCE_PATH}/.config" > /dev/null

# Set the local version for the kernel build process
KERNEL_VERSION=$(uname -r)
LOCAL_VERSION="-$(echo ${KERNEL_VERSION} | cut -d "-" -f2-)"
cd "${KERNEL_SOURCE_PATH}"
sudo cp .config .config.orig
sudo bash scripts/config --file .config --set-str LOCALVERSION $LOCAL_VERSION

# Check if libssl-dev is installed
if ! dpkg -s libssl-dev > /dev/null 2>&1; then
    log "libssl-dev is not installed. Installing..."
    sudo apt-get install -y libssl-dev
    if [ $? -eq 0 ]; then
        log "libssl-dev installed successfully."
    else
        log "Failed to install libssl-dev. Please install it manually."
        exit 1
    fi
else
    log "libssl-dev is already installed."
fi

log "Kernel source setup complete!"
