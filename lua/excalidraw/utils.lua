local M = {}

local config = require("excalidraw.config")

local log_levels = { debug = 1, info = 2, warn = 3, error = 4 }

local function get_home()
  local ok, home = pcall(vim.fn.stdpath, "home")
  if ok and home then return home end
  return vim.env.HOME
end

local function opts()
  return config.get()
end

function M.log(level, msg)
  local cfg_level = log_levels[opts().log_level] or 2
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
  local theme = opts().theme
  if theme == "auto" then
    return vim.o.background == "dark" and "dark" or "light"
  end
  return theme
end

function M.open_browser(url)
  local cmd = opts().browser_command
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

function M.expand_path(path)
  if path and path:sub(1, 1) == "~" then
    local home = get_home()
    if not home then
      return path
    end
    return home .. path:sub(2)
  end
  return path
end

function M.get_library_path()
  local lib_path = opts().library_path
  if not lib_path then
    local home = get_home()
    if home then
      lib_path = home .. "/.excalidraw/library.excalidrawlib"
    end
  end
  return lib_path and M.expand_path(lib_path) or nil
end

function M.get_excalidraw_link_at_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2]

  local patterns = {
    "%[([^%]]+)%]%((./[^%)]+%.excalidraw)%)",
    "%[([^%]]+)%]%(([^%s]+%.excalidraw)%)",
  }

  local line_start = 1
  while true do
    local s, e, _text, path
    for _, pat in ipairs(patterns) do
      s, e, _text, path = line:find(pat, line_start)
      if s and col >= s - 1 and col <= e - 1 then
        return path
      end
    end

    if not s then break end
    line_start = e + 1
  end

  return nil
end

function M.get_assets_path(name)
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == "" then
    return nil, "No file in current buffer"
  end
  local dir = vim.fn.fnamemodify(current_file, ":h")
  local assets = opts().assets_dir or "assets"
  local full_path = dir .. "/" .. assets .. "/" .. name
  if not M.is_excalidraw_file(full_path) then
    full_path = full_path .. ".excalidraw"
  end
  return full_path, nil
end

return M
