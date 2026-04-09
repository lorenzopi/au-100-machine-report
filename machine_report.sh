#!/bin/bash
# AU-100 Machine Report (macOS edition)
# Derived from TR-100 Machine Report by U.S. Graphics, LLC.
# Copyright (c) 2024, U.S. Graphics, LLC. BSD-3-Clause License.

# Global variables
MIN_NAME_LEN=5
MAX_NAME_LEN=13
MAX_DATA_LEN=32
BORDERS_AND_PADDING=7

# Basic configuration
report_title="ABSOLUTE UNIT RESEARCH"
last_login_ip_present=0
last_login_ip=""

# Optional features
ENABLE_PUBLIC_IP=0
PUBLIC_IP_TIMEOUT=2

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

max_length() {
    local max_len=0
    local len

    for str in "$@"; do
        len=${#str}
        if (( len > max_len )); then
            max_len=$len
        fi
    done

    if [ "$max_len" -lt "$MAX_DATA_LEN" ]; then
        printf '%s' "$max_len"
    else
        printf '%s' "$MAX_DATA_LEN"
    fi
}

set_current_len() {
    CURRENT_LEN=$(max_length                                  \
        "$report_title"                                      \
        "$os_name"                                           \
        "$os_kernel"                                         \
        "$macos_full_version"                                \
        "$model_name"                                        \
        "$model_identifier"                                  \
        "$chip_name"                                         \
        "$core_display"                                      \
        "$memory_total_text"                                 \
        "$serial_number"                                     \
        "$net_hostname"                                      \
        "$net_machine_ip"                                    \
        "$net_client_ip"                                     \
        "$net_interface"                                     \
        "$net_public_ip"                                     \
        "$net_current_user"                                  \
        "$cpu_1min_bar_graph"                                \
        "$cpu_5min_bar_graph"                                \
        "$cpu_15min_bar_graph"                               \
        "$root_used_gb/$root_total_gb GB [$disk_percent%]"   \
        "$disk_bar_graph"                                    \
        "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]" \
        "${mem_bar_graph}"                                   \
        "$battery_status"                                    \
        "$vpn_status"                                        \
        "$security_status"                                   \
        "$last_login_time"                                   \
        "$last_login_ip"                                     \
        "$sys_uptime"                                        \
    )
}

PRINT_HEADER() {
    local length=$((CURRENT_LEN+MAX_NAME_LEN+BORDERS_AND_PADDING))

    local top="┌"
    local bottom="├"
    for (( i = 0; i < length - 2; i++ )); do
        top+="─"
        bottom+="─"
    done
    top+="┐"
    bottom+="┤"

    printf '%s\n' "$top"
    printf '%s\n' "$bottom"
}

PRINT_CENTERED_DATA() {
    local max_len=$((CURRENT_LEN+MAX_NAME_LEN-BORDERS_AND_PADDING))
    local text="$1"
    local total_width=$((max_len + 12))

    local text_len=${#text}
    local padding_left=$(( (total_width - text_len) / 2 ))
    local padding_right=$(( total_width - text_len - padding_left ))

    printf "│%${padding_left}s%s%${padding_right}s│\n" "" "$text" ""
}

PRINT_DIVIDER() {
    local side="$1"
    case "$side" in
        "top")
            local left_symbol="├"
            local middle_symbol="┬"
            local right_symbol="┤"
            ;;
        "bottom")
            local left_symbol="└"
            local middle_symbol="┴"
            local right_symbol="┘"
            ;;
        *)
            local left_symbol="├"
            local middle_symbol="┼"
            local right_symbol="┤"
    esac

    local length=$((CURRENT_LEN+MAX_NAME_LEN+BORDERS_AND_PADDING))
    local divider="$left_symbol"
    for (( i = 0; i < length - 3; i++ )); do
        divider+="─"
        if [ "$i" -eq 14 ]; then
            divider+="$middle_symbol"
        fi
    done
    divider+="$right_symbol"
    printf '%s\n' "$divider"
}

PRINT_DATA() {
    local name="$1"
    local data="$2"
    local max_data_len=$CURRENT_LEN

    local name_len=${#name}
    if (( name_len < MIN_NAME_LEN )); then
        name=$(printf "%-${MIN_NAME_LEN}s" "$name")
    elif (( name_len > MAX_NAME_LEN )); then
        name=$(echo "$name" | cut -c 1-$((MAX_NAME_LEN-3)))...
    else
        name=$(printf "%-${MAX_NAME_LEN}s" "$name")
    fi

    local data_len=${#data}
    if (( data_len > max_data_len )); then
        if (( max_data_len > 3 )); then
            data=$(echo "$data" | cut -c 1-$((max_data_len-3)))...
        else
            data=$(echo "$data" | cut -c 1-"$max_data_len")
        fi
    else
        data=$(printf "%-${max_data_len}s" "$data")
    fi

    printf "│ %-${MAX_NAME_LEN}s │ %s │\n" "$name" "$data"
}

bar_graph() {
    local percent
    local num_blocks
    local width=$CURRENT_LEN
    local graph=""
    local used=$1
    local total=$2

    if (( total == 0 )); then
        percent=0
    else
        percent=$(awk -v used="$used" -v total="$total" 'BEGIN { printf "%.2f", (used / total) * 100 }')
    fi

    num_blocks=$(awk -v percent="$percent" -v width="$width" 'BEGIN { printf "%d", (percent / 100) * width }')
    if (( num_blocks > width )); then
        num_blocks=$width
    fi
    if (( num_blocks < 0 )); then
        num_blocks=0
    fi

    for (( i = 0; i < num_blocks; i++ )); do
        graph+="█"
    done
    for (( i = num_blocks; i < width; i++ )); do
        graph+="░"
    done
    printf "%s" "$graph"
}

get_ip_addr() {
    local ipv4_address
    local ipv6_address

    ipv4_address=$(ifconfig 2>/dev/null | awk '
        /^[a-z0-9]/ {iface=$1; sub(":$", "", iface)}
        iface !~ /^lo/ && iface !~ /^utun/ && iface !~ /^awdl/ && /inet / && !found_ipv4 {found_ipv4=1; print $2}')

    if [ -n "$ipv4_address" ]; then
        printf '%s' "$ipv4_address"
        return
    fi

    ipv6_address=$(ifconfig 2>/dev/null | awk '
        /^[a-z0-9]/ {iface=$1; sub(":$", "", iface)}
        iface !~ /^lo/ && iface !~ /^utun/ && iface !~ /^awdl/ && /inet6 / && !found_ipv6 {found_ipv6=1; print $2}')

    if [ -n "$ipv6_address" ]; then
        printf '%s' "$ipv6_address"
    else
        printf '%s' "No IP found"
    fi
}

get_default_iface() {
    local iface

    iface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2; exit}')
    if [ -n "$iface" ]; then
        printf '%s' "$iface"
        return
    fi

    iface=$(ifconfig 2>/dev/null | awk '
        /^[a-z0-9].*flags=/ {gsub(":", "", $1); cur=$1}
        /status: active/ && cur !~ /^(lo|gif|stf|anpi|utun|awdl|llw)/ {print cur; exit}
    ')

    if [ -n "$iface" ]; then
        printf '%s' "$iface"
    else
        printf '%s' "Unavailable"
    fi
}

get_public_ip() {
    if [ "$ENABLE_PUBLIC_IP" -ne 1 ]; then
        printf '%s' "Disabled"
        return
    fi

    if command_exists curl; then
        local pip
        pip=$(curl -4 -fsS --max-time "$PUBLIC_IP_TIMEOUT" https://api.ipify.org 2>/dev/null)
        if [ -z "$pip" ]; then
            pip=$(curl -6 -fsS --max-time "$PUBLIC_IP_TIMEOUT" https://api64.ipify.org 2>/dev/null)
        fi
        if [ -n "$pip" ]; then
            printf '%s' "$pip"
            return
        fi
    fi

    printf '%s' "Unavailable"
}

# Apple hardware/software info
sp_all=$(system_profiler SPHardwareDataType SPSoftwareDataType 2>/dev/null)

model_name=""
model_identifier=""
chip_name=""
core_detail=""
memory_total_text=""
serial_number=""
macos_full_version=""
os_kernel=""
sip_status=""
secure_vm_status=""

while IFS='=' read -r key value; do
    case "$key" in
        model_name) model_name="$value" ;;
        model_identifier) model_identifier="$value" ;;
        chip_name) chip_name="$value" ;;
        core_detail) core_detail="$value" ;;
        memory_total_text) memory_total_text="$value" ;;
        serial_number) serial_number="$value" ;;
        macos_full_version) macos_full_version="$value" ;;
        os_kernel) os_kernel="$value" ;;
        sip_status) sip_status="$value" ;;
        secure_vm_status) secure_vm_status="$value" ;;
    esac
done < <(
    printf '%s\n' "$sp_all" | awk -F': ' '
        $1 ~ /Model Name$/ {print "model_name=" $2; next}
        $1 ~ /Model Identifier$/ {print "model_identifier=" $2; next}
        $1 ~ /Chip$/ {print "chip_name=" $2; next}
        $1 ~ /Total Number of Cores$/ {print "core_detail=" $2; next}
        $1 ~ /^[[:space:]]*Memory$/ {print "memory_total_text=" $2; next}
        $1 ~ /Serial Number \(system\)$/ {print "serial_number=" $2; next}
        $1 ~ /System Version$/ {print "macos_full_version=" $2; next}
        $1 ~ /Kernel Version$/ {print "os_kernel=" $2; next}
        $1 ~ /System Integrity Protection$/ {print "sip_status=" $2; next}
        $1 ~ /Secure Virtual Memory$/ {print "secure_vm_status=" $2; next}
    '
)

# Fallbacks
if [ -z "$model_name" ]; then model_name="Mac"; fi
if [ -z "$model_identifier" ]; then model_identifier="Unavailable"; fi
if [ -z "$chip_name" ]; then chip_name="Unavailable"; fi
if [ -z "$core_detail" ]; then core_detail="Unavailable"; fi
if [ -z "$memory_total_text" ]; then memory_total_text="Unavailable"; fi
if [ -z "$serial_number" ]; then serial_number="Unavailable"; fi
if [ -z "$macos_full_version" ]; then macos_full_version="$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"; fi
if [ -z "$os_kernel" ]; then os_kernel="Darwin $(uname -r)"; fi
if [ -z "$sip_status" ]; then sip_status="Unavailable"; fi
if [ -z "$secure_vm_status" ]; then secure_vm_status="Unavailable"; fi

os_name="macOS"
core_count=$(printf '%s\n' "$core_detail" | awk '{print $1}')
if printf '%s' "$core_count" | grep -Eq '^[0-9]+$'; then
    core_display="${core_count}-core"
else
    core_display="$core_detail"
fi

# Network info
net_current_user=$(whoami)
net_hostname=$(hostname -f 2>/dev/null)
if [ -z "$net_hostname" ]; then
    net_hostname=$(hostname 2>/dev/null)
fi
if [ -z "$net_hostname" ]; then
    net_hostname="Not Defined"
fi

net_machine_ip=$(get_ip_addr)
net_client_ip=$(who am i 2>/dev/null | sed -nE 's/.*\(([^)]+)\).*/\1/p')
if [ -z "$net_client_ip" ]; then
    net_client_ip="Not connected"
fi
net_interface=$(get_default_iface)
net_public_ip=$(get_public_ip)

net_dns_ip=()
while IFS= read -r dns; do
    [ -n "$dns" ] && net_dns_ip+=("$dns")
done < <(scutil --dns 2>/dev/null | awk '/nameserver\[[0-9]+\]/ {print $3}' | awk '!seen[$0]++')

if [ "${#net_dns_ip[@]}" -eq 0 ] && [ -f /etc/resolv.conf ]; then
    while IFS= read -r dns; do
        [ -n "$dns" ] && net_dns_ip+=("$dns")
    done < <(grep '^nameserver ' /etc/resolv.conf | awk '{print $2}')
fi
if [ "${#net_dns_ip[@]}" -eq 0 ]; then
    net_dns_ip=("Unavailable")
fi
if [ "${#net_dns_ip[@]}" -gt 3 ]; then
    net_dns_ip=("${net_dns_ip[@]:0:3}")
fi

# Load and cores for graphs
cpu_cores=$(printf '%s\n' "$core_detail" | awk '{print $1}')
if [ -z "$cpu_cores" ] || ! printf '%s' "$cpu_cores" | awk '/^[0-9]+$/ {ok=1} END {exit !ok}'; then
    cpu_cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null)
fi
if [ -z "$cpu_cores" ]; then cpu_cores=1; fi

load_values=$(uptime 2>/dev/null | sed -E 's/.*load averages?: //; s/,//g')
load_avg_1min=$(printf '%s\n' "$load_values" | awk '{print $1}')
load_avg_5min=$(printf '%s\n' "$load_values" | awk '{print $2}')
load_avg_15min=$(printf '%s\n' "$load_values" | awk '{print $3}')
if [ -z "$load_avg_1min" ]; then load_avg_1min=0; fi
if [ -z "$load_avg_5min" ]; then load_avg_5min=0; fi
if [ -z "$load_avg_15min" ]; then load_avg_15min=0; fi

# Memory info (macOS vm_stat)
vm_stats=$(vm_stat 2>/dev/null)
page_size=$(printf '%s\n' "$vm_stats" | awk -F'page size of | bytes' 'NR==1 {print $2}')
pages_free=$(printf '%s\n' "$vm_stats" | awk '/Pages free/ {gsub("\\.","",$3); print $3}')
pages_active=$(printf '%s\n' "$vm_stats" | awk '/Pages active/ {gsub("\\.","",$3); print $3}')
pages_inactive=$(printf '%s\n' "$vm_stats" | awk '/Pages inactive/ {gsub("\\.","",$3); print $3}')
pages_speculative=$(printf '%s\n' "$vm_stats" | awk '/Pages speculative/ {gsub("\\.","",$3); print $3}')
pages_wired=$(printf '%s\n' "$vm_stats" | awk '/Pages wired down/ {gsub("\\.","",$4); print $4}')
pages_compressed=$(printf '%s\n' "$vm_stats" | awk '/Pages occupied by compressor/ {gsub("\\.","",$5); print $5}')

if [ -z "$page_size" ]; then page_size=4096; fi
if [ -z "$pages_free" ]; then pages_free=0; fi
if [ -z "$pages_active" ]; then pages_active=0; fi
if [ -z "$pages_inactive" ]; then pages_inactive=0; fi
if [ -z "$pages_speculative" ]; then pages_speculative=0; fi
if [ -z "$pages_wired" ]; then pages_wired=0; fi
if [ -z "$pages_compressed" ]; then pages_compressed=0; fi

total_pages=$((pages_free + pages_active + pages_inactive + pages_speculative + pages_wired + pages_compressed))
mem_total=$((total_pages * page_size))
mem_available=$(((pages_free + pages_speculative) * page_size))
mem_used=$((mem_total - mem_available))
if [ "$mem_used" -lt 0 ]; then mem_used=0; fi

mem_percent=$(awk -v used="$mem_used" -v total="$mem_total" 'BEGIN { if (total == 0) print "0.00"; else printf "%.2f", (used / total) * 100 }')
mem_total_gb=$(awk -v total="$mem_total" 'BEGIN { printf "%.2f", total / (1024 * 1024 * 1024) }')
mem_used_gb=$(awk -v used="$mem_used" 'BEGIN { printf "%.2f", used / (1024 * 1024 * 1024) }')

# Disk info (root volume)
root_partition="/"
root_used=$(df -k "$root_partition" 2>/dev/null | awk 'NR==2 {print $3}')
root_total=$(df -k "$root_partition" 2>/dev/null | awk 'NR==2 {print $2}')
if [ -z "$root_used" ]; then root_used=0; fi
if [ -z "$root_total" ]; then root_total=1; fi
root_total_gb=$(awk -v total="$root_total" 'BEGIN { printf "%.2f", total / (1024 * 1024) }')
root_used_gb=$(awk -v used="$root_used" 'BEGIN { printf "%.2f", used / (1024 * 1024) }')
disk_percent=$(awk -v used="$root_used" -v total="$root_total" 'BEGIN { if (total==0) print "0.00"; else printf "%.2f", (used / total) * 100 }')

# Battery
battery_status="Unavailable"
if command_exists pmset; then
    battery_status=$(pmset -g batt 2>/dev/null | awk -F'; *' 'NR==2 {pct=$1; sub(/^.*\t/, "", pct); gsub(/^ +/, "", pct); state=$2; gsub(/^ +/, "", state); print pct " " state; exit}')
    if [ -z "$battery_status" ]; then
        battery_status="AC/no battery"
    fi
fi

# Temperature (optional; hidden if unavailable)
temp_fan_status=""
if command_exists istats; then
    temp_fan_status=$(istats cpu temp 2>/dev/null | awk -F': ' '/CPU temp/ {print $2; exit}')
elif command_exists powermetrics; then
    temp_fan_status=$(powermetrics --samplers smc -n 1 2>/dev/null | awk -F': ' '/CPU die temperature/ {print $2; exit}')
fi
if [ -z "$temp_fan_status" ] || [ "$temp_fan_status" = "Unavailable" ]; then
    temp_fan_status=""
fi

# VPN
vpn_status="Unavailable"
if command_exists tailscale; then
    ts_state=$(tailscale status --json 2>/dev/null | awk -F'"' '/"BackendState"/ {print $4; exit}')
    ts_ip=$(tailscale ip -4 2>/dev/null | head -n 1)
    if printf '%s' "$ts_ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        vpn_status="Connected $ts_ip"
    elif [ -n "$ts_state" ]; then
        vpn_status="$ts_state"
    else
        vpn_status="Unavailable"
    fi
fi

# Security
security_status="SIP:${sip_status} SVM:${secure_vm_status}"

# Last login
last_login=$(last -n 1 "$USER" 2>/dev/null | head -n 1)
if [ -z "$last_login" ] || echo "$last_login" | grep -q '^wtmp begins'; then
    last_login_time="Never logged in"
else
    last_login_source=$(echo "$last_login" | awk '{print $3}')
    if [[ "$last_login_source" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        last_login_ip_present=1
        last_login_ip="$last_login_source"
        last_login_time=$(echo "$last_login" | awk '{print $4, $5, $6, $7}')
    else
        last_login_time=$(echo "$last_login" | awk '{print $3, $4, $5, $6}')
    fi
    if [ -z "$last_login_time" ]; then
        last_login_time="Unavailable"
    fi
    if echo "$last_login" | grep -q 'still logged in'; then
        last_login_time="$last_login_time (active)"
    fi
fi

# Uptime
uptime_raw="$(uptime 2>/dev/null)"
if echo "$uptime_raw" | grep -q ' up '; then
    sys_uptime=$(printf '%s\n' "$uptime_raw" | sed -E 's/.* up //; s/, [0-9]+ users?.*//; s/, load averages?:.*//')
else
    boot_line="$(who -b 2>/dev/null)"
    if [ -n "$boot_line" ]; then
        boot_month="$(printf '%s\n' "$boot_line" | awk '{print $3}')"
        boot_day="$(printf '%s\n' "$boot_line" | awk '{print $4}')"
        boot_time="$(printf '%s\n' "$boot_line" | awk '{print $5}')"
        current_year="$(date +%Y)"
        boot_epoch="$(date -j -f "%b %e %Y %H:%M" "$boot_month $boot_day $current_year $boot_time" +%s 2>/dev/null)"
        now_epoch="$(date +%s)"
        if [ -n "$boot_epoch" ]; then
            uptime_secs=$((now_epoch - boot_epoch))
            if [ "$uptime_secs" -lt 0 ]; then uptime_secs=0; fi
            up_days=$((uptime_secs / 86400))
            up_hours=$(((uptime_secs % 86400) / 3600))
            up_minutes=$(((uptime_secs % 3600) / 60))
            sys_uptime="${up_days}d ${up_hours}h ${up_minutes}m"
        else
            sys_uptime="Unavailable"
        fi
    else
        sys_uptime="Unavailable"
    fi
fi

# Width before graphs
set_current_len

# Graphs
cpu_1min_bar_graph=$(bar_graph "$load_avg_1min" "$cpu_cores")
cpu_5min_bar_graph=$(bar_graph "$load_avg_5min" "$cpu_cores")
cpu_15min_bar_graph=$(bar_graph "$load_avg_15min" "$cpu_cores")
mem_bar_graph=$(bar_graph "$mem_used" "$mem_total")
disk_bar_graph=$(bar_graph "$root_used" "$root_total")

# Render
PRINT_HEADER
PRINT_CENTERED_DATA "$report_title"
PRINT_CENTERED_DATA "AU-100 MACHINE REPORT"
PRINT_DIVIDER "top"
PRINT_DATA "OS" "$os_name"
PRINT_DATA "KERNEL" "$os_kernel"
PRINT_DATA "MACOS" "$macos_full_version"

PRINT_DIVIDER
PRINT_DATA "MODEL" "$model_name"
PRINT_DATA "MODEL ID" "$model_identifier"
PRINT_DATA "CHIP" "$chip_name"
PRINT_DATA "CORES" "$core_display"
PRINT_DATA "MEMORY" "$memory_total_text"
PRINT_DATA "SERIAL" "$serial_number"

PRINT_DIVIDER
PRINT_DATA "HOSTNAME" "$net_hostname"
PRINT_DATA "MACHINE IP" "$net_machine_ip"
PRINT_DATA "CLIENT  IP" "$net_client_ip"
PRINT_DATA "NET IFACE" "$net_interface"
PRINT_DATA "PUBLIC IP" "$net_public_ip"
for dns_num in "${!net_dns_ip[@]}"; do
    PRINT_DATA "DNS  IP $((dns_num + 1))" "${net_dns_ip[dns_num]}"
done
PRINT_DATA "USER" "$net_current_user"

PRINT_DIVIDER
PRINT_DATA "LOAD  1m" "$cpu_1min_bar_graph"
PRINT_DATA "LOAD  5m" "$cpu_5min_bar_graph"
PRINT_DATA "LOAD 15m" "$cpu_15min_bar_graph"
PRINT_DATA "VOLUME" "$root_used_gb/$root_total_gb GB [$disk_percent%]"
PRINT_DATA "DISK USAGE" "$disk_bar_graph"
PRINT_DATA "RAM USE" "${mem_used_gb}/${mem_total_gb} GiB [${mem_percent}%]"
PRINT_DATA "USAGE" "${mem_bar_graph}"
PRINT_DATA "BATT" "$battery_status"

PRINT_DIVIDER
if [ -n "$temp_fan_status" ]; then
    PRINT_DATA "TEMP/FAN" "$temp_fan_status"
fi
PRINT_DATA "VPN" "$vpn_status"
PRINT_DATA "SECURITY" "$security_status"

PRINT_DIVIDER
PRINT_DATA "LAST LOGIN" "$last_login_time"
if [ "$last_login_ip_present" -eq 1 ]; then
    PRINT_DATA "" "$last_login_ip"
fi
PRINT_DATA "UPTIME" "$sys_uptime"
PRINT_DIVIDER "bottom"
