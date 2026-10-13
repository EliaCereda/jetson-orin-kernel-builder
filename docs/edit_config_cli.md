# NVIDIA Jetson Kernel Configuration Script

## Overview
This script allows users to edit the kernel configuration for an **NVIDIA Jetson Developer Kit**. It automates the process of locating the kernel source directory and launching the `menuconfig` tool to configure the kernel. The script also verifies required dependencies and prompts the user to install them if necessary.

## Requirements and Dependencies
To run this script, you must have the following installed on your system:
- **Bash shell** (pre-installed on most Linux systems)
- **ncurses development package** (required for `menuconfig`): `libncurses5-dev` on Ubuntu 22.04, `libncurses-dev` on Ubuntu 24.04
- **Kernel source code** located in the `/usr/src/` directory or a user-specified path

### Installation of Dependencies
If the ncurses development package is not installed, the script will prompt the user to install it (selecting the correct package name for your Ubuntu release), for example:
```bash
sudo apt-get update && sudo apt-get install -y libncurses-dev
```

## Usage
Run the script using:
```bash
./scripts/edit_config_cli.sh [[-d directory ] | [-h]]
```

### Options
- `-d, --directory <path>` : Specifies the directory where the kernel source is located (default: `/usr/src/`).
- `-h, --help` : Displays the usage information and exits.

### Example Usage
To edit the kernel configuration using the default kernel source path:
```bash
./scripts/edit_config_cli.sh
```
To specify a custom kernel source directory:
```bash
./scripts/edit_config_cli.sh -d /path/to/kernel/source
```
To display the help message:
```bash
./scripts/edit_config_cli.sh -h
```

## Workflow and Key Steps
1. **Parse Command-Line Arguments**  
   - The script checks for the `-d` flag to override the default kernel source directory.
   - If the `-h` flag is provided, the script displays the usage message and exits.

2. **Ensure Directory Path Format**  
   - The script ensures the provided directory path ends with a trailing slash (`/`).

3. **Check for the ncurses Dependency**  
   - The script checks if the ncurses development package for your Ubuntu release is installed.
   - If missing, the user is prompted to install it. If declined, the script exits.

4. **Verify Kernel Source Directory**  
   - The script detects the kernel source path under `/usr/src/kernel/`, for example:  
     ```
     /usr/src/kernel/kernel-noble      # JetPack 7.X (kernel-jammy-src on JetPack 6.X)
     ```
   - If the directory does not exist, an error message is displayed, and the script exits.

5. **Launch Kernel Configuration Tool (`menuconfig`)**  
   - The script changes to the kernel source directory.
   - The `menuconfig` tool is launched using:
     ```bash
     sudo make menuconfig
     ```

## Error Handling
- If an invalid option is provided, the script displays a usage message and exits.
- If the ncurses development package is missing and the user declines installation, the script exits with an error.
- If the kernel source directory does not exist, an error message is shown, and the script exits.

