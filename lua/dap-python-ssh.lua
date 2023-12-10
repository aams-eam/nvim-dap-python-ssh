---@mod dap-python-ssh nvim-dap extension for python and SSH remote execution

local M = {}
local active_sessions = {}


 local function load_dap()
   local ok, dap = pcall(require, 'dap')
   assert(ok, 'nvim-dap is required to use dap-python')
   return dap
 end


 local is_windows = function()
   return vim.fn.has("win32") == 1
 end


 local get_python_path = function()
   local venv_path = os.getenv('VIRTUAL_ENV')
   if venv_path then
     if is_windows() then
       return venv_path .. '\\Scripts\\python.exe'
     end
     return venv_path .. '/bin/python'
   end

   venv_path = os.getenv("CONDA_PREFIX")
   if venv_path then
     if is_windows() then
       return venv_path .. '\\python.exe'
     end
     return venv_path .. '/bin/python'
   end

   if M.resolve_python then
     assert(type(M.resolve_python) == "function", "resolve_python must be a function")
     return M.resolve_python()
   end
   return nil
 end


 local enrich_config = function(config, on_config)
   if not config.pythonPath and not config.python then
     config.pythonPath = get_python_path()
   end
   on_config(config)
 end


 local default_setup_opts = {
   include_configs = true,
   console = 'integratedTerminal',
   pythonPath = nil,
 }

-- Function to find and remove a table based on multiple fields
local function findAndRemove(tableOfTables, fields)
    for i, tbl in ipairs(tableOfTables) do
        local match = true

        -- A debugger session with attach can be identified by host and port
        if tbl.connect.host ~= fields.connect.host or tbl.connect.port ~= fields.connect.port then
          match = false
        end

        if match then
            table.remove(tableOfTables, i)
            return tbl
        end
    end

    return nil
end

--- set a listener when debugging session finishes
local function add_ssh_launch_attach_dap_listeners()
  local dap = load_dap()

  -- Subscribe to the event_terminated event
  dap.listeners.after['event_terminated']['nvim-dap-python-ssh'] = function(session)

    -- We only need to check for attach adapters
    if session.config.request == "attach" then

      local deletedSessionInfo = findAndRemove(active_sessions, session.config)

      if deletedSessionInfo then

          -- Call Bash script only if the table was found
          local username = deletedSessionInfo.username
          local host = deletedSessionInfo.host
          local port = deletedSessionInfo.port
          local debug_host = deletedSessionInfo.connect.host
          local debug_port = deletedSessionInfo.connect.port

          -- ToDo: Make this global?
          -- Get path of the directory of the bash file
          local bashScriptPath = debug.getinfo(1, "S").source:sub(2)
          local bashScriptDirectory = bashScriptPath:match("(.*/)") .. "../bash/"

          local cmd = string.format("bash %s %s %s %d %s %d", bashScriptDirectory .. "delete_n_tunnel.sh", username, host, port, debug_host, debug_port)
          local result = vim.fn.systemlist(cmd)
          -- ToDo: Check that the tunnel has been deleted correctly

      end
    end
  end
end

 --- Register the python debug adapter
 ---@param adapter_python_path string|nil Path to the python interpreter. Path must be absolute or in $PATH and needs to have the debugpy package installed. Default is `python3`
 ---@param opts SetupOpts|nil See |dap-python.SetupOpts|
 function M.setup(adapter_python_path, opts)
   local dap = load_dap()
   add_ssh_launch_attach_dap_listeners()
   adapter_python_path = adapter_python_path and vim.fn.expand(vim.fn.trim(adapter_python_path), true) or 'python3'
   opts = vim.tbl_extend('keep', opts or {}, default_setup_opts)
   dap.adapters.python = function(cb, config)
     if config.request == 'attach' then
       ---@diagnostic disable-next-line: undefined-field
       local port = (config.connect or config).port
       ---@diagnostic disable-next-line: undefined-field
       local host = (config.connect or config).host or '127.0.0.1'

       cb({
         type = 'server',
         port = assert(port, '`connect.port` is required for a python `attach` configuration'),
         host = host,
         enrich_config = enrich_config,
         options = {
           source_filetype = 'python',
         }
       })
     elseif config.request == 'ssh_launch_attach' then

       -- Get path of the directory of the bash file
       local bashScriptPath = debug.getinfo(1, "S").source:sub(2)
       local bashScriptDirectory = bashScriptPath:match("(.*/)") .. "../bash/"

       -- Get the rest of the variables from config
       local username = config.username
       local host = config.host
       local port = config.port
       local debug_host = config.connect.host or '127.0.0.1'
       local debug_port = config.connect.port or 5678
       local remoteRoot = config.pathMappings[1].remoteRoot
       local program = config.program
       local python_exec = config.pythonPath
       local password = vim.fn.inputsecret("SSH Password: ")
       -- ToDo: store the passwords? Maybe decrypt them with a master password when nvim opens for the first time

       local ssh_creation_command = string.format("bash %s %s %s %s %s %s %s %s %s", bashScriptDirectory .. "launch_n_tunnel.sh", username, host, port, debug_host, debug_port, password, python_exec, remoteRoot .. "/" .. program)

       local result = vim.fn.systemlist(ssh_creation_command)

        -- ToDo: Handle the result. In stop creating the debugging session if the command was not executed properly or the tunnels are not created
        -- if string.find(result, "Success") then
        --     print("Execution successful")

        -- else
        --     print("Error:", result)
        -- end

       local debugSession = {}
       debugSession.username = config.username
       debugSession.host = config.host
       debugSession.port = config.port
       debugSession.connect = config.connect
       table.insert(active_sessions, debugSession)


        -- There is no function for "ssh_launch_attach" in dap, that configuration request does not exists. Hence, we need
        -- to modify the request to "attach".
       config.request = "attach"
       config.host = nil
       config.port = nil
       config.sshpass = nil

       cb({
         type = 'server',
         port = assert(debug_port, '`connect.port` is required for a python `ssh_launch_attach` configuration'),
         host = debug_host,
         enrich_config = enrich_config,
         options = {
           source_filetype = 'python',
         }
       })

     else
       cb({
         type = 'executable';
         command = adapter_python_path;
         args = { '-m', 'debugpy.adapter' };
         enrich_config = enrich_config;
         options = {
           source_filetype = 'python',
         }
       })
     end
   end

   if opts.include_configs then
     local configs = dap.configurations.python or {}
     dap.configurations.python = configs
     table.insert(configs, {
       type = 'python';
       request = 'attach';
       name = 'Attach to remote server';
       connect = function()
         local host = vim.fn.input('Host [127.0.0.1]: ')
         host = host ~= '' and host or '127.0.0.1'
         local port = tonumber(vim.fn.input('Port [5678]: ')) or 5678
         return { host = host, port = port }
       end;
       cwd = vim.fn.getcwd();
       pathMappings = {
             {
                 localRoot = function()
                     return vim.fn.input("Local code folder: ", vim.fn.getcwd(), "file")
                 end;
                 remoteRoot = function()
                     return vim.fn.input("Remote code folder: ", "/home/kali/remotedebug", "file")
                 end;
             },
         },
     })
     table.insert(configs, {
      -- Given a server with SSH enabled, with this configuration you can launch the
      -- application via ssh, create a tunnel, and then attach to the port locally to 
      -- debug the remote application.
      type = 'python';
      request = 'ssh_launch_attach';
      name = 'Launch and attach to remote SSH server';
      host = function()
        return vim.fn.input('SSH HOST to connect: ')
      end;
      port = function()
        return vim.fn.input('SSH PORT to connect: ')
      end;
      username = function()
        return vim.fn.input('SSH Username: ')
      end;
      connect = function()
        local host = vim.fn.input('Host to debug [127.0.0.1]: ')
        host = host ~= '' and host or '127.0.0.1'
        local port = tonumber(vim.fn.input('Port to debug [5678]: ')) or 5678
        return { host = host, port = port }
      end;
			program = "${fileBasename}",
      pythonPath = function()
        return vim.fn.input('Python path: ')
      end;
      pathMappings = {
            {
                localRoot = function()
                    return vim.fn.input("Local code folder: ", vim.fn.getcwd(), "file")
                end;
                remoteRoot = function()
                    return vim.fn.input("Remote code folder: ", "/home/kali/remotedebug", "file")
                end;
            },
        },
     })
   end
 end

return M
