# Toolbox

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
