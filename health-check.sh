#!/usr/bin/env bash
# Linux Health Check Script
# This script checks various aspects of system health and reports warnings when thresholds are exceeded

# ANSI color codes for output formatting
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Print section header
print_header() {
    echo -e "\n${GREEN}=== $1 ===${NC}"
}

# Print warning
print_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}"
}

# Print error
print_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get number of CPU cores
get_cpu_cores() {
    grep -c ^processor /proc/cpuinfo
}

# Check file system usage
check_filesystem() {
    print_header "File System Usage"
    
    # Check available space and inodes
    df -h | grep -v "tmpfs\|devtmpfs\|snap\|udev" | awk 'NR==1 {next} {printf "%-25s %-8s %-s\n", $1, $5, $6}'
    
    # Find file systems with less than 10% space remaining
    problem_fs=$(df -h | grep -v "tmpfs\|devtmpfs\|snap" | awk 'NR>1 && int($5) > 90 {print $6}')
    
    # Find file systems with less than 10% inodes remaining
    problem_inodes=$(df -i | grep -v "tmpfs\|devtmpfs\|snap" | awk 'NR>1 && int($5) > 90 {print $6}')
    
    if [ -n "$problem_fs" ]; then
        for fs in $problem_fs; do
            print_warning "Less than 10% space remaining on $fs"
            echo "Three largest directories on $fs:"
            find "$fs" -type d -exec du -xsh {} \; 2>/dev/null | sort -hr | head -3
        done
    fi
    
    if [ -n "$problem_inodes" ]; then
        for fs in $problem_inodes; do
            print_warning "Less than 10% inodes remaining on $fs"
        done
    fi
}

# Check system load and memory usage
check_system_load() {
    print_header "System Load and Memory"
    
    # Get number of CPU cores
    cpu_cores=$(get_cpu_cores)
    
    # Get load averages
    load_1min=$(cat /proc/loadavg | awk '{print $1}')
    load_5min=$(cat /proc/loadavg | awk '{print $2}')
    load_15min=$(cat /proc/loadavg | awk '{print $3}')
    
    echo "Load average (1, 5, 15 min): $load_1min, $load_5min, $load_15min"
    
    # Check if load average exceeds 80% of CPU capacity
    # Calculate threshold without bc
    threshold=$(awk "BEGIN {print $cpu_cores * 0.8}")
    
    # Compare load average to threshold without bc
    if awk -v load="$load_1min" -v thresh="$threshold" 'BEGIN {exit !(load > thresh)}'; then
        print_warning "Load average exceeds 80% of CPU capacity (cores: $cpu_cores)"
    fi
    
    # Check memory usage
    if command_exists free; then
        total_mem=$(free -m | awk '/Mem:/ {print $2}')
        used_mem=$(free -m | awk '/Mem:/ {print $3}')
        mem_percent=$(( used_mem * 100 / total_mem ))
        
        echo "Memory usage: ${mem_percent}% ($used_mem MB used out of $total_mem MB)"
        
        if [ "$mem_percent" -gt 80 ]; then
            print_warning "Memory usage exceeds 80% capacity"
        fi
    else
        echo "Memory usage: Unable to determine (free command not found)"
    fi
}

# Check for processes in uninterruptible sleep state
check_processes_D_state() {
    print_header "Processes in D State (Uninterruptible Sleep)"
    
    d_state_procs=$(ps -eo state,pid,cmd | grep "^D" | wc -l)
    
    if [ "$d_state_procs" -gt 0 ]; then
        print_warning "Found $d_state_procs processes in uninterruptible sleep (D) state"
        echo "Details of processes in D state:"
        ps -eo state,pid,cmd | grep "^D"
    else
        echo "No processes in uninterruptible sleep (D) state"
    fi
}

# Check SELinux status
check_selinux() {
    print_header "SELinux Status"

    if command_exists getenforce; then
        selinux_status=$(getenforce)
        echo "SELinux is $selinux_status"
        if [ "$selinux_status" != "Enforcing" ]; then
            print_warning "SELinux is not enforcing"
        fi
    elif [ -f /etc/selinux/config ]; then
        selinux_status=$(grep -i '^SELINUX=' /etc/selinux/config | cut -d'=' -f2)
        echo "SELinux configuration: $selinux_status"
        if [ "$selinux_status" != "enforcing" ]; then
            print_warning "SELinux is not enforcing"
        fi
    else
        echo "SELinux not present on this system"
    fi
}

# Check Firewall status
check_firewall() {
    print_header "Firewall Status"

    if command_exists firewall-cmd; then
        # firewalld detected (common on Red Hat family)
        fw_state=$(firewall-cmd --state 2>/dev/null)
        if [ $? -eq 0 ]; then
            echo "firewalld state: $fw_state"
            if [ "$fw_state" != "running" ]; then
                print_warning "firewalld is not running"
            fi
        else
            print_warning "firewalld service is inactive"
        fi

    elif command_exists ufw; then
        # UFW detected (common on Ubuntu)
        fw_state=$(ufw status 2>/dev/null | head -n1)
        echo "$fw_state"
        if echo "$fw_state" | grep -qi "inactive"; then
            print_warning "UFW firewall is inactive"
        fi

    elif command_exists nft && systemctl list-unit-files | grep -q '^nftables\.service'; then
        # nftables detected
        if systemctl is-active --quiet nftables; then
            echo "nftables service is active"
        else
            print_warning "nftables service is inactive"
        fi

    elif command_exists iptables; then
        # Fallback to iptables
        rules=$(iptables -S 2>/dev/null | wc -l)
        echo "iptables rules configured: $rules"
        if [ "$rules" -eq 0 ]; then
            print_warning "iptables has no active rules"
        fi

    else
        echo "No recognized firewall service detected"
    fi
}
check_updates() {
    print_header "Available Updates"
    
    # Check for Debian/Ubuntu based systems
    if command_exists apt-get; then
        if ! command_exists apt-get; then
            echo "apt-get not found or not executable"
            return
        fi
        
        # Update package lists
        echo "Checking for updates on Debian/Ubuntu based system..."
        apt_update_output=$(apt-get update 2>&1)
        
        # Count available updates
        updates_count=$(apt-get --simulate upgrade 2>&1 | grep -c '^Inst')
        security_count=$(apt-get --simulate upgrade 2>&1 | grep -c '^Inst.*security')
        
        echo "Available updates: $updates_count (including $security_count security updates)"
        
        if [ "$updates_count" -gt 0 ]; then
            print_warning "System has $updates_count updates available"
        fi
    
    # Check for Red Hat based systems
    elif command_exists yum; then
        echo "Checking for updates on Red Hat based system..."
        updates_count=$(yum check-update --quiet | grep -v "^$" | wc -l)
        
        # Subtract 1 for the header line if there are any updates
        if [ "$updates_count" -gt 0 ]; then
            updates_count=$((updates_count - 1))
        fi
        
        echo "Available updates: $updates_count"
        
        if [ "$updates_count" -gt 0 ]; then
            print_warning "System has $updates_count updates available"
        fi
    
    # Check for DNF (newer Red Hat systems)
    elif command_exists dnf; then
        echo "Checking for updates on Red Hat based system (using DNF)..."
        updates_count=$(dnf check-update --quiet | grep -v "^$" | wc -l)
        
        # Subtract 1 for the header line if there are any updates
        if [ "$updates_count" -gt 0 ]; then
            updates_count=$((updates_count - 1))
        fi
        
        echo "Available updates: $updates_count"
        
        if [ "$updates_count" -gt 0 ]; then
            print_warning "System has $updates_count updates available"
        fi
    
    else
        echo "Unable to determine package manager for updates check"
    fi
}

# Check if system requires a reboot
check_reboot_required() {
    print_header "Reboot Required Check"
    
    # Debian/Ubuntu specific
    if [ -f /var/run/reboot-required ]; then
        print_warning "System requires a reboot"
    elif [ -f /var/run/reboot-required.pkgs ]; then
        pkgs=$(cat /var/run/reboot-required.pkgs | wc -l)
        print_warning "System requires a reboot due to package updates ($pkgs packages)"
    # RHEL/CentOS specific
    elif command_exists needs-restarting && needs-restarting -r >/dev/null 2>&1; then
        if [ $? -eq 1 ]; then
            print_warning "System requires a reboot according to needs-restarting"
        else
            echo "No reboot required"
        fi
    # Check for kernel updates
    elif [ -d /boot ]; then
        running_kernel=$(uname -r)
        newest_kernel=$(ls -t /boot/vmlinuz-* 2>/dev/null | head -n1 | sed 's/\/boot\/vmlinuz-//')
        
        if [ "$running_kernel" != "$newest_kernel" ] && [ -n "$newest_kernel" ]; then
            print_warning "System is running kernel $running_kernel but kernel $newest_kernel is available"
        else
            echo "No reboot required (running latest kernel)"
        fi
    else
        echo "Unable to determine if reboot is required"
    fi
}

# Display system uptime
check_uptime() {
    print_header "System Uptime"
    uptime=$(uptime -p 2>/dev/null || uptime)
    echo "$uptime"
}

# Main function
main() {
    echo -e "${GREEN}Linux Health Check - $(date)${NC}"
    echo -e "${GREEN}Hostname: $(hostname)${NC}"
    
    # Run all checks
    check_filesystem
    check_system_load
    check_processes_D_state
    check_selinux
    check_firewall
    check_updates
    check_reboot_required
    check_uptime
    
    print_header "Health Check Complete"
}

# Run the main function
main