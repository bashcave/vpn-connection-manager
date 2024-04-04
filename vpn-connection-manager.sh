#!/bin/bash

# VPN Connection Manager
# Manages Multiple VPN connections by measuring latency, ensuring the best connection is always active.
#
# @author BASHCAVE
# @version 1.0.0
# @license MIT

declare -a vpn_services=("vpn1.service" "vpn2.service" "vpn3.service") # List your VPN service names
log_file="vpn_manager_latency.log"
test_host="8.8.8.8"

measure_latency() {
    local vpn_service=$1
    systemctl start "$vpn_service"
    sleep 5 # Wait for the VPN to potentially establish a connection
    if systemctl is-active --quiet "$vpn_service"; then
        # Measure the latency
        local latency=$(ping -c 4 $test_host | tail -1 | awk '{print $(NF-1)}' | cut -d '/' -f 2)
        echo "$latency"
        systemctl stop "$vpn_service"
    else
        echo "9999" # Return a high latency value if the service didn't start
    fi
}

select_best_vpn() {
    local best_latency=9999
    local best_vpn=""
    for vpn_service in "${vpn_services[@]}"; do
        echo "$(date): Measuring latency for $vpn_service..." >> "$log_file"
        local latency=$(measure_latency "$vpn_service")
        echo "$(date): Latency for $vpn_service: $latency ms" >> "$log_file"
        if (( $(echo "$latency < $best_latency" | bc -l) )); then
            best_latency=$latency
            best_vpn=$vpn_service
        fi
    done
    if [ "$best_vpn" != "" ]; then
        echo "$(date): Best VPN based on latency: $best_vpn ($best_latency ms). Connecting..." >> "$log_file"
        systemctl start "$best_vpn"
        if systemctl is-active --quiet "$best_vpn"; then
            echo "$(date): Connected successfully to $best_vpn." >> "$log_file"
            return 0
        else
            echo "$(date): Failed to connect to $best_vpn." >> "$log_file"
            return 1
        fi
    else
        echo "$(date): Unable to determine the best VPN service. All services failed latency check." >> "$log_file"
        return 1
    fi
}

# Main logic
echo "Starting VPN Connection Manager with Latency Check..."
if select_best_vpn; then
    echo "Successfully connected to the best VPN service based on latency."
else
    echo "Failed to connect to any VPN service."
fi
