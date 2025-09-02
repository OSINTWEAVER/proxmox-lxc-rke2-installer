# Upgrading Proxmox Bookworm and Installing CUDA‑Capable NVIDIA Drivers

**Goal:** Fully patch a fresh Proxmox VE 8 (Debian Bookworm) host, activate your Proxmox subscription so you can pull enterprise updates, cleanly install the latest NVIDIA Linux driver with CUDA support (via the official runfile + DKMS), and prepare the node for future GPU passthrough to LXC containers (covered in a separate guide). We also stage networking: start on a single RJ‑45 copper management link, then—after updates & NVIDIA install—bring up bonded SFP+/QSFP+ high‑speed links on a VLAN‑aware bridge before clustering.

---

## Table of Contents
1. [Assumptions & Prereqs](#assumptions--prereqs)
2. [Activate Your Proxmox Subscription (Web GUI)](#1-activate-your-proxmox-subscription-web-gui)
3. [Patch the OS & Add Debian `non-free-firmware`](#2-bring-the-os-fully-up-to-date)
4. [Purge Any Existing NVIDIA Packages](#3-clean-out-any-old-nvidia-bits)
5. [Disable Secure Boot](#4-disable-secureboot-biosuefi)
6. [Blacklist Nouveau & Rebuild initramfs](#5-blacklist-nouveau-and-rebuild-initramfs)
7. [Install Build/DKMS Prerequisites](#6-install-build--dkms-prerequisites)
8. [Download the Latest NVIDIA Feature‑Branch Driver](#7-download-the-newest-nvidia-featurebranch-driver)
9. [Install the NVIDIA Driver with DKMS](#8-install-the-driver-with-dkms)
10. [Reboot & Verify CUDA Readiness](#9-reboot-and-verify-cuda-readiness)
11. [Add SFP+/QSFP+ Bonded Networking (vmbr1, VLAN Aware)](#10-connect-and-configure-sfpqsfp-networking)
12. [Join the Proxmox Cluster](#11-join-the-proxmox-cluster-optional)
13. [Next: GPU Into LXC (Coming Soon)](#youre-ready-for-cuda-inside-lxc)

---

## Assumptions & Prereqs
- Proxmox VE 8.x host freshly installed (Debian Bookworm base).
- Root shell access on the host.
- Only the **on‑board RJ‑45** management NIC is connected at first.
- Internet connectivity available (required for subscription validation on Proxmox Community/Standard editions and for pulling updates & driver runfile).
- You have a valid Proxmox subscription key in the Proxmox Shop client area.
- You will later connect SFP+/QSFP+ interfaces for high‑speed data/VM networks.

> **Why start with just the RJ‑45?** Keeping initial networking simple avoids interface renaming, routing surprises, and multi‑path confusion while you patch, license, and install drivers. Add the complex links only after the base system is stable.

---

## 1. Activate Your Proxmox Subscription (Web GUI)

1. From a browser: `https://<host>:8006` (accept the self‑signed cert if prompted).
2. In the left tree: **Datacenter ▶︎ <your-node> ▶︎ Subscription**.
3. Click **Upload Subscription Key**.
4. Paste your key (from the Proxmox Shop portal) and click **Check**.
5. Status should show *active* for your edition (Community, Standard, etc.).
6. If you need to move the key to new hardware, log into:  
   `https://shop.proxmox.com/clientarea.php?action=services` → select your service → **Reissue License** → copy the new key and upload it as above.

> **Must do before updating:** Activating the subscription unlocks the enterprise repositories so `apt update` pulls signed packages from Proxmox's high‑quality, tested channel instead of the no‑subscription / public repo.

---

## 2. Bring the OS Fully Up‑to‑Date

Debian 12 (Bookworm) split firmware into a new `non-free-firmware` component. We'll add that and update the system.

```bash
cp /etc/apt/sources.list /etc/apt/sources.list.bak

# Append non-free-firmware to every Bookworm line that already has main contrib non-free
sed -i -E 's/^(deb .*bookworm.* main contrib non-free)(.*)$/\1 non-free-firmware\2/' /etc/apt/sources.list

apt update
apt upgrade -y         # or dist-upgrade -y if you prefer to take kernel jumps immediately
```

*Result:* System packages, kernel, and firmware are current; APT warning about the non‑free split goes away.

---

## 3. Clean Out Any Old NVIDIA Bits

If you previously experimented with packaged NVIDIA drivers (Debian, Ubuntu, CUDA repo, etc.), purge them so the runfile install won't collide.

```bash
apt-get remove --purge '^nvidia-.*' libnvidia-* || true
apt-get autoremove --purge -y || true
```

The `|| true` prevents pipeline aborts if no packages match.

---

## 4. Disable SecureBoot (BIOS/UEFI)

NVIDIA's proprietary kernel modules are not signed with your platform keys; Secure Boot will block them. Reboot into firmware setup and set **Secure Boot = Disabled**. Save & exit.

> If you *must* keep Secure Boot, you'll need to generate and enroll a Machine Owner Key (MOK), then sign the NVIDIA modules. That workflow is beyond the scope of this article but can be added later.

---

## 5. Blacklist Nouveau and Rebuild initramfs

Block the open‑source Nouveau module so it doesn't bind the GPU before NVIDIA's driver loads.

```bash
cat <<EOF >/etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
options nouveau modeset=0
EOF

# Rebuild initramfs for all installed kernels so the blacklist is baked in.
update-initramfs -u -k all
```

Reboot **after** driver install (Step 9); no need to reboot yet.

---

## 6. Install Build & DKMS Prerequisites

The NVIDIA runfile builds a kernel module locally; you need compilers, headers, and DKMS so that module auto‑rebuilds on future kernel updates.

```bash
apt install -y build-essential dkms pve-headers-$(uname -r) wget
```

- **build-essential** – GCC, g++, make, libc dev headers
- **dkms** – Auto‑rebuilds NVIDIA module when the kernel updates
- **pve-headers-$(uname -r)** – Exact headers for the running Proxmox kernel
- **wget** – Fetch the driver runfile

If the kernel gets upgraded in Step 2 and you haven't yet rebooted into it, consider rebooting now so `$(uname -r)` matches the kernel you'll actually use.

---

## 7. Download the Newest NVIDIA Feature‑Branch Driver

NVIDIA publishes *Production Branch* (long‑lived) and *New Feature Branch* drivers. Either will work; here we grab the latest feature branch.

1. Browse: <https://www.nvidia.com/en-us/drivers/unix/>
2. Copy the **Linux x86_64** "New Feature Branch" *.run* URL.
3. Download on the Proxmox host. Example (update the version if newer):

```bash
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/575.64.05/NVIDIA-Linux-x86_64-575.64.05.run
```

Check the SHA256 checksum if one is published (recommended in production environments).

---

## 8. Install the Driver with DKMS

Stop any X11 (not normally present on Proxmox) and switch to a console if needed. Then:

```bash
chmod +x NVIDIA-Linux-x86_64-575.64.05.run
./NVIDIA-Linux-x86_64-575.64.05.run --dkms --no-questions --ui=none
```

Common installer prompts (auto‑answered by flags above):
- Build kernel module? **Yes** (done)
- Register with DKMS? **Yes**
- Install 32‑bit compatibility libs? (needed only for some workloads; add `--compat32-lib` if required)

**Heads‑up:** If the installer complains about Nouveau still loaded, you either didn't blacklist correctly or you haven't rebooted since Step 5. In that case:

```bash
lsmod | grep nouveau
```
If present, reboot, then re‑run the installer.

---

## 9. Reboot and Verify CUDA Readiness

Reboot to load the new NVIDIA kernel modules:

```bash
reboot
```

After the host comes back:

```bash
nvidia-smi
```

Expected output: a table listing your GPU(s), **Driver Version** (e.g., 575.64.05), and **CUDA Version** column. If you see `No devices were found`, ensure the GPU is installed, PCIe is enabled in BIOS, and IOMMU/ACS settings aren't hiding it.

---

## 10. Configure High‑Speed Networking in the Web UI

Once the host is fully patched **and** the NVIDIA driver is verified, plug in the SFP+ or QSFP+ ports and create the bond/bridge directly in the Proxmox web interface—no shell editing required.

1. **Navigate** → **Datacenter ▶︎ `<node>` ▶︎ Network**.
2. Click **Create ▶︎ Linux Bond**.
   * **Slaves**: select the two (or more) 25 GbE / 40 GbE ports.
   * **Mode**: *802.3ad (LACP)* is typical for switch‑side LACP.
   * **Miimon**: leave `100` ms unless your switch vendor advises otherwise.
3. After the bond appears, click **Create ▶︎ Bridge**.
   * **Bridge Ports**: choose the new bond (e.g. `bond0`).
   * **VLAN Aware**: enable ✔.
   * **IPv4 / IPv6**: **leave empty** if this bridge is for VM traffic only. If you do plan to manage over this network, assign the **final** IP address now.
4. **Apply Configuration** and confirm the GUI prompts to activate. If you installed **ifupdown2** earlier, activation is almost instant; otherwise Proxmox will schedule a reboot.
5. **Switch‑side**: make sure the participating switch ports are in the correct LAG (LACP) and carry the same VLANs you expect.

> **Important:** Set your *permanent* management IPs & DNS names *before* clustering. Changing them later across multiple nodes is labor‑intensive and error‑prone.

---

## 11. Join the Proxmox Cluster (Web UI)

Only after networking is stable should you add the node to an existing cluster:

1. **Datacenter ▶︎ Cluster** on any cluster member → **Join Information** → copy the join command string.
2. On the **new node's** GUI: **Datacenter ▶︎ Cluster ▶︎ Join Cluster**.
3. Paste the cluster fingerprint and IP/hostname exactly as provided, enter `root@pam` credentials, confirm.
4. Watch the **Tasks** window for `pvecm` progress until status reads *Sync finished*.
5. Verify quorum: **Datacenter ▶︎ Cluster** should show the new node in `Online` state.

> **Tip:** If you ever must rename a node or move it to another IP subnet, plan the maintenance window—each node stores its peer list by name/IP, and `/etc/hosts`, corosync, storage definitions, and HA resources will all need adjustment.

---

Once networking is validated (LACP active on both switch ends; pings good; MTU consistent if you're using jumbo frames), you can safely join the node to an existing cluster.

From the new node:
```bash
pvecm add <cluster-ip-or-name>
```
Follow the prompts (fingerprint, root@pam credentials, etc.). After join, verify quorum:
```bash
pvecm status
```

> Always bring nodes into a cluster **after** they're patched and network‑stable. Partial/failed cluster joins are harder to unwind.

---

## You're Ready for CUDA Inside LXC

Your Proxmox host is now:
- Licensed (enterprise repos active)
- Fully patched (Debian + Proxmox + firmware)
- Clean of legacy NVIDIA bits
- Running the latest NVIDIA driver with DKMS
- Prepared for high‑speed bonded networking
- Cluster‑ready

**Next guide:** Exposing the GPU to LXC containers and enabling CUDA workloads across your Proxmox cluster.

---

### Appendix A – Post‑Upgrade Health Checklist
Tick each box before moving on to GPU passthrough or clustering.

| Area | Command / GUI Check | Expectation |
|------|--------------------|-------------|
| **Subscription** | GUI → *Datacenter ▶︎ `<node>` ▶︎ Subscription* | Status = **Active** |
| **Repositories** | `apt update` | No warnings; enterprise & Debian repos fetch clean |
| **Kernel vs. Headers** | `uname -r` matches `dpkg -l | grep pve-headers` | Same version string |
| **DKMS Module** | `dkms status | grep nvidia` | Shows *installed* & *built* for current kernel |
| **Modules Loaded** | `lsmod | grep -E "nvidia|nouveau"` | `nvidia*` present, **nouveau absent** |
| **Driver OK** | `nvidia-smi` | Lists GPU(s) & driver 575.64.05; CUDA version column present |
| **Bond LACP** | Switch CLI or GUI | Ports in LAG, LACP *active* |
| **vmbr1** | GUI → *Network* | vmbr1 state = *Active*, VLAN aware ✔ |
| **Ping Across Bond** | `ping -c4 <gateway>` | <1 ms average, 0% loss |
| **Cluster Quorum** (if joined) | `pvecm status` | Quorate, expected node count |

When every row meets the expectation, the node is ready for production workloads.

---

### Appendix B – Common Issues & Fixes

> **Tip:** Keep `/var/log/installer/nvidia-installer.log` and `journalctl -xe` open in a second SSH window while troubleshooting.

| Symptom | Likely Cause | Quick Fix |
|---------|--------------|-----------|
| **Installer aborts: "Nouveau is currently in use"** | Nouveau module still loaded | `lsmod | grep nouveau` → if present, `update-initramfs -u -k all && reboot`, then rerun installer |
| **`nvidia-smi` → "No devices were found"** | GPU invisible to OS (PCIe disable, power, or IOMMU) | 1) Verify card in `lspci -nn | grep -i nvidia`; 2) Check BIOS slot set to *Enabled / Gen4 / Gen3*; 3) Confirm both 8‑pin PCIe power leads are seated |
| **DKMS build fails during kernel upgrade** | Headers for new kernel missing | `apt install pve-headers-$(uname -r) && dkms autoinstall` |
| **Black screen / kernel panic on boot** | Mismatched driver vs. kernel, or Secure Boot re‑enabled | Boot old kernel from GRUB, purge driver (`apt-get remove --purge '^nvidia-.*'`), reinstall; ensure Secure Boot remains *Disabled* |
| **High fan speed, GPU stuck in P0** | Persistence daemon off | `nvidia-smi -pm 1` to enable persistence; consider `nvidia-smi -pl <watts>` to cap power |
| **LACP bond shows *down* in GUI** | Switch not set to LACP or wrong hashing | Verify switchport config (`channel-group` / `lag`), ensure mode *active*, hashing *Layer3+4* on both sides |
| **Cluster join fails (transport endpoint)** | Corosync multicast blocked or hostname mismatch | Ping multicast group (`ping 224.0.0.1 -I vmbr1`); fix /etc/hosts entries; confirm identical `/etc/pve/corosync.conf` network stanza after join |
| **`dkms status` empty after install** | Installer run without `--dkms` | Re‑execute runfile: `./NVIDIA-Linux-…run --dkms` |
| **Package signature errors on `apt update`** | Subscription expired or wrong key uploaded | Renew license in Proxmox shop → **Reissue**, upload new key in GUI |

---

*End of Document*
