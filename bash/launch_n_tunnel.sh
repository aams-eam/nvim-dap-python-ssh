#!/bin/bash

# Check if all required arguments are provided
if [ "$#" -ne 9 ]; then
    echo "Error; Usage: $0 <username> <host> <port> <debug_host> <debug_port> <password_key_file> <uses_pass> <python_executable> <python_script_path>"
    exit 1
fi

# Assign provided arguments to variables
USERNAME=$1
HOST=$2
PORT=$3
DEBUG_HOST=$4
DEBUG_PORT=$5
PASSWORD_KEY_FILE=$6
USES_PASS=$7
PYTHON_EXEC=$8
PYTHON_SCRIPT_PATH=$9
# Function to check execution status and send result to Lua
check_and_send_result() {
    if [ "$?" -eq 0 ]; then
        echo "Success"
    else
        echo "Error: $1"
    fi
}


if [ "$USES_PASS" == "true" ]; then
  SSH_COMMAND="sshpass -p $PASSWORD_KEY_FILE ssh -o StrictHostKeyChecking=no -f -l $USERNAME -p $PORT $HOST" 
else
  SSH_COMMAND="ssh -i $PASSWORD_KEY_FILE -o StrictHostKeyChecking=no -f -l $USERNAME -p $PORT $HOST"  
fi

# Execute Python file via sshpass
eval "$SSH_COMMAND $PYTHON_EXEC -Xfrozen_modules=off -m debugpy --listen localhost:5678 --wait-for-client $PYTHON_SCRIPT_PATH"
check_and_send_result "Failed to execute Python script via sshpass"

# Wait until the debugger is ready
MAX_WAIT_SECONDS=120  # Adjust the maximum wait time as needed
WAIT_INTERVAL=1       # Adjust the interval between checks as needed
SECONDS_WAITED=0

while [ $SECONDS_WAITED -lt $MAX_WAIT_SECONDS ]; do
    # Check if the debugger port is open on the remote host
    if eval "$SSH_COMMAND netstat -an | grep -q '$DEBUG_PORT.*LISTEN'"; then
        break
    else
        sleep $WAIT_INTERVAL
        SECONDS_WAITED=$((SECONDS_WAITED + WAIT_INTERVAL))
    fi
done

# If the loop completes without breaking, consider handling the case where the debugger is not ready within the specified time.
if [ $SECONDS_WAITED -ge $MAX_WAIT_SECONDS ]; then
    echo "Error: Debugger did not become ready within the specified time. Exiting script."
    exit 1
fi
 
# Create Local Port Forwarding Tunnel via sshpass
eval "$SSH_COMMAND -N -L $DEBUG_PORT:$DEBUG_HOST:$DEBUG_PORT" 
check_and_send_result "Failed to create Local Port Forwarding Tunnel via sshpass"

