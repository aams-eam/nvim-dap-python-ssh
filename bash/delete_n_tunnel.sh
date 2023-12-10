#!/bin/bash

# Check if all required arguments are provided
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <username> <host> <port> <debug_host> <debug_port>"
    exit 1
fi

# Extracting arguments
username="$1"
host="$2"
port="$3"
debug_host="$4"
debug_port="$5"

# Define the pattern based on the provided arguments
# ssh -o StrictHostKeyChecking=no -fN -L 5678:127.0.0.1:5678 -l kali -p 30022 172.21.64.1
pattern="ssh -o StrictHostKeyChecking=no -fN -L $debug_port:$debug_host:$debug_port -l $username -p $port $host"

# Use pkill to find and delete the process
pkill -f "$pattern"

# Check if the process was found and killed
if [ "$?" -eq 0 ]; then
    echo "Process with tunnel to $debug_host:$debug_port for user $username killed successfully."
else
    echo "No matching process found."
fi

