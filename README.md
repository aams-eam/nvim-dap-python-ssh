# nvim-dap-python-ssh

This plugin was based on [nvim-dap-python][1]. It provides the hability to debug python applications remotely via ssh.
When debugging an application remotely the plugin:
- Connects via ssh and executes the application with debugpy.
- Create a SSH tunnel to the machine with the specified port.
- Attach the debugger to the tunnel.

The tunnel is deleted when a debug sessions is finished or stopped.


## Installation

- Requires [nvim-dap-python][1] and its dependencies.
- Requires `sshpass` if SSH used with password.

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
This is an example of launch.json using password.
```json

```

This is an example of launch.json using a SSH key.
```json

```

[1]: https://github.com/mfussenegger/nvim-dap-python
