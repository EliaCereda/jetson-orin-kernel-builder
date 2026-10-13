# Custom kernel `6.8.12-1021-tegra-elia` — build recipe (2026-08-10)

Why: stock NVIDIA kernel lacks `NF_CONNTRACK_MARK` (Tailscale connmark health
warning) and `LOGITECH_FF`. `NF_CONNTRACK_MARK=y` changes `struct nf_conn`, so
it can NEVER be added as a bolt-on module — kernel Image + ALL modules (in-tree
AND NVIDIA OOT) must be rebuilt and installed together. Installing only the
modules over the stock Image = MODVERSIONS CRC mismatch = every module refused
at boot = network dead ("the brick", 2026-08-10).

Prereqs: kernel sources at /usr/src (scripts/get_kernel_sources.sh), build deps
(libssl-dev, libncurses-dev), ~10 GB free.

## 1. Configure  (/usr/src/kernel/kernel-noble)
```bash
cd /usr/src/kernel/kernel-noble
sudo scripts/config --set-str LOCALVERSION "-1021-tegra-elia"
sudo scripts/config --enable NF_CONNTRACK_MARK --module NETFILTER_XT_CONNMARK --enable LOGITECH_FF
sudo make olddefconfig
sudo rm -f include/config/kernel.release   # force release re-gen
sudo make -s prepare && sudo make -s kernelrelease   # must print 6.8.12-1021-tegra-elia
```
LOCALVERSION suffix keeps everything side-by-side; the stock kernel stays intact
as the extlinux `primary` fallback entry.

## 2. Build + install kernel and in-tree modules
```bash
sudo make -j$(($(nproc)-1)) Image modules
sudo make INSTALL_MOD_STRIP=1 modules_install   # -> /lib/modules/6.8.12-1021-tegra-elia/
```

## 3. NVIDIA OOT modules (nvgpu, nvidia-oot, hwpm, display)
**Both variables are required.** Without `kernel_name=noble`, tegra_hv/ivc_ext
build for real and modpost fails with "exported twice. Previous export was in
vmlinux" (Makefile.config.noble stubs the modules the kernel has built in).
```bash
cd /usr/src
export KERNEL_HEADERS=/usr/src/kernel/kernel-noble
sudo -E make kernel_name=noble modules
sudo -E make kernel_name=noble modules_install
sudo depmod 6.8.12-1021-tegra-elia
```

## 4. Install boot files side-by-side
```bash
sudo cp /usr/src/kernel/kernel-noble/arch/arm64/boot/Image /boot/Image.elia
sudo cp /usr/src/kernel/kernel-noble/.config /boot/config-6.8.12-1021-tegra-elia
sudo update-initramfs -c -k 6.8.12-1021-tegra-elia
```

## 5. extlinux entry  (/boot/extlinux/extlinux.conf)
Append (copy the APPEND line verbatim from the `primary` entry):
```
LABEL elia
      MENU LABEL elia kernel (connmark)
      LINUX /boot/Image.elia
      INITRD /boot/initrd.img-6.8.12-1021-tegra-elia
      APPEND <same as primary>
```
Then flip `DEFAULT primary` -> `DEFAULT elia` and reboot.

## 6. Validate
```bash
uname -r                                   # 6.8.12-1021-tegra-elia
sudo dmesg | grep -icE "disagrees|unknown symbol"   # must be 0
lsmod | grep nvgpu                         # loaded
sudo modprobe xt_connmark                  # loads
tailscale status --json | grep -A2 Health  # []
```

## Recovery (headless, no UART)
Kernel fails to boot -> pull NVMe, attach to the docker-vm QEMU guest
(needs `-device virtio-blk-pci,drive=<id>` per raw disk!), mount APP partition,
edit /boot/extlinux/extlinux.conf back to `DEFAULT primary`. Stock Image +
/lib/modules/6.8.12-1021-tegra are untouched. Also: check the MLX4 NIC PSU
before assuming a brick, and the USB-C gadget port gives a serial console
(/dev/cu.usbmodem* on macOS) once Linux is up.

## After a JetPack kernel update
The elia entry keeps booting the OLD custom kernel. Either redo this recipe on
the new source, or flip DEFAULT back to primary.

## 7. DKMS modules (zfs, etc.)
DKMS packages are only built for the kernel they were installed under; a new
custom kernel needs an explicit rebuild (found out via "modprobe zfs" failing):
```bash
sudo dkms install zfs/2.2.2 -k 6.8.12-1021-tegra-elia   # or: sudo dkms autoinstall -k $(uname -r)
```
Works because /lib/modules/6.8.12-1021-tegra-elia/build -> /usr/src/kernel/kernel-noble.
Repeat for any other DKMS module shown by "dkms status".
