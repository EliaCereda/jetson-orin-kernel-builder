# Kernel Configuration Script Documentation

## Overview

This script facilitates the use of `make xconfig`, which provides a graphical interface for configuring Linux kernel options. It ensures that the necessary Qt5 libraries are installed and then launches `make xconfig` in the specified kernel source directory.

## Requirements

- A valid Linux kernel source directory containing a `Makefile`. The directory is auto-detected under `/usr/src/kernel/` (`kernel-jammy-src` on JetPack 6.X, `kernel-noble` on JetPack 7.X), but this can be overridden using the directory override flag.
- The Qt5 development libraries (`Qt5Core`, `Qt5Gui`, `Qt5Widgets`), which are required to run `make xconfig`.

## Usage
To invoke the script from the repository root directory, run 

```bash
./scripts/edit_config_gui.sh
```

to use the auto-detected kernel source directory under `/usr/src/kernel/`, or use the directory override flag by running:

```bash
./scripts/edit_config_gui.sh /path/to/kernel/source
```

to specify a different directory.
