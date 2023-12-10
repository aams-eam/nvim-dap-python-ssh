#!/bin/bash

# Check if all required arguments are provided
if [ "$#" -ne 7 ]; then
    echo "Usage: $0 <username> <host> <port> <debug_host> <debug_port> <use_pass> <key_file>"
    exit 1
fi

# Extracting arguments
username="$1"
host="$2"
port="$3"
debug_host="$4"
debug_port="$5"
use_pass="$6"
key_file="$7"

# Define the pattern based on the provided arguments
if [ "$use_pass" == "true" ]; then
  pattern="ssh -o StrictHostKeyChecking=no -f -l $username -p $port $host -N -L $debug_port:$debug_host:$debug_port"
else
  pattern="ssh -i $key_file -o StrictHostKeyChecking=no -f -l $username -p $port $host -N -L $debug_port:$debug_host:$debug_port"
fi

# Use pkill to find and delete the process
pkill -f "$pattern"

# Check if the process was found and killed
if [ "$?" -eq 0 ]; then
    echo "Process with tunnel to $debug_host:$debug_port for user $username killed successfully."
else
    echo "Error: No matching process found."
fi

