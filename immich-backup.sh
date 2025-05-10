#!/bin/bash

# Backup script for Immich Docker containers on BTRFS
# Created: May 10, 2025

# Constants
COMPOSE_FILE="/boot/config/plugins/compose.manager/projects/immich/docker-compose.yml"
SOURCE_VOLUME="/mnt/ftldrive/immich-database"
SNAPSHOT_NAME="immich-database-daily-$(date +%Y%m%d-%H%M%S)"
SNAPSHOT_PATH="/mnt/ftldrive/.snapshots/${SNAPSHOT_NAME}"
BACKUP_DIR="/mnt/zpool/backups/immich-database"
LOG_FILE="/mnt/zpool/backups/immich-backup-$(date +%Y%m%d).log"

# Function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to handle errors
handle_error() {
  log_message "ERROR: $1"
  log_message "Backup failed!"
  exit 1
}

# Ensure required directories exist
mkdir -p "$(dirname "$LOG_FILE")" || handle_error "Failed to create log directory"
mkdir -p "$(dirname "$SNAPSHOT_PATH")" || handle_error "Failed to create snapshot directory"

# Check for required commands
for cmd in docker-compose btrfs rsync; do
  if ! command -v $cmd &> /dev/null; then
    handle_error "Required command not found: $cmd"
  fi
done

# Check if source volume exists
if [ ! -d "$SOURCE_VOLUME" ]; then
  handle_error "Source volume not found: $SOURCE_VOLUME"
fi

# Check if source is a BTRFS subvolume
if ! btrfs subvolume show "$SOURCE_VOLUME" &> /dev/null; then
  handle_error "Source is not a BTRFS subvolume: $SOURCE_VOLUME"
fi

# Start backup process
log_message "Starting Immich backup process"

# Step 1: Stop Docker containers
log_message "Stopping Docker containers"
docker-compose -f "$COMPOSE_FILE" down || handle_error "Failed to stop Docker containers"

# Step 2: Create BTRFS snapshot labeled as daily backup
log_message "Creating BTRFS snapshot of $SOURCE_VOLUME"
btrfs subvolume snapshot -r "$SOURCE_VOLUME" "$SNAPSHOT_PATH" || handle_error "Failed to create BTRFS snapshot"

# Step 3: Start Docker containers
log_message "Starting Docker containers"
docker-compose -f "$COMPOSE_FILE" up -d || handle_error "Failed to start Docker containers"

# Step 4: Backup data using rsync - directly from snapshot (no mount needed)
log_message "Backing up data using rsync"
mkdir -p "$BACKUP_DIR" || handle_error "Failed to create backup directory"
rsync -avzAX --delete "$SNAPSHOT_PATH/" "$BACKUP_DIR/" || handle_error "Failed to rsync data"

# Step 5: Cleanup - remove snapshot
log_message "Removing snapshot"
btrfs subvolume delete "$SNAPSHOT_PATH" || handle_error "Failed to remove snapshot"

# Step 6: Finalize backup
log_message "Backup completed successfully!"
exit 0
