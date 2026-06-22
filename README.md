# sys_menu.ps1

A PowerCLI-based orchestration menu for automating the full lifecycle of the **Systems IQT course** lab environment in VMware vSphere. It lets administrators rapidly deploy, tear down, update, and operate up to 34 identical student suites using linked-clones, while enforcing strict Layer 2 network isolation through air-gapped distributed port groups and DRS affinity rules.

## Overview

The script presents an interactive, color-coded console menu that wraps common vCenter operations into guarded, confirmation-driven workflows. Each suite is a self-contained set of VMs (Active Directory, Exchange, endpoint management, NetApp, clients, etc.) isolated to its own folder, port group, and "keep together" DRS rule so students can't reach across into other suites or the production network.

## Requirements

- **PowerShell** 5.1 or later
- **VMware PowerCLI** (`Install-Module VMware.PowerCLI`)
- Network access to the target vCenter Server
- A vCenter account with sufficient privileges (folder/VM management, DRS rule edits, port group and permission assignment)
- For guest-facing tasks (file push, broadcast): valid guest OS credentials, VMware Tools installed on targets, and WinRM enabled where applicable

## Configuration

Edit the global variables near the top of the script to match your environment:

| Variable | Purpose |
|----------|---------|
| `$vCenterServer` | vCenter FQDN |
| `$datacenterName` | Target datacenter |
| `$clusterName` | Compute cluster |
| `$vdsName` | Distributed switch |
| `$targetDatastore` | Datastore for clones |
| `$masterFolder` | Golden master VM folder |
| `$templatePrefix` | Regex for templates to preserve during teardown |
| `$adDomain` | AD domain for RBAC assignment |

The `$globalVmMapping` hashtable defines which master VMs belong to each functional sub-folder (Apps, Clients, Core, EndPoint, EXCH, Network). Update this to reflect your VM naming scheme.

## Usage

Run the script from a machine with PowerCLI installed:

```powershell
.\sys_menu.ps1
```

It connects to vCenter, disables web operation timeouts, and presents the main menu. **All actions require explicit confirmation before executing.**

### Main Menu

| Option | Action |
|--------|--------|
| `1` | Take new foundational snapshots of the Golden Master VMs (auto-incremented `Golden-Base-NN`) |
| `2` | Teardown — power off and delete student VMs, clear old DRS rules (templates preserved) |
| `3` | Deploy linked-clones from a chosen snapshot and apply "Keep Together" affinity rules |
| `4` | Staggered power-on in three waves (AD → SQL/License → clients) to mitigate boot storms |
| `5` | One-Time Setup sub-menu |
| `6` | Instructor Scripts sub-menu |
| `R` | Refresh / re-authenticate the vCenter connection |
| `D` | Admin Debug sub-menu |
| `Q` | Quit and disconnect |

### One-Time Setup (Menu 5)

> **Warning:** These scripts alter cluster infrastructure.

- **Build Logical Boundaries** — creates suite VM folders and isolated, hardened air-gapped port groups (unused uplinks, promiscuous/MAC-change/forged-transmit disabled).
- **Assign Folder Permissions** — applies RBAC, binding AD student accounts to their respective suite folders and port groups while denying cross-suite visibility.

### Instructor Scripts (Menu 6)

- Reset NetApp training VMs from the `PE_ready_netapp` snapshot
- Integrate student-created `SDC-02v-##` VMs into the suite's port group and DRS rule
- Pull the latest version of `sys_menu.ps1` to admin workstations
- Take a snapshot of all student suite VMs *(WIP)*
- Push a file from `C:\.scripts\transfer` to a VM's `C:\temp`
- Pull a file from a VM *(WIP)*
- Broadcast a pop-up message to student workstations via WinRM

### Debug (Menu D)

- **Audit Isolation** — checks each suite for network, DRS membership, and host-placement compliance, with optional auto-remediation of failed suites.

## Suite Targeting

Most operations prompt for a scope: a single suite, a range (e.g. `1-5`), or all suites. Inputs are validated against the supported range.

## Author

Masen Calhoun

## Notes

- This script performs destructive operations (VM deletion, infrastructure changes). Review the targeted scope at each confirmation prompt before proceeding.
- Items marked *WIP* are placeholders and not yet implemented.