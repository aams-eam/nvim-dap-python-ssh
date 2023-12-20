# nvim-dap-python-ssh

This plugin was based on [nvim-dap-python][1]. It includes additional configurations for:
- Attaching to an application being debugged remotely.
- Launching an application remotely via ssh.

When launching an application remotely, the plugin:
- Connects via ssh and executes the application with Debugpy.
- Creates an SSH tunnel to the machine with the specified port.
- Attach the debugger via the tunnel.
- Deletes the tunnel when a debug session is finished or stopped.

## Installation

- Requires [nvim-dap-python][1] and its dependencies.
- Requires `sshpass` if SSH is used with password.

If you are using Lazy:
```lua
  {
    "nvim-dap-python-ssh",
    dependencies = {
      'mfussenegger/nvim-dap-python',
    },
    config = function()
      require("dap-python-ssh").setup()
    end,
    lazy = false,
  }
```

## Usage

The following `launch.json` adds two configurations. One for debugging via ssh with password, and the other for debugging via ssh with key.
```json
{
    "configurations": [
        {
            "type": "python",
            "request": "ssh_launch_attach",
            "name": "SSH Connection with Password",
            "host": "172.23.63.1",
            "port": "22",
            "username": "user",
            "pythonPath": "/home/user/remotedebug/.venv/bin/python3",
            "pathMappings": [
                {
                  "localRoot": "${fileDirname}",
                  "remoteRoot": "/home/user/remotedebug"
                }
            ],
	        "program": "${fileBasename}",
            "connect": {
              "host": "127.0.0.1",
              "port": 5678
            }
	    },
	    {
            "type": "python",
            "request": "ssh_launch_attach",
            "name": "SSH Connection with Key",
            "host": "172.23.63.1",
            "port": "22",
            "username": "user",
            "ssh_key": "~/.ssh/user_remote_server",
            "pythonPath": "/home/user/remotedebug/.venv/bin/python3",
            "pathMappings": [
                {
                  "localRoot": "${fileDirname}",
                  "remoteRoot": "/home/user/remotedebug"
                }
            ],
	        "program": "${fileBasename}",
            "connect": {
                "host": "127.0.0.1",
                "port": 5678
            }
        }
	]
}
```

[1]: https://github.com/mfussenegger/nvim-dap-python
