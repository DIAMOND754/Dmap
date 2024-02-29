#!/bin/bash

# Colors :D
RESET='\033[0m'       # Reset text style to default
BOLD_GREEN='\033[1;32m'   # Bold Green
BOLD_CYAN='\033[1;36m'    # Bold Cyan
BOLD_RED='\033[1;31m'     # Bold Red
BOLD_MAGENTA='\033[1;35m' # Bold Magenta

# Function to display script usage
usage() {
    echo -e "${BOLD_MAGENTA}<${RESET}${BOLD_GREEN}Info${RESET}${BOLD_MAGENTA}>${RESET} Usage: $0 -a <ip_address> [-s <min_rate>] [-A]" >&2
    exit 1
}

# Check if there are at least 2 arguments
if [ $# -lt 2 ]; then
    usage
elif [ $# -gt 6 ]; then
    usage
fi

# Parse command line arguments
while getopts ":a:s:A" opt; do
    case $opt in
        a)
            ip_address=$OPTARG
            ;;
        s)
            min_rate=$OPTARG
            ;;
        A)
            A_option=true
            ;;
        \?)
            echo -e "${BOLD_MAGENTA}<${RESET}${BOLD_RED}Warning${RESET}${BOLD_MAGENTA}>${RESET} Invalid option: -$OPTARG" >&2
            usage
            ;;
        :)
            echo -e "${BOLD_MAGENTA}<${RESET}${BOLD_RED}Warning${RESET}${BOLD_MAGENTA}>${RESET} Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# If -s option is not provided, use default min_rate value
if [ -z "$min_rate" ]; then
    min_rate=500
fi

#Quality
echo -e "${BOLD_MAGENTA}<${RESET}${BOLD_GREEN}Info${RESET}${BOLD_MAGENTA}>${RESET} Probing Ports"
echo ""

# Run nmap command and use a process substitution to parse output in real-time (Getting ports)
while read -r line; do
    # Parse each line of output to extract discovered open ports
    if [[ $line =~ ^Discovered\ open\ port\ ([0-9]+)/[a-z]+ ]]; then
        port=${BASH_REMATCH[1]}
        # Add the port to the array if it's not already present
        if [[ ! " ${open_ports[@]} " =~ " $port " ]]; then
            open_ports+=("$port")
            echo -e "${BOLD_MAGENTA}<${RESET}${BOLD_GREEN}Info${RESET}${BOLD_MAGENTA}>${RESET} Open port: $port"
        fi
    fi
done < <(sudo nmap -p- -T4 -v --min-rate "$min_rate" "$ip_address")

# Construct a comma-separated list of open ports
open_ports_list=$(IFS=,; echo "${open_ports[*]}")

#Quality
echo ""
echo -e "${BOLD_MAGENTA}<${RESET}${BOLD_GREEN}Info${RESET}${BOLD_MAGENTA}>${RESET} Scanning Ports"

# Variable
below_scan_report=false
needToCheck=true

# Run nmap command and use a process substitution to parse output in real-time (Script,Version and Tracerout scanning)
while read -r line; do

    if [[ $line =~ ^Nmap\ scan\ report\ for ]]; then
        below_scan_report=true
        needToCheck=false
        echo ""
        echo -e "\t\t\t\t\t\t\t${BOLD_CYAN}Finished Scan${RESET}"
        echo ""
        sleep 1.2
        echo $line
    elif $below_scan_report; then
        echo $line
    fi

    if $needToCheck; then
        if [[ $line == *"Initiating Service scan"* ]]; then
            echo -e " ${BOLD_MAGENTA}<${RESET}${BOLD_GREEN}Info${RESET}${BOLD_MAGENTA}>${RESET} Started Service Scan"
        elif [[ $line == *"Service scan Timing: "* ]]; then
            timing_info=$(echo "$line" | sed 's/.*{\(.*\) remaining}.*/\1/')
            echo -e " ${BOLD_MAGENTA}<${RESET}${BOLD_GREEN}Info${RESET}${BOLD_MAGENTA}>${RESET} $timing_info"
        elif [[ $line == *"Completed Service scan"* ]]; then
            echo -e " ${BOLD_MAGENTA}<${RESET}${BOLD_GREEN}Info${RESET}${BOLD_MAGENTA}>${RESET} Finished Service Scan"
        elif [[ $line == *"NSE: Script scanning"* ]]; then
            echo -e " ${BOLD_MAGENTA}<${RESET}${BOLD_GREEN}Info${RESET}${BOLD_MAGENTA}>${RESET} Started Script Scanning"
        fi
    fi

done < <(sudo nmap -p"$open_ports_list" -sS -sV -sC -T4 -v --min-rate 500 --traceroute "$ip_address" ${A_option:+-A} 2>/dev/null)

