local M = {}

local config = require("excalidraw.config")
local utils = require("excalidraw.utils")

M.job_id = nil
M.port = nil
M.state = "STOPPED" -- STOPPED | STARTING | RUNNING

function M.is_running()
  return M.state == "RUNNING" and M.job_id ~= nil
end

function M.start(callback)
  if M.state == "RUNNING" then
    if callback then callback() end
    return
  end

  if M.state == "STARTING" then
    -- Queue callback for when ready
    local timer = vim.loop.new_timer()
    timer:start(100, 100, vim.schedule_wrap(function()
      if M.state == "RUNNING" then
        timer:stop()
        timer:close()
        if callback then callback() end
      elseif M.state == "STOPPED" then
        timer:stop()
        timer:close()
        utils.log("error", "Server failed to start")
      end
    end))
    return
  end

  M.state = "STARTING"

  local server_script = utils.plugin_root() .. "/server/excalidraw_server.py"
  local cmd = {
    config.options.python_path,
    server_script,
    "--host", config.options.server_host,
    "--port", tostring(config.options.server_port),
  }

  local stdout_buffer = ""

  M.job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      for _, line in ipairs(data) do
        stdout_buffer = stdout_buffer .. line
        local port_str = stdout_buffer:match("READY:(%d+)")
        if port_str then
          M.port = tonumber(port_str)
          M.state = "RUNNING"
          utils.log("info", "Server running on port " .. M.port)
          stdout_buffer = ""
          if callback then
            vim.schedule(function() callback() end)
          end
        end
      end
    end,
    on_stderr = function(_, data, _)
      for _, line in ipairs(data) do
        if line ~= "" then
          utils.log("debug", "Server stderr: " .. line)
        end
      end
    end,
    on_exit = function(_, code, _)
      M.job_id = nil
      M.port = nil
      M.state = "STOPPED"
      if code ~= 0 then
        utils.log("warn", "Server exited with code " .. code)
      end
    end,
  })

  if M.job_id <= 0 then
    M.state = "STOPPED"
    M.job_id = nil
    utils.log("error", "Failed to start server. Is " .. config.options.python_path .. " available?")
  end
end

function M.ensure_running(callback)
  if M.is_running() then
    callback()
  else
    M.start(callback)
  end
end

function M.stop()
  if M.job_id then
    vim.fn.jobstop(M.job_id)
    M.job_id = nil
    M.port = nil
    M.state = "STOPPED"
    utils.log("info", "Server stopped")
  end
end

function M.status()
  if M.state == "RUNNING" then
    return "RUNNING on port " .. (M.port or "?")
  end
  return M.state
end

return M
