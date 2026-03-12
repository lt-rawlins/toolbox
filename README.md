# Toolbox

## immich database backup

If you aren't running immich on a btrfs file system then this script is just a paper weight... and a bad one at that.

This is very specific to my home server. While I'm sure you can adapt it to your own needs, you'll want to carefully
read the contents of the script and ensure you've updated the variables that contain paths.



## Smart Folder
`smart-folder.sh`

Simulates macOS Smart Folders on Linux. Runs a `find` based on user-defined criteria and creates a directory of symlinks to all matching files — useful for tracking config files or logs that live outside their conventional locations (`/etc`, `/var/log`).

Requires bash 4+ and GNU find. Run with `sudo` for full filesystem visibility.

```
Usage: smart-folder.sh [OPTIONS]

Options:
  -n NAME     Smart folder name (required) — used as output dir name
  -t TYPE     Preset type: configs, logs (omit for custom extensions)
  -e EXTS     Comma-separated extensions without dot (e.g. conf,yaml,ini)
  -s PATH     Search root path (default: /)
  -m MINS     Match files modified within last N minutes
  -H HOURS    Match files modified within last N hours
  -d DAYS     Match files modified within last N days
  -o OUTPUT   Parent dir for output (default: ~/smart-folders)
  -x PATHS    Colon-separated additional paths to exclude
  -f          Force: clear existing smart folder first
  -r          Dry run: print matches, don't create anything
  -h          Show help
```

**Presets:**
- `configs` — searches for `.conf`, `.cfg`, `.ini`, `.yaml`, `.yml`, `.toml`, `.json`, `.env`
- `logs` — searches for `.log`, `.log.1`, `.log.2.gz`

Symlinks are named `<parent-dir>_<filename>` so each link carries its source context (e.g. `nginx_error.log`, `apache2_error.log`).

```bash
# Find all config files changed in the last 7 days
sudo ./smart-folder.sh -n recent-configs -t configs -d 7

# Find logs modified in the last 2 hours under /var
sudo ./smart-folder.sh -n fresh-logs -t logs -H 2 -s /var

# Preview matches without creating anything
sudo ./smart-folder.sh -n recent-configs -t configs -d 7 -r

# Custom extensions, limited to a specific directory
./smart-folder.sh -n yaml-files -e yaml,yml -d 30 -s ~/projects
```

## Health Check
`health-check.sh`

Should be mostly distro agnostic with the exception of package update checks which will only work on Debian and Red Hat based distros.


Example output of health-check.sh on Debian 12.10

```
Linux Health Check - Thu Apr 17 10:26:49 PM EDT 2025
Hostname: debian01

=== File System Usage ===
/dev/vda2                 7%       /
/dev/vda1                 2%       /boot/efi

=== System Load and Memory ===
Load average (1, 5, 15 min): 0.04, 0.04, 0.01
Memory usage: 9% (387 MB used out of 3909 MB)

=== Processes in D State (Uninterruptible Sleep) ===
No processes in uninterruptible sleep (D) state

=== SELinux Status ===
SELinux not present on this system

=== Firewall Status ===
WARNING: nftables service is inactive

=== Available Updates ===
Checking for updates on Debian/Ubuntu based system...
Available updates: 4 (including 4 security updates)
WARNING: System has 4 updates available

=== Reboot Required Check ===
No reboot required (running latest kernel)

=== System Uptime ===
up 4 hours, 36 minutes

=== Health Check Complete ===
```
