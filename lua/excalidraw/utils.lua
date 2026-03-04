local M = {}

local config = require("excalidraw.config")

local log_levels = { debug = 1, info = 2, warn = 3, error = 4 }

function M.log(level, msg)
  local cfg_level = log_levels[config.options.log_level] or 2
  local msg_level = log_levels[level] or 2
  if msg_level >= cfg_level then
    local prefix = "[excalidraw] "
    if level == "error" then
      vim.notify(prefix .. msg, vim.log.levels.ERROR)
    elseif level == "warn" then
      vim.notify(prefix .. msg, vim.log.levels.WARN)
    elseif level == "info" then
      vim.notify(prefix .. msg, vim.log.levels.INFO)
    else
      vim.notify(prefix .. msg, vim.log.levels.DEBUG)
    end
  end
end

function M.url_encode(str)
  return str:gsub("([^%w%-%.%_%~%/])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
end

function M.get_theme()
  local theme = config.options.theme
  if theme == "auto" then
    return vim.o.background == "dark" and "dark" or "light"
  end
  return theme
end

function M.open_browser(url)
  local cmd = config.options.browser_command
  if cmd then
    vim.fn.jobstart({ cmd, url }, { detach = true })
    return
  end

  local uname = vim.loop.os_uname().sysname
  if uname == "Darwin" then
    vim.fn.jobstart({ "open", url }, { detach = true })
  elseif uname == "Linux" then
    -- Detect WSL
    local is_wsl = vim.fn.filereadable("/proc/sys/fs/binfmt_misc/WSLInterop") == 1
    if is_wsl then
      vim.fn.jobstart({ "wslview", url }, { detach = true })
    else
      vim.fn.jobstart({ "xdg-open", url }, { detach = true })
    end
  else
    M.log("error", "Unsupported platform: " .. uname .. ". Set browser_command in config.")
  end
end

function M.plugin_root()
  local source = debug.getinfo(1, "S").source:sub(2)
  -- source is .../lua/excalidraw/utils.lua → go up 3 levels
  return vim.fn.fnamemodify(source, ":h:h:h")
end

function M.is_excalidraw_file(path)
  return path:match("%.excalidraw$") or path:match("%.excalidraw%.json$")
end

return M
