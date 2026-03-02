# GEMINI.md

## Directory Overview

This directory, "toolbox", contains a collection of shell scripts for server administration. These scripts are designed to perform health checks and backups.

## Key Files

*   `health-check.sh`: This script performs a health check on a Linux system. It checks file system usage, system load, memory usage, processes in an uninterruptible sleep state, zombie processes, top 5 processes by CPU and memory usage, SELinux status, firewall status, available updates, and whether a reboot is required. It is designed to be distro-agnostic, with the exception of package update checks, which work on Debian and Red Hat-based systems.

*   `immich-backup.sh`: This script is designed to back up an Immich Docker container's database on a BTRFS file system. It stops the Immich containers, creates a BTRFS snapshot, starts the containers again, and then backs up the data using `rsync`. It also includes cleanup of old snapshots and backups. This script is highly specific to a particular user's home server setup.

*   `README.md`: This file provides a brief overview of the scripts in this directory.

*   `LICENSE`: This file contains the license for the scripts in this directory.

## Usage

The scripts in this directory are intended to be run from the command line.

*   `health-check.sh`: This script can be run directly to perform a health check on the system. It is recommended to run this script with root privileges for accurate results.

*   `immich-backup.sh`: This script is intended to be run as a cron job or systemd timer to automate the backup of an Immich instance. It requires careful configuration of the variables at the top of the script to match the user's environment.