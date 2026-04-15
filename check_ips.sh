#!/bin/bash

# Enforce root privileges since masscan requires them
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: Please run this script as root (use sudo)."
    exit 1
fi

# Check arguments
if [[ $# -ne 1 ]] || [[ ! -f "$1" ]]; then
    echo "Usage: $0 <cidr_list_file>"
    exit 1
fi

# Check if masscan is installed
if ! command -v masscan &>/dev/null; then
    echo "Error: masscan is not installed."
    exit 1
fi

input_file="$1"
masscan_out=$(mktemp)
reachable_ips=$(mktemp)
clean_cidrs=$(mktemp)
export output="result.csv"
export tmp_output=$(mktemp) # Temp file for parallel workers to write un-sorted data

# Step 0: Clean up input file properly
awk '/^[^#]/ {print $1}' "$input_file" | tr -d '\r' > "$clean_cidrs"

if [[ ! -s "$clean_cidrs" ]]; then
    echo "No valid CIDRs found in input file."
    rm -f "$clean_cidrs" "$masscan_out" "$reachable_ips" "$tmp_output"
    exit 1
fi

# Step 1: Run masscan on both port 80 (HTTP) and 443 (HTTPS)
echo "[*] Running masscan on ports 80 and 443..."
masscan -iL "$clean_cidrs" -p80,443 --rate=1000 -oL "$masscan_out"

# Step 2: Extract unique IPs that have either port open
grep '^open' "$masscan_out" | awk '{print $4}' | sort -u > "$reachable_ips"

total=$(wc -l < "$reachable_ips")
echo "[*] Found $total hosts with port 80 or 443 open."

# Stop execution if no IPs were found
if [[ "$total" -eq 0 ]]; then
    echo "[-] No hosts found. Check the masscan output above for any errors."
    rm -f "$clean_cidrs" "$masscan_out" "$reachable_ips" "$tmp_output"
    exit 0
fi

echo "[*] Starting HTTP and HTTPS checks with 50 parallel workers..."

# Step 3: Define the worker function for parallel execution
check_single_ip() {
    local ip=$1
    
    # Check HTTP (port 80) and get latency
    local http_out
    http_out=$(curl -s -o /dev/null -w "%{http_code},%{time_total}" --connect-timeout 3 --max-time 5 "http://${ip}")
    [[ -z "$http_out" ]] && http_out="000,999"
    local http_code="${http_out%%,*}"
    local http_time="${http_out##*,}"
    
    # Check HTTPS (port 443) and get latency
    local https_out
    https_out=$(curl -sk -o /dev/null -w "%{http_code},%{time_total}" --connect-timeout 3 --max-time 5 "https://${ip}")
    [[ -z "$https_out" ]] && https_out="000,999"
    local https_code="${https_out%%,*}"
    local https_time="${https_out##*,}"
    
    # Highlight if either protocol returns 403
    if [[ "$http_code" == "403" ]] || [[ "$https_code" == "403" ]]; then
        # Determine the best latency
        local best_lat="999"
        
        if [[ "$http_code" == "403" ]]; then
            best_lat=$http_time
        fi
        
        if [[ "$https_code" == "403" ]]; then
            if [[ "$best_lat" == "999" ]]; then
                best_lat=$https_time
            else
                # Find the minimum latency using awk
                best_lat=$(awk -v t1="$best_lat" -v t2="$https_time" 'BEGIN{print (t1<t2)?t1:t2}')
            fi
        fi

        # Append to tmp CSV file (ip,latency)
        echo "${ip},${best_lat}" >> "$tmp_output"
        echo "    [+] [403] Found target on $ip (HTTP: $http_code | HTTPS: $https_code) -> Latency: ${best_lat}s"
    else
        echo "    [*] Received HTTP: $http_code | HTTPS: $https_code from $ip"
    fi
}

# Export the function and the output variables so xargs can use them
export -f check_single_ip

# Step 4: Run the curl checks in parallel (Fixed xargs warning)
cat "$reachable_ips" | xargs -P 50 -I {} bash -c 'check_single_ip "$@"' _ {}

# Step 5: Sort the results based on latency and write ONLY IPs to final CSV
if [[ -s "$tmp_output" ]]; then
    # Sort by the second column (latency) numerically (-n), separated by comma (-t,)
    # Then use cut to extract only the first column (IP address)
    sort -t, -k2,2n "$tmp_output" | cut -d, -f1 > "$output"
else
    # Create empty file if no targets were found
    > "$output"
fi

# Clean up temp files
rm -f "$clean_cidrs" "$masscan_out" "$reachable_ips" "$tmp_output"
echo "[*] Done. Sorted IPs saved to $output"
